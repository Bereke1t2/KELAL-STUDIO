import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/quota/domain/entities/quota.dart';
import 'package:kelal_studio/features/quota/domain/usecases/get_quota_usecase.dart';
import 'package:kelal_studio/features/quota/presentation/bloc/quota_bloc.dart';
import 'package:kelal_studio/features/quota/presentation/bloc/quota_event.dart';
import 'package:kelal_studio/features/quota/presentation/bloc/quota_state.dart';
import 'package:mocktail/mocktail.dart';

class MockGetQuotaUseCase extends Mock implements GetQuotaUseCase {}

void main() {
  late MockGetQuotaUseCase getQuotaUseCase;

  final quota = Quota(
    textCallsUsed: 3,
    textCallsLimit: 10,
    imageCallsUsed: 1,
    imageCallsLimit: 5,
    resetsAt: DateTime.utc(2026, 1, 1, 18),
  );

  setUp(() {
    getQuotaUseCase = MockGetQuotaUseCase();
  });

  QuotaBloc buildBloc() => QuotaBloc(getQuotaUseCase);

  group('QuotaRequested', () {
    blocTest<QuotaBloc, QuotaState>(
      'emits [LoadInProgress, Loaded] on a successful fetch',
      setUp: () {
        when(getQuotaUseCase.call).thenAnswer((_) async => Result.ok(quota));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const QuotaRequested()),
      expect: () => [const QuotaLoadInProgress(), QuotaLoaded(quota)],
    );

    blocTest<QuotaBloc, QuotaState>(
      'emits [LoadInProgress, LoadFailure] when the fetch fails',
      setUp: () {
        when(getQuotaUseCase.call).thenAnswer(
          (_) async => const Result.err(
            ApiFailure(
              type: ApiErrorType.network,
              message: 'No connection. Check your network and try again.',
            ),
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const QuotaRequested()),
      expect: () => [
        const QuotaLoadInProgress(),
        const QuotaLoadFailure(
          'No connection. Check your network and try again.',
        ),
      ],
    );

    blocTest<QuotaBloc, QuotaState>(
      'restartable transformer: firing a second QuotaRequested while the '
      'first is still in flight cancels the first — only the second '
      "call's result is ever emitted, so a slower, now-stale first "
      'response can never land after (and overwrite) the fresher one',
      setUp: () {
        var callCount = 0;
        when(getQuotaUseCase.call).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            // The first call is slower than the second — if this bloc
            // were `droppable()` this event would win (second dropped);
            // if it were naive `concurrent()` this could still land last
            // and overwrite the fresher result. `restartable()` must
            // prevent both.
            await Future<void>.delayed(const Duration(milliseconds: 100));
            return Result.ok(
              quota.copyWithForTest(textCallsUsed: 1), // stale reading
            );
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return Result.ok(quota); // fresh reading
        });
      },
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const QuotaRequested());
        // A real gap so the first event's handler actually starts (and
        // emits its LoadInProgress) before the second event arrives and
        // cancels it — firing both adds back-to-back with no gap lets
        // `restartable()`'s switchMap cancel event 1 before its handler
        // ever runs at all, which would demonstrate a *different*
        // (equally valid, but less illustrative) edge of the same
        // transformer.
        await Future<void>.delayed(const Duration(milliseconds: 20));
        bloc.add(const QuotaRequested());
      },
      wait: const Duration(milliseconds: 150),
      // Only one `QuotaLoadInProgress` appears, not two: it's emitted by
      // event 1's handler (which genuinely starts and runs synchronously
      // up to its first `await`), but by the time event 2's handler also
      // emits `QuotaLoadInProgress`, the bloc's current state is *already*
      // `QuotaLoadInProgress` (equatable-equal to the first) — `Bloc`
      // itself silently dedupes a same-value re-emit (see
      // `package:bloc`'s `onEmit`: `if (this.state == state && _emitted)
      // return;`), independent of the transformer. The property this test
      // actually exists to prove is the one after it: only `QuotaLoaded`
      // built from the *second* (fresh) call ever lands — event 1's
      // eventual, slower, stale result is fully suppressed.
      expect: () => [const QuotaLoadInProgress(), QuotaLoaded(quota)],
      verify: (_) {
        // The first call's `_getQuotaUseCase()` future still runs to
        // completion in the background — `restartable()` stops
        // *forwarding its emits*, it doesn't kill the future — but its
        // eventual (stale) result is never emitted, per `expect` above.
        verify(getQuotaUseCase.call).called(2);
      },
    );
  });
}

extension on Quota {
  /// Test-only helper for building a second, distinguishable [Quota]
  /// value — the real entity has no `copyWith` (unlike `BrandKit`, nothing
  /// in the app builds a draft/edited copy of a server-reported quota), so
  /// this is local to the test rather than added to the domain entity just
  /// for this one assertion.
  Quota copyWithForTest({required int textCallsUsed}) => Quota(
    textCallsUsed: textCallsUsed,
    textCallsLimit: textCallsLimit,
    imageCallsUsed: imageCallsUsed,
    imageCallsLimit: imageCallsLimit,
    resetsAt: resetsAt,
  );
}
