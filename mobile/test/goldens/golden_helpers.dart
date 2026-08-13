import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';

/// Write **one** golden test with this helper and it produces a scenario
/// for every `(theme x variant)` combination automatically — light and
/// dark are always included; pass as many named [variants] as the
/// component needs (states, locales, etc.) and each one gets rendered in
/// both themes without hand-duplicating a `GoldenTestScenario` per
/// combination. See mobile/.claude/skills/flutter-testing/SKILL.md and
/// test/goldens/primary_button_golden_test.dart for the reference usage.
///
/// Every text-bearing golden should include at least one Amharic-label
/// variant — see mobile/.claude/skills/flutter-ethiopic-typography/SKILL.md
/// and the PRD §6.7 golden-image regression corpus this contributes to.
void goldenThemeTest(
  String description, {
  required String fileName,
  required Map<String, WidgetBuilder> variants,
  Size surfaceSize = const Size(360, 120),
}) {
  final themes = {'light': AppTheme.light(), 'dark': AppTheme.dark()};

  goldenTest(
    description,
    fileName: fileName,
    builder: () => GoldenTestGroup(
      children: [
        for (final themeEntry in themes.entries)
          for (final variantEntry in variants.entries)
            GoldenTestScenario(
              name: '${themeEntry.key} - ${variantEntry.key}',
              child: _GoldenSurface(
                theme: themeEntry.value,
                size: surfaceSize,
                builder: variantEntry.value,
              ),
            ),
      ],
    ),
  );
}

class _GoldenSurface extends StatelessWidget {
  const _GoldenSurface({
    required this.theme,
    required this.size,
    required this.builder,
  });

  final ThemeData theme;
  final Size size;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: theme,
      child: Builder(
        builder: (context) => SizedBox(
          width: size.width,
          height: size.height,
          child: ColoredBox(
            color: theme.scaffoldBackgroundColor,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Builder(builder: builder),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
