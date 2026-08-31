import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:kelal_studio/core/l10n/gen/app_localizations.dart';
import 'package:kelal_studio/core/l10n/locale_cubit.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/core/theme/theme_cubit.dart';
import 'package:kelal_studio/features/settings/presentation/pages/settings_page.dart';

class _InMemoryStorage implements Storage {
  final _data = <String, dynamic>{};

  @override
  dynamic read(String key) => _data[key];

  @override
  Future<void> write(String key, dynamic value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<void> clear() async => _data.clear();

  @override
  Future<void> close() async {}
}

void main() {
  setUpAll(() {
    HydratedBloc.storage = _InMemoryStorage();
  });

  Widget wrap() {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ThemeCubit()),
        BlocProvider(create: (_) => LocaleCubit()),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return BlocBuilder<LocaleCubit, Locale?>(
            builder: (context, locale) {
              return MaterialApp(
                theme: AppTheme.light(),
                darkTheme: AppTheme.dark(),
                themeMode: themeMode,
                locale: locale,
                supportedLocales: LocaleCubit.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                home: const SettingsPage(),
              );
            },
          );
        },
      ),
    );
  }

  // Every string this file asserts on now comes from the same
  // AppLocalizations getters SettingsPage itself reads — a hardcoded
  // English literal here would silently stop testing anything the moment
  // the ARB copy changes, which is exactly the drift this avoids.
  final l10n = lookupAppLocalizations(const Locale('en'));

  testWidgets('SettingsPage renders all core sections', (tester) async {
    await tester.pumpWidget(wrap());

    expect(find.text(l10n.navSettingsLabel), findsWidgets);
    expect(find.text(l10n.settingsSectionAccount), findsOneWidget);
    expect(find.text(l10n.settingsAccountItem), findsOneWidget);
    expect(find.text(l10n.settingsBrandKitItem), findsOneWidget);
    expect(find.text(l10n.settingsSectionPreferences), findsOneWidget);
    expect(find.text(l10n.settingsThemeItem), findsOneWidget);
    expect(find.text(l10n.settingsLanguageItem), findsOneWidget);
    expect(find.text(l10n.settingsQuotaItem), findsOneWidget);

    // Legal/ABOUT/Sign Out sit below the fold at the default 800x600 test
    // surface now that each section is a padded, shadowed SoftCard rather
    // than a flat compact list — scroll them into view instead of assuming
    // ListView eagerly built every child (it doesn't; a lazy ListView only
    // builds what's actually visible).
    await tester.scrollUntilVisible(
      find.text(l10n.settingsSignOutItem),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text(l10n.settingsSectionAbout), findsOneWidget);
    expect(find.text(l10n.settingsLegalItem), findsOneWidget);
    expect(find.text(l10n.settingsSignOutItem), findsOneWidget);
  });

  testWidgets('Theme toggle cycles correctly', (tester) async {
    await tester.pumpWidget(wrap());

    // Assuming default is System
    expect(find.text(l10n.settingsThemeSystem), findsOneWidget);

    // Tap theme toggle
    await tester.tap(find.text(l10n.settingsThemeItem));
    await tester.pumpAndSettle();

    // The theme text should change (to Dark or Light depending on
    // platform brightness, mocked to light usually)
    expect(find.text(l10n.settingsThemeDark), findsOneWidget);
  });

  testWidgets('Language toggle changes between English and Amharic', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());

    expect(find.text(l10n.settingsLanguageEnglish), findsOneWidget);

    // Tap language toggle
    await tester.tap(find.text(l10n.settingsLanguageItem));
    await tester.pumpAndSettle();

    // Toggling also switches MaterialApp.locale to Amharic (LocaleCubit
    // drives both), so the row's own copy — not just its trailing value —
    // is now rendered in Amharic too; assert against that locale's own
    // AppLocalizations instance, not the English one every other
    // assertion in this file uses. The trailing value itself is the
    // language's own endonym ("አማርኛ"), not the English word "Amharic" —
    // deliberately, matching how most bilingual apps name a language
    // option once you're actually using it.
    final l10nAm = lookupAppLocalizations(const Locale('am'));
    expect(find.text(l10nAm.settingsLanguageAmharic), findsOneWidget);
  });
}
