import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import 'package:kelal_studio/core/di/injection.dart';
import 'package:kelal_studio/core/l10n/gen/app_localizations.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/core/widgets/app_text_field.dart';
import 'package:kelal_studio/core/widgets/brand_avatar.dart';
import 'package:kelal_studio/core/widgets/error_snack_bar.dart';
import 'package:kelal_studio/core/widgets/loading_indicator.dart';
import 'package:kelal_studio/core/widgets/primary_button.dart';
import 'package:kelal_studio/features/brand_kit/domain/entities/brand_kit.dart';
import 'package:kelal_studio/features/brand_kit/presentation/bloc/brand_kit_bloc.dart';
import 'package:kelal_studio/features/brand_kit/presentation/bloc/brand_kit_event.dart';
import 'package:kelal_studio/features/brand_kit/presentation/bloc/brand_kit_state.dart';
import 'package:kelal_studio/features/brand_kit/presentation/widgets/color_swatch_picker.dart';

/// **Deliberate PRD deviation, documented per this branch's task** (see
/// mobile/CLAUDE.md's own note on this). The PRD (§4, §6.8) assigns Brand
/// Kit configuration to a separate web admin/brand-kit portal that doesn't
/// exist anywhere in this repo (`web/` is an empty, not-yet-built
/// directory — see the root CLAUDE.md). Without a mobile-side Brand Kit
/// screen, nothing in this app could ever attach a business's name, logo,
/// colors, or tone of voice to a generation request — the entire content-
/// generation feature would be unusable. This screen is therefore a full
/// read/write Brand Kit editor built directly into mobile, not a stopgap —
/// mirrors how `features/auth` is this codebase's reference vertical
/// slice.
///
/// **Known real limitation, also flagged rather than glossed over**: the
/// `BrandKit` schema in mobile/api_contract/openapi.yaml exposes
/// `logo_asset_id` only, never a display URL for the uploaded image. This
/// screen can therefore only preview a logo actually picked *in the
/// current session* (kept in memory — see
/// `_BrandKitViewState._confirmedLogoPreviewBytes`); a `logoAssetId`
/// inherited from a previous session/save renders as a generic icon
/// placeholder rather than the real image, since there's nothing to fetch
/// it from.
class BrandKitPage extends StatelessWidget {
  const BrandKitPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<BrandKitBloc>()..add(const BrandKitLoadRequested()),
      child: const _BrandKitView(),
    );
  }
}

class _BrandKitView extends StatefulWidget {
  const _BrandKitView();

  @override
  State<_BrandKitView> createState() => _BrandKitViewState();
}

class _BrandKitViewState extends State<_BrandKitView> {
  final _brandNameController = TextEditingController();
  final _toneOfVoiceController = TextEditingController();
  final _contactInfoController = TextEditingController();
  final _primaryColorController = TextEditingController();
  final _secondaryColorController = TextEditingController();

  static final _hexColorPattern = RegExp(r'^#[0-9A-Fa-f]{6}$');

  String? _primaryColorError;
  String? _secondaryColorError;

  /// Guards against re-syncing the text controllers from server state after
  /// the first load — every emission after that (from a save or logo
  /// upload) must leave in-progress, unsaved keystrokes alone. See this
  /// file's class doc comment and `BrandKitBloc`'s doc comment for the
  /// full reasoning.
  bool _controllersSynced = false;

  /// Bytes just handed to the Bloc for upload, not yet confirmed —
  /// promoted to [_confirmedLogoPreviewBytes] only once the upload
  /// succeeds (see the matching [BlocListener] below), so a failed upload
  /// never shows a phantom preview.
  Uint8List? _pendingLogoBytes;

  /// The only source of truth this screen has for rendering an actual
  /// logo image — see this file's class doc comment for why a
  /// server-persisted `logoAssetId` from a previous session can't be
  /// rendered here.
  Uint8List? _confirmedLogoPreviewBytes;

  @override
  void dispose() {
    _brandNameController.dispose();
    _toneOfVoiceController.dispose();
    _contactInfoController.dispose();
    _primaryColorController.dispose();
    _secondaryColorController.dispose();
    super.dispose();
  }

  void _syncControllersOnce(BrandKit brandKit) {
    if (_controllersSynced) return;
    _brandNameController.text = brandKit.brandName;
    _toneOfVoiceController.text = brandKit.toneOfVoice;
    _contactInfoController.text = brandKit.contactInfo;
    _primaryColorController.text = brandKit.primaryColorHex;
    _secondaryColorController.text = brandKit.secondaryColorHex;
    _controllersSynced = true;
  }

  bool _validateColors(AppLocalizations l10n) {
    final primaryValid = _hexColorPattern.hasMatch(
      _primaryColorController.text.trim(),
    );
    final secondaryValid = _hexColorPattern.hasMatch(
      _secondaryColorController.text.trim(),
    );
    setState(() {
      _primaryColorError = primaryValid ? null : l10n.brandKitInvalidHexError;
      _secondaryColorError = secondaryValid
          ? null
          : l10n.brandKitInvalidHexError;
    });
    return primaryValid && secondaryValid;
  }

  void _save(BuildContext context, BrandKit current) {
    final l10n = AppLocalizations.of(context);
    if (!_validateColors(l10n)) return;
    final draft = BrandKit(
      id: current.id,
      brandName: _brandNameController.text.trim(),
      logoAssetId: current.logoAssetId,
      primaryColorHex: _primaryColorController.text.trim(),
      secondaryColorHex: _secondaryColorController.text.trim(),
      toneOfVoice: _toneOfVoiceController.text.trim(),
      contactInfo: _contactInfoController.text.trim(),
      updatedAt: current.updatedAt,
    );
    context.read<BrandKitBloc>().add(BrandKitSaveRequested(draft));
  }

  Future<void> _pickLogo(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    }
    // image_picker can throw a variety of platform-specific exception
    // types (permission denial, no camera/gallery app, etc.) — all of them
    // collapse to the same plain-language message here.
    // ignore: avoid_catches_without_on_clauses
    catch (_) {
      if (context.mounted) {
        showErrorSnackBar(context, l10n.brandKitLogoTooLargeError);
      }
      return;
    }
    if (picked == null) return; // user cancelled the picker

    final bytes = await picked.readAsBytes();
    _pendingLogoBytes = bytes;
    if (!context.mounted) return;
    context.read<BrandKitBloc>().add(
      BrandKitLogoUploadRequested(
        bytes: bytes,
        filename: picked.name,
        mimeType: picked.mimeType ?? 'application/octet-stream',
      ),
    );
  }

  void _showSuccessSnackBar(BuildContext context, String message) {
    final colors = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: colors.successBg,
        content: Text(
          message,
          style: AppTypography.bodySmall.copyWith(color: colors.successText),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return MultiBlocListener(
      listeners: [
        // Sync the form controllers exactly once, on the transition into
        // the first-ever BrandKitReady state.
        BlocListener<BrandKitBloc, BrandKitState>(
          listenWhen: (previous, current) =>
              current is BrandKitReady && previous is! BrandKitReady,
          listener: (context, state) =>
              _syncControllersOnce((state as BrandKitReady).brandKit),
        ),
        // A logo upload that started while `_pendingLogoBytes` was set just
        // succeeded — promote it to the confirmed preview.
        BlocListener<BrandKitBloc, BrandKitState>(
          listenWhen: (previous, current) =>
              previous is BrandKitUploadingLogo && current is BrandKitLoaded,
          listener: (context, state) {
            setState(() => _confirmedLogoPreviewBytes = _pendingLogoBytes);
          },
        ),
        BlocListener<BrandKitBloc, BrandKitState>(
          listenWhen: (previous, current) => current is BrandKitSaveFailure,
          listener: (context, state) => showErrorSnackBar(
            context,
            (state as BrandKitSaveFailure).message,
          ),
        ),
        BlocListener<BrandKitBloc, BrandKitState>(
          listenWhen: (previous, current) =>
              current is BrandKitLogoUploadFailure,
          listener: (context, state) => showErrorSnackBar(
            context,
            (state as BrandKitLogoUploadFailure).message,
          ),
        ),
        // A save that was in flight just landed successfully — distinct
        // from the initial load also producing a `BrandKitLoaded` state,
        // which `listenWhen`'s `previous is BrandKitSaving` check excludes.
        BlocListener<BrandKitBloc, BrandKitState>(
          listenWhen: (previous, current) =>
              previous is BrandKitSaving && current is BrandKitLoaded,
          listener: (context, state) =>
              _showSuccessSnackBar(context, l10n.brandKitSaveSuccessMessage),
        ),
      ],
      child: Scaffold(
        // Reuses navBrandLabel ("Brand"), same convention `SettingsPage`
        // (another real, non-placeholder branch page) follows — keeps the
        // AppBar title consistent with the bottom-nav tab it lives under.
        appBar: AppBar(title: Text(l10n.navBrandLabel)),
        body: SafeArea(
          child: BlocBuilder<BrandKitBloc, BrandKitState>(
            builder: (context, state) {
              return switch (state) {
                BrandKitInitial() || BrandKitLoadInProgress() => const Center(
                  child: LoadingIndicator(),
                ),
                BrandKitLoadFailure(:final message) => _LoadErrorView(
                  message: message,
                  onRetry: () => context.read<BrandKitBloc>().add(
                    const BrandKitLoadRequested(),
                  ),
                ),
                BrandKitReady() => _BrandKitForm(
                  state: state,
                  brandNameController: _brandNameController,
                  toneOfVoiceController: _toneOfVoiceController,
                  contactInfoController: _contactInfoController,
                  primaryColorController: _primaryColorController,
                  secondaryColorController: _secondaryColorController,
                  primaryColorError: _primaryColorError,
                  secondaryColorError: _secondaryColorError,
                  logoPreviewBytes: _confirmedLogoPreviewBytes,
                  onPickLogo: () => _pickLogo(context),
                  onSave: () => _save(context, state.brandKit),
                ),
              };
            },
          ),
        ),
      ),
    );
  }
}

class _LoadErrorView extends StatelessWidget {
  const _LoadErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              key: const Key('brand_kit_retry_button'),
              label: l10n.brandKitRetryButton,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandKitForm extends StatelessWidget {
  const _BrandKitForm({
    required this.state,
    required this.brandNameController,
    required this.toneOfVoiceController,
    required this.contactInfoController,
    required this.primaryColorController,
    required this.secondaryColorController,
    required this.primaryColorError,
    required this.secondaryColorError,
    required this.logoPreviewBytes,
    required this.onPickLogo,
    required this.onSave,
  });

  final BrandKitReady state;
  final TextEditingController brandNameController;
  final TextEditingController toneOfVoiceController;
  final TextEditingController contactInfoController;
  final TextEditingController primaryColorController;
  final TextEditingController secondaryColorController;
  final String? primaryColorError;
  final String? secondaryColorError;
  final Uint8List? logoPreviewBytes;
  final VoidCallback onPickLogo;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final isSaving = state is BrandKitSaving;
    final isUploadingLogo = state is BrandKitUploadingLogo;
    final isBusy = isSaving || isUploadingLogo;
    final hasLogo = state.brandKit.logoAssetId != null;

    final avatarStatus = isUploadingLogo
        ? BrandAvatarStatus.uploading
        : state is BrandKitLogoUploadFailure
        ? BrandAvatarStatus.error
        : hasLogo
        ? BrandAvatarStatus.hasLogo
        : BrandAvatarStatus.initialFallback;

    final avatarCaption = switch (avatarStatus) {
      BrandAvatarStatus.uploading => l10n.brandKitLogoCaptionUploading,
      BrandAvatarStatus.error => l10n.brandKitLogoCaptionError,
      BrandAvatarStatus.hasLogo => l10n.brandKitLogoCaptionHasLogo,
      BrandAvatarStatus.initialFallback => l10n.brandKitLogoCaptionNoLogo,
    };

    // `substring(0, 1)` (not a grapheme-cluster split) is safe here: the
    // Ethiopic Unicode block is entirely within the BMP (no surrogate
    // pairs), so a single UTF-16 code unit is always exactly one visible
    // Amharic character too.
    final brandInitial = state.brandKit.brandName.isNotEmpty
        ? state.brandKit.brandName.substring(0, 1).toUpperCase()
        : '?';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: GestureDetector(
              key: const Key('brand_kit_logo_picker'),
              onTap: isBusy ? null : onPickLogo,
              child: BrandAvatar(
                status: avatarStatus,
                caption: avatarCaption,
                initial: avatarStatus == BrandAvatarStatus.initialFallback
                    ? brandInitial
                    : null,
                logo: avatarStatus == BrandAvatarStatus.hasLogo
                    ? (logoPreviewBytes != null
                          ? Image.memory(logoPreviewBytes!, fit: BoxFit.cover)
                          // No display URL exists for a logoAssetId
                          // inherited from a previous session — see this
                          // screen's class doc comment.
                          : Icon(Icons.image, color: colors.textTertiary))
                    : null,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: TextButton(
              key: const Key('brand_kit_change_logo_button'),
              onPressed: isBusy ? null : onPickLogo,
              child: Text(l10n.brandKitChangeLogoButton),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppTextField(
            key: const Key('brand_kit_name_field'),
            controller: brandNameController,
            enabled: !isBusy,
            label: l10n.brandKitBrandNameLabel,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            key: const Key('brand_kit_tone_field'),
            controller: toneOfVoiceController,
            enabled: !isBusy,
            label: l10n.brandKitToneOfVoiceLabel,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            key: const Key('brand_kit_contact_field'),
            controller: contactInfoController,
            enabled: !isBusy,
            label: l10n.brandKitContactInfoLabel,
          ),
          const SizedBox(height: AppSpacing.xl),
          ColorSwatchPicker(
            key: const Key('brand_kit_primary_color_picker'),
            label: l10n.brandKitPrimaryColorLabel,
            hexController: primaryColorController,
            enabled: !isBusy,
            errorText: primaryColorError,
          ),
          const SizedBox(height: AppSpacing.lg),
          ColorSwatchPicker(
            key: const Key('brand_kit_secondary_color_picker'),
            label: l10n.brandKitSecondaryColorLabel,
            hexController: secondaryColorController,
            enabled: !isBusy,
            errorText: secondaryColorError,
          ),
          const SizedBox(height: AppSpacing.xxl),
          PrimaryButton(
            key: const Key('brand_kit_save_button'),
            label: l10n.brandKitSaveButton,
            isLoading: isSaving,
            onPressed: isBusy ? null : onSave,
          ),
        ],
      ),
    );
  }
}
