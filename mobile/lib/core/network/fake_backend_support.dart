import 'dart:math';

import 'package:kelal_studio/core/error/result.dart';

/// Shared infrastructure for every feature's `Fake*RemoteDataSource`.
///
/// The point of a "professional" mock (per mobile/.claude/skills/
/// flutter-networking-data/SKILL.md) is that it exercises the UI's error
/// handling honestly, not just the happy path — a fake that always
/// succeeds instantly hides bugs that only show up against a real,
/// imperfect network. Every Fake*RemoteDataSource should route its
/// simulated latency and failures through this class instead of
/// hand-rolling `Future.delayed` and ad-hoc throws per feature.
class ApiException implements Exception {
  ApiException(this.failure);
  final ApiFailure failure;
}

abstract final class FakeBackendSupport {
  static final _random = Random();

  /// Simulated realistic latency for a 3G/4G Ethiopian mobile network
  /// (PRD §12: "standard Ethiopian mobile network (3G/4G)"), not a
  /// same-machine localhost round trip — fakes that respond in 5ms hide
  /// loading-state and race-condition bugs that only appear under real
  /// latency.
  static Future<void> latency({
    Duration min = const Duration(milliseconds: 400),
    Duration max = const Duration(milliseconds: 1800),
  }) {
    final spread = max.inMilliseconds - min.inMilliseconds;
    final delay =
        min.inMilliseconds + _random.nextInt(spread <= 0 ? 1 : spread);
    return Future<void>.delayed(Duration(milliseconds: delay));
  }

  /// Throws the given [failure] with probability [rate] (0.0-1.0). Use this
  /// in fake data sources to exercise typed-error UI paths deliberately —
  /// e.g. a composer fake should throw `quota_exceeded` occasionally, not
  /// only on command, so the "quota almost used up" banner actually gets
  /// tested by whoever is driving the app manually.
  static void maybeFail(ApiFailure failure, {double rate = 0.0}) {
    if (rate <= 0) return;
    if (_random.nextDouble() < rate) throw ApiException(failure);
  }
}
