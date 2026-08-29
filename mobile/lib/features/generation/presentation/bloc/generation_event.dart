import 'package:equatable/equatable.dart';

import 'package:kelal_studio/features/generation/domain/entities/content_platform.dart';
import 'package:kelal_studio/features/generation/domain/entities/input_language.dart';

sealed class GenerationEvent extends Equatable {
  const GenerationEvent();
}

/// Dispatched when the user taps Generate on the composer screen — carries
/// the fully-assembled request snapshotted at submit time, mirrors
/// `BrandKitSaveRequested`'s "only dispatch on submit, not per-keystroke"
/// pattern. `brand_kit_id` is deliberately not a field here — it's
/// resolved inside `GenerationBloc` from whatever brand kit is currently
/// on file, not something the composer form itself collects (see
/// `GenerationBloc`'s doc comment).
final class GenerationRequested extends GenerationEvent {
  const GenerationRequested({
    required this.inputText,
    required this.inputLanguage,
    required this.platform,
  });

  final String inputText;
  final InputLanguage inputLanguage;
  final ContentPlatform platform;

  @override
  List<Object?> get props => [inputText, inputLanguage, platform];
}
