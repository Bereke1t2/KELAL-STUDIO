import 'package:flutter/widgets.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:injectable/injectable.dart';

/// The user's explicit language preference. `null` means "follow the
/// device locale, falling back to English" — matches `MaterialApp.router`'s
/// `locale` semantics when passed `null`.
///
/// This resolves the PRD's OQ-14 ("is the app interface itself localized
/// into Amharic, separate from generated bilingual content?") for
/// practical purposes: yes — see `lib/core/l10n/arb/`. Only a handful of
/// strings are wired through `AppLocalizations` so far (the login screen);
/// extend `app_en.arb`/`app_am.arb` together as new screens land, and get
/// every new Amharic string reviewed by a native speaker before it ships —
/// this scaffold's own `am` strings beyond the two pulled verbatim from
/// Figma (`appTitle`, `appTagline`) are a best-effort placeholder
/// translation, explicitly flagged as unverified per the PRD's own
/// requirement for native-speaker review of Amharic content.
@lazySingleton
class LocaleCubit extends HydratedCubit<Locale?> {
  LocaleCubit() : super(null);

  static const supportedLocales = [Locale('en'), Locale('am')];

  void setLocale(Locale? locale) => emit(locale);

  @override
  Locale? fromJson(Map<String, dynamic> json) {
    final code = json['languageCode'] as String?;
    return code == null ? null : Locale(code);
  }

  @override
  Map<String, dynamic>? toJson(Locale? state) => {
    'languageCode': state?.languageCode,
  };
}
