import 'package:flutter/material.dart';
import 'package:kelal_studio/core/widgets/empty_state.dart';

import 'golden_helpers.dart';

/// Golden coverage for [EmptyState] — Figma `Components / Empty State`,
/// node `45:2`, variants "Home — First Run" (`45:6`) and "Drafts Library
/// — Empty" (`45:13`); both share this exact structure.
void main() {
  goldenThemeTest(
    'Empty state renders its mark, copy, and optional CTA',
    fileName: 'empty_state',
    surfaceSize: const Size(380, 420),
    variants: {
      'with cta - english': (context) => EmptyState(
        icon: Icons.auto_awesome_outlined,
        heading: 'Your first post starts here',
        body:
            'Tell Kelal what you’re promoting and get a bilingual caption '
            'plus a branded graphic in seconds.',
        ctaLabel: 'Create Your First Post',
        onCtaPressed: () {},
      ),
      'with cta - amharic': (context) => EmptyState(
        icon: Icons.auto_awesome_outlined,
        heading: 'የመጀመሪያ ልጥፍዎ እዚህ ይጀምራል',
        body:
            'ኬላል ምን እያስተዋወቁ እንደሆነ ይንገሩ እና በሰከንዶች ውስጥ ሁለት ቋንቋ '
            'መግለጫ እና የምርት ስም ግራፊክ ያግኙ።',
        ctaLabel: 'የመጀመሪያ ልጥፍዎን ይፍጠሩ',
        onCtaPressed: () {},
      ),
      'without cta': (context) => const EmptyState(
        icon: Icons.folder_open_outlined,
        heading: 'No drafts yet',
        body: 'Drafts you save while composing will show up here.',
      ),
    },
  );
}
