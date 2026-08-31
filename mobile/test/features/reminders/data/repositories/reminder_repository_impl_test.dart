import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/network/fake_backend_support.dart';
import 'package:kelal_studio/core/notifications/local_notification_scheduler.dart';
import 'package:kelal_studio/features/reminders/data/datasources/reminder_remote_data_source.dart';
import 'package:kelal_studio/features/reminders/data/repositories/reminder_repository_impl.dart';
import 'package:kelal_studio/features/reminders/domain/entities/reminder.dart';
import 'package:kelal_studio/features/reminders/domain/entities/reminder_failure.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalNotificationScheduler extends Mock
    implements LocalNotificationScheduler {}

class MockReminderRemoteDataSource extends Mock
    implements ReminderRemoteDataSource {}

void main() {
  late MockLocalNotificationScheduler scheduler;
  late MockReminderRemoteDataSource remote;
  late ReminderRepositoryImpl repository;

  final reminder = Reminder(
    draftLocalId: 'draft-1',
    scheduledAtUtc: DateTime.utc(2026, 9, 1, 8),
  );

  setUp(() {
    scheduler = MockLocalNotificationScheduler();
    remote = MockReminderRemoteDataSource();
    repository = ReminderRepositoryImpl(scheduler, remote);

    // Every test that reaches the local-schedule step needs createReminder
    // stubbed — it's called fire-and-forget in the background regardless
    // of the test's own assertions.
    when(
      () => remote.createReminder(
        draftLocalId: any(named: 'draftLocalId'),
        scheduledAtUtc: any(named: 'scheduledAtUtc'),
      ),
    ).thenAnswer((_) async {});
  });

  group('schedule', () {
    test(
      'returns ReminderPermissionDeniedFailure without ever calling '
      'LocalNotificationScheduler.schedule when permission is refused',
      () async {
        when(
          () => scheduler.requestPermission(),
        ).thenAnswer((_) async => false);

        final result = await repository.schedule(
          reminder,
          notificationTitle: 'Time to post!',
          notificationBody: 'Your draft is ready.',
        );

        expect(result.isErr, isTrue);
        result.when(
          ok: (_) => fail('expected an error'),
          err: (failure) =>
              expect(failure, isA<ReminderPermissionDeniedFailure>()),
        );
        verifyNever(
          () => scheduler.schedule(
            draftLocalId: any(named: 'draftLocalId'),
            scheduledAtUtc: any(named: 'scheduledAtUtc'),
            notificationId: any(named: 'notificationId'),
            title: any(named: 'title'),
            body: any(named: 'body'),
          ),
        );
      },
    );

    test(
      "schedules the local notification with the reminder's derived "
      'notificationId and the given title/body, and returns Result.ok',
      () async {
        when(() => scheduler.requestPermission()).thenAnswer((_) async => true);
        when(
          () => scheduler.schedule(
            draftLocalId: any(named: 'draftLocalId'),
            scheduledAtUtc: any(named: 'scheduledAtUtc'),
            notificationId: any(named: 'notificationId'),
            title: any(named: 'title'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async {});

        final result = await repository.schedule(
          reminder,
          notificationTitle: 'Time to post!',
          notificationBody: 'Your draft is ready.',
        );

        expect(result.isOk, isTrue);
        verify(
          () => scheduler.schedule(
            draftLocalId: 'draft-1',
            scheduledAtUtc: reminder.scheduledAtUtc,
            notificationId: reminder.notificationId,
            title: 'Time to post!',
            body: 'Your draft is ready.',
          ),
        ).called(1);
      },
    );

    test(
      'a LocalNotificationScheduler.schedule failure surfaces as '
      'UnexpectedFailure and never triggers the backend notify call',
      () async {
        when(() => scheduler.requestPermission()).thenAnswer((_) async => true);
        when(
          () => scheduler.schedule(
            draftLocalId: any(named: 'draftLocalId'),
            scheduledAtUtc: any(named: 'scheduledAtUtc'),
            notificationId: any(named: 'notificationId'),
            title: any(named: 'title'),
            body: any(named: 'body'),
          ),
        ).thenThrow(StateError('boom'));

        final result = await repository.schedule(
          reminder,
          notificationTitle: 'Time to post!',
          notificationBody: 'Your draft is ready.',
        );

        expect(result.isErr, isTrue);
        result.when(
          ok: (_) => fail('expected an error'),
          err: (failure) => expect(failure, isA<UnexpectedFailure>()),
        );
        verifyNever(
          () => remote.createReminder(
            draftLocalId: any(named: 'draftLocalId'),
            scheduledAtUtc: any(named: 'scheduledAtUtc'),
          ),
        );
      },
    );

    test('a failing best-effort backend notify never affects the returned '
        'Result — the local notification is already scheduled and is the '
        'source of truth', () async {
      when(() => scheduler.requestPermission()).thenAnswer((_) async => true);
      when(
        () => scheduler.schedule(
          draftLocalId: any(named: 'draftLocalId'),
          scheduledAtUtc: any(named: 'scheduledAtUtc'),
          notificationId: any(named: 'notificationId'),
          title: any(named: 'title'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => remote.createReminder(
          draftLocalId: any(named: 'draftLocalId'),
          scheduledAtUtc: any(named: 'scheduledAtUtc'),
        ),
      ).thenThrow(
        ApiException(
          const ApiFailure(
            type: ApiErrorType.network,
            message: 'No connection.',
          ),
        ),
      );

      final result = await repository.schedule(
        reminder,
        notificationTitle: 'Time to post!',
        notificationBody: 'Your draft is ready.',
      );

      expect(result.isOk, isTrue);
      // Let the unawaited background call actually run before the test
      // ends, so a swallow bug (an exception escaping the fire-and-forget
      // call) would surface here rather than in some unrelated test.
      await Future<void>.delayed(Duration.zero);
    });
  });

  group('cancel', () {
    test("cancels the notification id derived from the draft's localId (same "
        'derivation Reminder.notificationId uses, so a cancel always targets '
        'the exact id a matching schedule() call would have used)', () async {
      when(() => scheduler.cancel(any())).thenAnswer((_) async {});

      final result = await repository.cancel('draft-1');

      expect(result.isOk, isTrue);
      verify(() => scheduler.cancel(reminder.notificationId)).called(1);
    });

    test('a LocalNotificationScheduler.cancel failure surfaces as '
        'UnexpectedFailure rather than propagating', () async {
      when(() => scheduler.cancel(any())).thenThrow(StateError('boom'));

      final result = await repository.cancel('draft-1');

      expect(result.isErr, isTrue);
      result.when(
        ok: (_) => fail('expected an error'),
        err: (failure) => expect(failure, isA<UnexpectedFailure>()),
      );
    });
  });
}
