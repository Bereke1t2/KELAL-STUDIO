import 'package:flutter/material.dart' show Size;
import 'package:kelal_studio/core/widgets/quota_badge.dart';

import 'golden_helpers.dart';

/// Golden coverage for the quota badge design-system primitive — scoped to
/// a single component, not a full screen, per
/// mobile/.claude/skills/flutter-testing/SKILL.md. Warrants a golden (per
/// that skill's "use your judgment" scoping) because it has several
/// visually-distinct states (loading/loaded/warning/error) that a plain
/// widget test only asserts on structurally, not pixel-for-pixel — the
/// warning-vs-neutral color swap in particular is exactly the kind of
/// thing a golden catches that a `find.text`/`find.byKey` assertion won't.
///
/// English and Amharic loaded-state variants both included, contributing
/// to the Ethiopic golden-image regression corpus (PRD §6.7) — see
/// `test/goldens/primary_button_golden_test.dart` for the reference usage
/// of `goldenThemeTest`.
void main() {
  goldenThemeTest(
    'Quota badge renders on-brand in light and dark',
    fileName: 'quota_badge',
    surfaceSize: const Size(320, 140),
    variants: {
      'loading': (context) => const QuotaBadge(
        status: QuotaBadgeStatus.loading,
        loadingValue: 0.65,
      ),
      'loaded - english': (context) => const QuotaBadge(
        status: QuotaBadgeStatus.loaded,
        textRemainingLabel: '7 of 10 text calls remaining today',
        imageRemainingLabel: '4 of 5 image calls remaining today',
        resetLabel: 'Resets at 6:00 PM',
      ),
      'loaded - amharic': (context) => const QuotaBadge(
        status: QuotaBadgeStatus.loaded,
        textRemainingLabel: 'ከ10 የጽሑፍ ጥሪዎች ዛሬ 7 ቀርተዋል',
        imageRemainingLabel: 'ከ5 የምስል ጥሪዎች ዛሬ 4 ቀርተዋል',
        resetLabel: 'በ6:00 PM ዳግም ይጀምራል',
      ),
      'warning - at limit': (context) => const QuotaBadge(
        status: QuotaBadgeStatus.loaded,
        textRemainingLabel: '0 of 10 text calls remaining today',
        imageRemainingLabel: '0 of 5 image calls remaining today',
        resetLabel: 'Resets at 6:00 PM',
        isWarning: true,
      ),
      'error': (context) => const QuotaBadge(
        status: QuotaBadgeStatus.error,
        errorMessage: 'No connection. Check your network and try again.',
      ),
    },
  );
}
