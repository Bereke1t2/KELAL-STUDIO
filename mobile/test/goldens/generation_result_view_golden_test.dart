import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kelal_studio/core/l10n/gen/app_localizations.dart';
import 'package:kelal_studio/features/generation/domain/entities/generation_result.dart';
import 'package:kelal_studio/features/generation/presentation/widgets/generation_result_view.dart';

import 'golden_helpers.dart';

/// Golden coverage for the generation feature's result-rendering widget —
/// scoped to the component, not the whole `ComposerPage`, per
/// mobile/.claude/skills/flutter-testing/SKILL.md. `GenerationResultView`
/// needs `AppLocalizations` (its copy-button tooltips/snack bar text are
/// localized), so unlike `primary_button_golden_test.dart` this wraps
/// each scenario's `builder` output in a minimal `Localizations` context
/// via [_localized] rather than relying on `goldenThemeTest`'s bare
/// `Theme`-only surface.
void main() {
  const freshResult = GenerationResult(
    captionEn: 'Check out our new arrivals!',
    captionAm: 'አዲስ ምርቶቻችንን ይመልከቱ!',
    callToAction: 'Shop now',
    hashtags: ['#new', '#shop', '#ethiopia'],
    isFallback: false,
  );

  const fallbackResult = GenerationResult(
    captionEn: "Here's a starting point you can edit.",
    captionAm: 'ሊያርትዑት የሚችሉት መነሻ ነጥብ።',
    callToAction: 'Tell us what you think!',
    hashtags: ['#KelalStudio', '#SmallBusiness'],
    isFallback: true,
  );

  goldenThemeTest(
    'Generation result view renders fields and the fallback notice on-brand '
    'in light and dark',
    fileName: 'generation_result_view',
    surfaceSize: const Size(360, 760),
    variants: {
      'fresh result - english': (context) => _localized(
        const Locale('en'),
        const GenerationResultView(result: freshResult),
      ),
      'fresh result - amharic': (context) => _localized(
        const Locale('am'),
        const GenerationResultView(result: freshResult),
      ),
      'fallback result - english': (context) => _localized(
        const Locale('en'),
        const GenerationResultView(result: fallbackResult),
      ),
    },
  );
}

Widget _localized(Locale locale, Widget child) {
  return Localizations(
    locale: locale,
    delegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    child: Directionality(textDirection: TextDirection.ltr, child: child),
  );
}
