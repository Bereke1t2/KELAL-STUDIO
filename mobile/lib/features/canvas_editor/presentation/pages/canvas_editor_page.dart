import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:kelal_studio/core/di/injection.dart';
import 'package:kelal_studio/core/l10n/gen/app_localizations.dart';
import 'package:kelal_studio/core/render_engine/canvas_scene.dart';
import 'package:kelal_studio/core/render_engine/render_engine.dart';
import 'package:kelal_studio/core/router/app_page_transitions.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/core/widgets/app_bottom_sheet.dart';
import 'package:kelal_studio/core/widgets/app_text_field.dart';
import 'package:kelal_studio/core/widgets/segmented_control.dart';
import 'package:kelal_studio/features/canvas_editor/presentation/bloc/canvas_editor_bloc.dart';
import 'package:kelal_studio/features/canvas_editor/presentation/bloc/canvas_editor_event.dart';
import 'package:kelal_studio/features/canvas_editor/presentation/bloc/canvas_editor_state.dart';
import 'package:kelal_studio/features/canvas_editor/presentation/widgets/safe_zone_guide.dart';
import 'package:kelal_studio/features/drafts/presentation/cubit/draft_autosave_cubit.dart';
import 'package:kelal_studio/features/export/presentation/pages/export_page.dart';
import 'package:kelal_studio/features/generation/domain/entities/aspect_ratio.dart';

/// `/canvas-editor`'s `state.extra` payload — bundles the [scene] to edit
/// with the two caption strings from the `GenerationResult` that produced
/// it. `CanvasScene` itself carries no caption field (see `ExportPageArgs`'s
/// doc comment in `features/export/presentation/pages/export_page.dart` for
/// the full contract-gap note); `CanvasEditorPage` doesn't render
/// [captionEn]/[captionAm] itself, it only holds onto them to forward
/// unchanged into an [ExportPageArgs] once the user taps Continue — this is
/// where that thread starts, fed by `ComposerPage`'s `ImageGenerationSuccess`
/// listener (`composer_page.dart`).
///
/// [inputText]/[brandKitId] exist purely to feed `DraftAutosaveCubit` (PRD
/// §10.5) — neither is rendered by this page. [inputText] is required (a
/// draft with no idea text behind it isn't meaningful); [brandKitId] is
/// left `null` when the caller has no brand kit id in scope at this point
/// in the flow (e.g. `ComposerPage` today doesn't thread one through its
/// generation request) rather than inventing new cross-feature plumbing to
/// populate it — a real, flagged gap, not a bug. **Also note**: resuming a
/// saved draft (`DraftsPage`) can only recover [inputText], never the
/// original captions — they aren't part of PRD §10.5's draft schema — so a
/// resumed draft's [captionEn]/[captionAm] arrive here as empty strings;
/// see `DraftsPage`'s listener for the other side of this same note.
class CanvasEditorPageArgs {
  const CanvasEditorPageArgs({
    required this.scene,
    required this.captionEn,
    required this.captionAm,
    required this.inputText,
    this.brandKitId,
  });

  final CanvasScene scene;
  final String captionEn;
  final String captionAm;
  final String inputText;
  final String? brandKitId;
}

/// The interactive canvas editor — PRD §6.9. Owns no generation logic
/// itself; [args]' `scene` is expected to already be built (decoded
/// background, sized to a real `GenerateImageResponse`) by whatever
/// screen navigated here, typically the composer after a successful
/// `ImageGenerationSuccess` (see
/// `features/generation/presentation/bloc/image_generation_bloc.dart`).
class CanvasEditorPage extends StatelessWidget {
  const CanvasEditorPage({required this.args, super.key});

  final CanvasEditorPageArgs args;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              getIt<CanvasEditorBloc>()
                ..add(CanvasEditorSceneLoaded(args.scene)),
        ),
        // PRD §10.5's debounced local-draft autosave — fed from every
        // CanvasEditorBloc scene change via the BlocListener in
        // _CanvasEditorView below, not read directly here.
        BlocProvider(create: (_) => getIt<DraftAutosaveCubit>()),
      ],
      child: _CanvasEditorView(args: args),
    );
  }
}

class _CanvasEditorView extends StatelessWidget {
  const _CanvasEditorView({required this.args});

  final CanvasEditorPageArgs args;

  static const _ratios = [
    GenerationAspectRatio.oneToOne,
    GenerationAspectRatio.fourToFive,
  ];

  int _selectedRatioIndex(Size canvasSize) {
    final ratio = canvasSize.width / canvasSize.height;
    final oneToOneRatio =
        GenerationAspectRatio.oneToOne.canvasSize.width /
        GenerationAspectRatio.oneToOne.canvasSize.height;
    return (ratio - oneToOneRatio).abs() < 0.01 ? 0 : 1;
  }

  /// **Reuses `showAppBottomSheet` (the modal-presentation function) and
  /// `AppTextField` (the input widget), not `AppBottomSheet` itself** —
  /// `AppBottomSheet`'s shape is fixed to a plain `String body` rendered as
  /// `Text`, with no slot for a live-editable field, so it cannot host the
  /// tap-to-edit affordance this needs. `showAppBottomSheet` takes any
  /// `Widget sheet`, so `_TextLayerEditSheet` below reuses that same modal
  /// presentation (transparent barrier, scroll-controlled bottom sheet)
  /// plus `AppTextField`, styled with the same tokens `AppBottomSheet`
  /// itself uses (grabber, heading, `AppSpacing`/`AppRadius`/colors) for
  /// visual consistency — rather than either forcing text entry through a
  /// widget that can't support it, or inventing an unrelated modal
  /// mechanism.
  Future<void> _openEditSheet(BuildContext context, TextLayer layer) async {
    final bloc = context.read<CanvasEditorBloc>();
    final result = await showAppBottomSheet<String>(
      context,
      sheet: _TextLayerEditSheet(initialText: layer.text),
    );
    if (result != null && context.mounted) {
      bloc.add(CanvasEditorLayerTextChanged(layerId: layer.id, text: result));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: Hero(
          tag: heroCreateGraphicTag,
          // Text has no bounded box of its own to interpolate cleanly, so
          // this gives the Hero flight a stable-sized target to animate
          // into — see `heroCreateGraphicTag`'s doc comment for the
          // composer-side counterpart.
          child: Material(
            type: MaterialType.transparency,
            child: Text(l10n.canvasEditorTitle),
          ),
        ),
      ),
      body: MultiBlocListener(
        listeners: [
          // PRD §10.5's local-draft autosave: every CanvasEditorReady scene
          // change restarts DraftAutosaveCubit's debounce timer. Separate
          // BlocListener (rather than folding into the BlocConsumer below)
          // so this autosave hook and the tap-to-edit-sheet behavior stay
          // independently `listenWhen`-gated instead of one hand-rolled
          // condition trying to cover both.
          BlocListener<CanvasEditorBloc, CanvasEditorState>(
            listenWhen: (previous, current) => current is CanvasEditorReady,
            listener: (context, state) {
              final ready = state as CanvasEditorReady;
              context.read<DraftAutosaveCubit>().sceneChanged(
                ready.scene,
                inputText: args.inputText,
                brandKitId: args.brandKitId,
              );
            },
          ),
        ],
        child: BlocConsumer<CanvasEditorBloc, CanvasEditorState>(
          // Auto-opens the tap-to-edit sheet for a layer the moment it's
          // added — CanvasEditorBloc._onLayerAdded intentionally leaves new
          // layers with empty text (see that method's doc comment on why it
          // isn't a placeholder phrase), so without this the user would see
          // an invisible, empty text box with no obvious next step.
          listenWhen: (previous, current) {
            if (previous is! CanvasEditorReady ||
                current is! CanvasEditorReady) {
              return false;
            }
            final selectedId = current.selectedLayerId;
            return selectedId != null &&
                selectedId != previous.selectedLayerId &&
                current.scene.textLayers.any(
                  (l) => l.id == selectedId && l.text.isEmpty,
                );
          },
          listener: (context, state) {
            final ready = state as CanvasEditorReady;
            final layer = ready.scene.textLayers.firstWhere(
              (l) => l.id == ready.selectedLayerId,
            );
            _openEditSheet(context, layer);
          },
          builder: (context, state) {
            if (state is! CanvasEditorReady) {
              return const SizedBox.shrink();
            }
            final bloc = context.read<CanvasEditorBloc>();
            final scene = state.scene;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: AppSegmentedControl(
                    key: const Key('canvas_editor_aspect_ratio_selector'),
                    labels: const ['1:1', '4:5'],
                    selectedIndex: _selectedRatioIndex(scene.canvasSize),
                    onChanged: (index) => bloc.add(
                      CanvasEditorAspectRatioChanged(_ratios[index]),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio:
                            scene.canvasSize.width / scene.canvasSize.height,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final boxSize = constraints.biggest;
                            return GestureDetector(
                              key: const Key('canvas_editor_deselect_area'),
                              onTap: () => bloc.add(
                                const CanvasEditorLayerSelected(null),
                              ),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: CustomPaint(
                                      key: const Key(
                                        'canvas_editor_canvas_paint',
                                      ),
                                      painter: CanvasScenePainter(scene),
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: SafeZoneGuide(boxSize: boxSize),
                                  ),
                                  for (final layer in scene.textLayers)
                                    _DraggableTextLayer(
                                      key: Key(
                                        'canvas_editor_layer_${layer.id}',
                                      ),
                                      layer: layer,
                                      selected:
                                          layer.id == state.selectedLayerId,
                                      canvasSize: scene.canvasSize,
                                      boxSize: boxSize,
                                      onSelected: () => bloc.add(
                                        CanvasEditorLayerSelected(layer.id),
                                      ),
                                      onDragUpdated: (delta) => bloc.add(
                                        CanvasEditorLayerDragUpdated(
                                          layerId: layer.id,
                                          screenDelta: delta,
                                          boxSize: boxSize,
                                        ),
                                      ),
                                      onScaled: (factor) => bloc.add(
                                        CanvasEditorLayerScaled(
                                          layerId: layer.id,
                                          scaleFactor: factor,
                                        ),
                                      ),
                                      onTapToEdit: () =>
                                          _openEditSheet(context, layer),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('canvas_editor_add_text_button'),
                          onPressed: state.canAddTextLayer
                              ? () => bloc.add(const CanvasEditorLayerAdded())
                              : null,
                          child: Text(l10n.canvasEditorAddTextButton),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('canvas_editor_remove_text_button'),
                          onPressed: state.selectedLayerId != null
                              ? () => bloc.add(
                                  CanvasEditorLayerRemoved(
                                    state.selectedLayerId!,
                                  ),
                                )
                              : null,
                          child: Text(l10n.canvasEditorRemoveTextButton),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: ElevatedButton(
                    key: const Key('canvas_editor_continue_button'),
                    // Forwards the *current* (possibly user-edited) scene —
                    // not `args.scene`, which is only the initial state this
                    // page was loaded with — plus the two caption strings
                    // threaded through unchanged from `args` (see
                    // `CanvasEditorPageArgs`'s doc comment above).
                    onPressed: () => context.push(
                      '/export',
                      extra: ExportPageArgs(
                        scene: scene,
                        captionEn: args.captionEn,
                        captionAm: args.captionAm,
                      ),
                    ),
                    child: Text(l10n.canvasEditorContinueButton),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      backgroundColor: colors.bgCanvas,
    );
  }
}

/// Drag-to-reposition / pinch-to-resize / tap-to-edit hit target for one
/// [TextLayer]. Renders **no visible text of its own** — the actual
/// caption pixels come from `RenderEngine.paint`'s `CustomPaint`
/// underneath (`core/render_engine`'s single paint path); this is purely
/// an invisible (except for a selection outline) gesture surface
/// positioned over that layer's approximate on-screen bounding box, so
/// the live editor never risks a second, independently-rendered copy of
/// the text drifting out of sync with what `RenderEngine` actually paints.
class _DraggableTextLayer extends StatefulWidget {
  const _DraggableTextLayer({
    required this.layer,
    required this.selected,
    required this.canvasSize,
    required this.boxSize,
    required this.onSelected,
    required this.onDragUpdated,
    required this.onScaled,
    required this.onTapToEdit,
    super.key,
  });

  final TextLayer layer;
  final bool selected;
  final Size canvasSize;
  final Size boxSize;
  final VoidCallback onSelected;
  final ValueChanged<Offset> onDragUpdated;
  final ValueChanged<double> onScaled;
  final VoidCallback onTapToEdit;

  @override
  State<_DraggableTextLayer> createState() => _DraggableTextLayerState();
}

class _DraggableTextLayerState extends State<_DraggableTextLayer> {
  /// Cumulative scale reported by the *current* gesture, as of the last
  /// `onScaleUpdate` — `ScaleUpdateDetails.scale` is cumulative-since-
  /// gesture-start, not a frame-to-frame delta, so this is tracked to
  /// derive an incremental multiplier per update
  /// (`CanvasEditorLayerScaled.scaleFactor`'s documented contract).
  double _lastCumulativeScale = 1;

  @override
  Widget build(BuildContext context) {
    final heightFraction = CanvasEditorBloc.estimateLayerHeightFraction(
      widget.layer,
      widget.canvasSize,
    );
    final left = widget.layer.normalizedOffset.dx * widget.boxSize.width;
    final top = widget.layer.normalizedOffset.dy * widget.boxSize.height;
    final width = widget.layer.normalizedMaxWidth * widget.boxSize.width;
    final height = (heightFraction * widget.boxSize.height).clamp(
      AppSpacing.minTapTarget,
      widget.boxSize.height,
    );

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.onTapToEdit,
        onScaleStart: (_) {
          _lastCumulativeScale = 1.0;
          widget.onSelected();
        },
        onScaleUpdate: (details) {
          widget.onDragUpdated(details.focalPointDelta);
          if (details.scale != _lastCumulativeScale) {
            widget.onScaled(details.scale / _lastCumulativeScale);
            _lastCumulativeScale = details.scale;
          }
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: widget.selected
                ? Border.all(color: const Color(0xFFFFFFFF), width: 1.5)
                : null,
          ),
        ),
      ),
    );
  }
}

class _TextLayerEditSheet extends StatefulWidget {
  const _TextLayerEditSheet({required this.initialText});

  final String initialText;

  @override
  State<_TextLayerEditSheet> createState() => _TextLayerEditSheetState();
}

class _TextLayerEditSheetState extends State<_TextLayerEditSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.only(
        top: AppSpacing.md,
        left: AppSpacing.xxl,
        right: AppSpacing.xxl,
        bottom: AppSpacing.xxxl,
      ),
      decoration: BoxDecoration(
        color: colors.bgSurfaceRaised,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.xl),
          topRight: Radius.circular(AppRadius.xl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.borderStrong,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.canvasEditorEditSheetHeading,
            textAlign: TextAlign.center,
            style: AppTypography.title.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            key: const Key('canvas_editor_edit_sheet_field'),
            controller: _controller,
            label: l10n.canvasEditorEditSheetFieldLabel,
            maxLines: 3,
            minLines: 1,
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            key: const Key('canvas_editor_edit_sheet_save_button'),
            onPressed: () => Navigator.of(context).pop(_controller.text),
            child: Text(l10n.canvasEditorEditSheetSaveButton),
          ),
        ],
      ),
    );
  }
}
