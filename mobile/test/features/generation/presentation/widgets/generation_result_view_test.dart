import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/l10n/gen/app_localizations.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/features/generation/domain/entities/generation_result.dart';
import 'package:kelal_studio/features/generation/presentation/widgets/generation_result_view.dart';

void main() {
  const result = GenerationResult(
    captionEn: 'Check out our new arrivals!',
    captionAm: 'አዲስ ምርቶቻችንን ይመልከቱ!',
    callToAction: 'Shop now',
    hashtags: ['new', '#shop'],
    isFallback: false,
  );

  Widget wrap(GenerationResult result) {
    return MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('am')],
      home: Scaffold(body: GenerationResultView(result: result)),
    );
  }

  testWidgets('renders every field and no fallback notice for a fresh '
      'generation', (tester) async {
    await tester.pumpWidget(wrap(result));

    expect(find.text('Check out our new arrivals!'), findsOneWidget);
    expect(find.text('አዲስ ምርቶቻችንን ይመልከቱ!'), findsOneWidget);
    expect(find.text('Shop now'), findsOneWidget);
    // Hashtags are normalized to always show a leading '#', even for an
    // entry that didn't already have one.
    expect(find.text('#new #shop'), findsOneWidget);
    expect(find.byKey(const Key('generation_fallback_notice')), findsNothing);
  });

  testWidgets('shows the fallback notice when isFallback is true', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const GenerationResult(
          captionEn: 'a',
          captionAm: 'b',
          callToAction: 'c',
          hashtags: ['#a'],
          isFallback: true,
        ),
      ),
    );

    expect(find.byKey(const Key('generation_fallback_notice')), findsOneWidget);
  });

  testWidgets(
    "tapping a field's copy button copies its value to the clipboard and "
    'shows a confirmation',
    (tester) async {
      final copiedValues = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<Object?, Object?>;
            copiedValues.add(args['text']! as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(wrap(result));
      await tester.tap(
        find.byKey(const Key('generation_result_caption_en_copy_button')),
      );
      await tester.pumpAndSettle();

      expect(copiedValues, ['Check out our new arrivals!']);
      expect(find.text('English caption copied to clipboard.'), findsOneWidget);
    },
  );
}
