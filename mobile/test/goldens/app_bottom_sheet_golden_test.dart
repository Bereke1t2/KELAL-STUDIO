import 'package:flutter/material.dart';
import 'package:kelal_studio/core/widgets/app_bottom_sheet.dart';

import 'golden_helpers.dart';

/// Golden coverage for [AppBottomSheet] and [AppDialog] — Figma
/// `Components / Modal & Sheet`, node `42:2`: "Bottom Sheet — Confirm
/// Delete" (`42:6`) and "Centered Dialog — Fatal Error" (`42:15`).
void main() {
  goldenThemeTest(
    'Bottom sheet and dialog shells render their content and actions',
    fileName: 'app_bottom_sheet',
    surfaceSize: const Size(375, 340),
    variants: {
      'bottom sheet - destructive - english': (context) => AppBottomSheet(
        heading: 'Delete this draft?',
        body:
            'This draft only exists on this device. Once deleted, it cannot '
            'be recovered — there is no server copy to restore from.',
        primaryLabel: 'Delete Draft',
        onPrimaryPressed: () {},
        secondaryLabel: 'Keep Draft',
        onSecondaryPressed: () {},
        isDestructive: true,
      ),
      'bottom sheet - destructive - amharic': (context) => AppBottomSheet(
        heading: 'ይህን ረቂቅ ይሰርዙ?',
        body: 'ይህ ረቂቅ የሚገኘው በዚህ መሣሪያ ላይ ብቻ ነው። አንዴ ከተሰረዘ መልሶ ማግኘት አይቻልም።',
        primaryLabel: 'ረቂቅ ሰርዝ',
        onPrimaryPressed: () {},
        secondaryLabel: 'ረቂቅ ያቆዩ',
        onSecondaryPressed: () {},
        isDestructive: true,
      ),
      'dialog - english': (context) => AppDialog(
        icon: Icons.error_outline,
        heading: "Kelal couldn't start",
        body:
            'Something on this device is preventing the app from loading '
            'your drafts. Try restarting the app.',
        actionLabel: 'Restart Kelal',
        onActionPressed: () {},
      ),
    },
  );
}
