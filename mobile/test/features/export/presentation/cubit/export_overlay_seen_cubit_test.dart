import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:kelal_studio/features/export/presentation/cubit/export_overlay_seen_cubit.dart';

/// Minimal in-memory `Storage` so `HydratedCubit`s can be constructed
/// without touching the filesystem — same pattern
/// `test/core/router/app_router_test.dart` and
/// `test/features/auth/presentation/pages/login_page_test.dart` each define
/// locally for `ThemeCubit`/`LocaleCubit`.
class _InMemoryStorage implements Storage {
  final _data = <String, dynamic>{};

  @override
  dynamic read(String key) => _data[key];

  @override
  Future<void> write(String key, dynamic value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<void> clear() async => _data.clear();

  @override
  Future<void> close() async {}
}

void main() {
  setUp(() {
    HydratedBloc.storage = _InMemoryStorage();
  });

  test('defaults to false (overlay not yet seen)', () {
    expect(ExportOverlaySeenCubit().state, isFalse);
  });

  test('markSeen() emits true', () {
    final cubit = ExportOverlaySeenCubit()..markSeen();
    expect(cubit.state, isTrue);
  });

  test('the seen flag survives a fresh instance reading the same storage '
      '(the whole point of using HydratedCubit for this)', () async {
    ExportOverlaySeenCubit().markSeen();
    // HydratedCubit persists asynchronously; give it a beat to flush before
    // constructing the second instance that reads it back.
    await Future<void>.delayed(Duration.zero);

    final second = ExportOverlaySeenCubit();
    expect(second.state, isTrue);
  });

  test('fromJson/toJson round-trip', () {
    final cubit = ExportOverlaySeenCubit();
    expect(cubit.toJson(true), {'seen': true});
    expect(cubit.fromJson({'seen': true}), isTrue);
    expect(cubit.fromJson({'seen': false}), isFalse);
  });
}
