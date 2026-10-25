import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/l10n/gen/app_localizations.dart';
import 'package:kelal_studio/features/settings/presentation/pages/legal_document_page.dart';

void main() {
  Widget wrap(String title, String content) {
    return MaterialApp(
      // AppBackButton reads AppLocalizations — without these delegates the
      // very first pump throws instead of rendering.
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: LegalDocumentPage(title: title, content: content),
    );
  }

  testWidgets('renders the title and back control', (tester) async {
    await tester.pumpWidget(wrap('Privacy Policy', 'Some content.'));

    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.byKey(const Key('app_back_button')), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
  });

  testWidgets(
    'splits double-newline-separated paragraphs into separate Text widgets '
    'instead of one undifferentiated block',
    (tester) async {
      await tester.pumpWidget(
        wrap('Terms of Service', 'First paragraph.\n\nSecond paragraph.'),
      );

      expect(find.text('First paragraph.'), findsOneWidget);
      expect(find.text('Second paragraph.'), findsOneWidget);
    },
  );

  testWidgets(
    'splits a short first line with no sentence-ending punctuation off a '
    "block as its own heading, matching the Font Licenses document's "
    r'"PREAMBLE\nThe goals of..." shape',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          'Third-Party Font Licenses',
          'Noto Sans Ethiopic\n\nPREAMBLE\nThe goals of the OFL are to '
              'stimulate font development.',
        ),
      );

      expect(find.text('Noto Sans Ethiopic'), findsOneWidget);
      expect(find.text('PREAMBLE'), findsOneWidget);
      expect(
        find.text('The goals of the OFL are to stimulate font development.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a normal sentence ending in punctuation is never treated as a heading',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          'Privacy Policy',
          'Kelal Studio operates as a supervised public beta.',
        ),
      );

      expect(
        find.text('Kelal Studio operates as a supervised public beta.'),
        findsOneWidget,
      );
    },
  );
}
