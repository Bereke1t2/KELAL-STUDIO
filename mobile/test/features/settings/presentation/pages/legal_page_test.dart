import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kelal_studio/core/l10n/gen/app_localizations.dart';
import 'package:kelal_studio/features/settings/presentation/pages/legal_page.dart';

// AppBackButton (used by LegalPage) reads AppLocalizations — every
// MaterialApp/MaterialApp.router built in this file needs the delegates
// below or the very first pump throws instead of rendering.
const _localizationsDelegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

void main() {
  Widget wrap() {
    return const MaterialApp(
      localizationsDelegates: _localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LegalPage(),
    );
  }

  testWidgets('LegalPage renders new UI list items', (tester) async {
    await tester.pumpWidget(wrap());

    expect(find.text('Legal'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Terms of Service'), findsOneWidget);
    expect(find.text('Content Ownership'), findsOneWidget);
    expect(find.text('Third-Party Font Licenses'), findsOneWidget);
    expect(
      find.text(
        'Noto Sans Ethiopic is licensed under the SIL Open Font License, '
        'version 1.1.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Tapping a list item navigates to document page', (tester) async {
    final router = GoRouter(
      initialLocation: '/settings/legal',
      routes: [
        GoRoute(
          path: '/settings/legal',
          builder: (context, state) => const LegalPage(),
        ),
        GoRoute(
          path: '/settings/legal_document',
          builder: (context, state) =>
              const Scaffold(body: Text('Document Page Placeholder')),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: _localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );

    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();

    expect(find.text('Document Page Placeholder'), findsOneWidget);
  });
}
