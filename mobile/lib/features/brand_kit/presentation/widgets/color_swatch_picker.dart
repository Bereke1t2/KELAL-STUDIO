import 'package:flutter/material.dart';

import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/core/widgets/app_text_field.dart';

/// A row of preset color swatches plus a hex [AppTextField], used for the
/// Brand Kit primary/secondary color pickers. Deliberately not a new
/// `core/widgets` design-system primitive — per this branch's task, a
/// small swatch-row-plus-hex-field is "enough" for this non-P0 detail
/// rather than pulling in a color-picker package.
///
/// Presets reuse this app's own Figma-sourced brand/feedback swatches
/// (`AppColors`) rather than arbitrary colors, so picking a preset always
/// yields a value consistent with the rest of the design system.
class ColorSwatchPicker extends StatelessWidget {
  const ColorSwatchPicker({
    required this.label,
    required this.hexController,
    required this.enabled,
    this.errorText,
    this.onChanged,
    super.key,
  });

  final String label;
  final TextEditingController hexController;
  final bool enabled;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  /// Hex strings pulled from this app's own light-mode [AppColors] —
  /// primary brand, brand border, destructive, success, info, and
  /// near-black — a small, on-brand starter palette, not arbitrary colors.
  static const List<String> presetHexColors = [
    '#855312',
    '#C6821F',
    '#8A1D1D',
    '#5CB279',
    '#63A6DA',
    '#171717',
  ];

  static Color? _parseHex(String hex) {
    final cleaned = hex.trim().replaceFirst('#', '');
    if (cleaned.length != 6) return null;
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return null;
    return Color(0xFF000000 | value);
  }

  void _selectPreset(String hex) {
    hexController
      ..text = hex
      ..selection = TextSelection.collapsed(offset: hex.length);
    onChanged?.call(hex);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final hex in presetHexColors)
              _Swatch(
                hex: hex,
                color: _parseHex(hex) ?? colors.bgDisabled,
                selected:
                    hexController.text.trim().toUpperCase() ==
                    hex.toUpperCase(),
                enabled: enabled,
                onTap: () => _selectPreset(hex),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          controller: hexController,
          enabled: enabled,
          label: label,
          errorText: errorText,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.hex,
    required this.color,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String hex;
  final Color color;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: hex,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          // AppSpacing.minTapTarget (48) — every tappable control meets the
          // accessibility floor, swatches included.
          width: AppSpacing.minTapTarget,
          height: AppSpacing.minTapTarget,
          alignment: Alignment.center,
          child: Container(
            width: AppSpacing.xxxl,
            height: AppSpacing.xxxl,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? colors.borderFocus : colors.borderDefault,
                width: selected ? 2 : 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
