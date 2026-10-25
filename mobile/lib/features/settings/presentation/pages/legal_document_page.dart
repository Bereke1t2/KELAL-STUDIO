import 'package:flutter/material.dart';
import 'package:kelal_studio/core/theme/app_colors.dart';
import 'package:kelal_studio/core/theme/app_spacing.dart';
import 'package:kelal_studio/core/theme/app_typography.dart';
import 'package:kelal_studio/core/widgets/app_back_button.dart';

/// One parsed unit of a legal document's plain-text content — an optional
/// short heading line (e.g. "PREAMBLE") plus the paragraph text under it.
/// Produced by [_parseLegalDocumentBlocks].
class _LegalBlock {
  const _LegalBlock({this.heading, this.body = ''});

  final String? heading;
  final String body;
}

/// A line counts as a standalone heading, not the start of a sentence, if
/// it's short and doesn't end the way a sentence normally does. The four
/// legal documents in `LegalPage._buildListItem` are plain strings with no
/// markup, so this is a heuristic, not a real document format — good
/// enough to stop a section title like "PREAMBLE" or "Noto Sans Ethiopic"
/// from being fused into the paragraph that follows it.
bool _looksLikeHeading(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty || trimmed.length > 60) return false;
  const sentenceEndings = ['.', ',', ';', ':', ')'];
  return !sentenceEndings.any(trimmed.endsWith);
}

/// Splits a legal document's [content] into display blocks: each
/// double-newline-separated chunk becomes one [_LegalBlock], and a chunk
/// whose own first line reads as a heading (see [_looksLikeHeading]) has
/// that line split off so it renders larger and separate from the body
/// text under it — e.g. "PREAMBLE\nThe goals of the OFL are..." becomes a
/// heading "PREAMBLE" plus its paragraph, instead of both running together
/// in one undifferentiated block of text.
List<_LegalBlock> _parseLegalDocumentBlocks(String content) {
  final chunks = content
      .split('\n\n')
      .map((c) => c.trim())
      .where((c) => c.isNotEmpty);

  return [
    for (final chunk in chunks)
      if (!chunk.contains('\n') && _looksLikeHeading(chunk))
        _LegalBlock(heading: chunk)
      else
        () {
          final lines = chunk.split('\n');
          final firstLine = lines.first;
          if (lines.length > 1 && _looksLikeHeading(firstLine)) {
            return _LegalBlock(
              heading: firstLine,
              body: lines.skip(1).join('\n').trim(),
            );
          }
          return _LegalBlock(body: chunk);
        }(),
  ];
}

class LegalDocumentPage extends StatelessWidget {
  const LegalDocumentPage({
    required this.title,
    required this.content,
    super.key,
  });

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    final blocks = _parseLegalDocumentBlocks(content);

    return Scaffold(
      backgroundColor: context.colors.bgCanvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.lg,
              ),
              child: AppBackButton(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Text(
                title,
                style: AppTypography.display.copyWith(
                  color: context.colors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < blocks.length; i++) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.lg),
                      if (blocks[i].heading != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: Text(
                            blocks[i].heading!,
                            style: AppTypography.title.copyWith(
                              color: context.colors.textPrimary,
                            ),
                          ),
                        ),
                      if (blocks[i].body.isNotEmpty)
                        Text(
                          blocks[i].body,
                          style: AppTypography.body.copyWith(
                            color: context.colors.textSecondary,
                            height: 1.6,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
