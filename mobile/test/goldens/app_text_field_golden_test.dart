import 'package:flutter/material.dart';
import 'package:kelal_studio/core/widgets/app_text_field.dart';

import 'golden_helpers.dart';

/// Golden coverage for [AppTextField] — Figma `Components / Text Field`
/// (see `flutter-design-system/SKILL.md` for the node-id caveat: the
/// dedicated component mockup wasn't found, so this uses the real
/// notched-label field pulled from Screens / Onboarding & Auth, node
/// `52:7`, which is Material's default `OutlineInputBorder` + `labelText`
/// behavior already themed in `app_theme.dart`).
void main() {
  goldenThemeTest(
    'Text field renders its label, error, and disabled states',
    fileName: 'app_text_field',
    surfaceSize: const Size(340, 100),
    variants: {
      'default - english': (context) =>
          const AppTextField(label: 'Business Email'),
      'default - amharic': (context) => const AppTextField(label: 'የንግድ ኢሜይል'),
      'error - english': (context) => const AppTextField(
        label: 'Business Email',
        errorText: 'Enter a valid email address.',
      ),
      'disabled': (context) =>
          const AppTextField(label: 'Business Email', enabled: false),
    },
  );
}
