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

  testWidgets('SettingsPage renders all core sections', (tester) async {
    await tester.pumpWidget(wrap());

    expect(find.text('Settings'), findsWidgets);
    expect(find.text('ACCOUNT'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Brand Kit'), findsOneWidget);
    expect(find.text('PREFERENCES'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Language & Region'), findsOneWidget);
    expect(find.text('Quota & Usage'), findsOneWidget);
    expect(find.text('ABOUT'), findsOneWidget);
    expect(find.text('Legal'), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);
  });

  testWidgets('Theme toggle cycles correctly', (tester) async {
    await tester.pumpWidget(wrap());

    // Assuming default is System
    expect(find.text('System'), findsOneWidget);

    // Tap theme toggle
    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();

    // The theme text should change (to Dark or Light depending on platform
    // brightness, mocked to light usually)
    expect(find.text('Dark'), findsOneWidget);
  });

  testWidgets('Language toggle changes between English and Amharic', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());

    expect(find.text('English'), findsOneWidget);

    // Tap language toggle
    await tester.tap(find.text('Language & Region'));
    await tester.pumpAndSettle();

    expect(find.text('Amharic'), findsOneWidget);
  });
}
