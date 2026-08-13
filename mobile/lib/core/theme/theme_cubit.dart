import 'package:flutter/material.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:injectable/injectable.dart';

/// The user's explicit dark/light/system preference, persisted on-device
/// via `hydrated_bloc` — this is exactly the "small, non-sensitive UI
/// preference" case mobile/.claude/skills/flutter-state-management/SKILL.md
/// calls out as the right use for `hydrated_bloc` (never drafts/secrets).
///
/// [ThemeMode.system] is the default (matches the previous behavior before
/// an explicit toggle existed); [toggle] flips between light and dark only
/// — from `system`, the first toggle moves to whichever of light/dark the
/// system *isn't* currently resolving to, matching the visible change a
/// user expects from tapping a toggle.
@lazySingleton
class ThemeCubit extends HydratedCubit<ThemeMode> {
  ThemeCubit() : super(ThemeMode.system);

  void setThemeMode(ThemeMode mode) => emit(mode);

  void toggle(Brightness currentPlatformBrightness) {
    final resolvedIsDark = switch (state) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => currentPlatformBrightness == Brightness.dark,
    };
    emit(resolvedIsDark ? ThemeMode.light : ThemeMode.dark);
  }

  @override
  ThemeMode? fromJson(Map<String, dynamic> json) {
    final index = json['themeModeIndex'] as int?;
    if (index == null || index < 0 || index >= ThemeMode.values.length) {
      return null;
    }
    return ThemeMode.values[index];
  }

  @override
  Map<String, dynamic>? toJson(ThemeMode state) => {
    'themeModeIndex': state.index,
  };
}
