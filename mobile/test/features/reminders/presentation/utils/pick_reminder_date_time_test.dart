import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/features/reminders/presentation/utils/pick_reminder_date_time.dart';

void main() {
  group('combineReminderDateTimeUtc', () {
    test('combines a future date/time and converts to UTC', () {
      final now = DateTime(2026, 9, 1, 10);

      final result = combineReminderDateTimeUtc(
        date: DateTime(2026, 9),
        time: const TimeOfDay(hour: 18, minute: 30),
        now: now,
      );

      expect(result, DateTime(2026, 9, 1, 18, 30).toUtc());
    });

    test("clamps forward to one minute from 'now' when the combined date/time "
        "has already passed (e.g. today's date with an earlier time) — "
        'showTimePicker has no floor of its own, unlike showDatePicker', () {
      final now = DateTime(2026, 9, 1, 15);

      final result = combineReminderDateTimeUtc(
        date: DateTime(2026, 9),
        time: const TimeOfDay(hour: 13, minute: 0),
        now: now,
      );

      expect(result, now.toUtc().add(const Duration(minutes: 1)));
    });

    test('a combined time exactly equal to now is also clamped forward', () {
      final now = DateTime(2026, 9, 1, 15, 30);

      final result = combineReminderDateTimeUtc(
        date: DateTime(2026, 9),
        time: const TimeOfDay(hour: 15, minute: 30),
        now: now,
      );

      expect(result, now.toUtc().add(const Duration(minutes: 1)));
    });
  });
}
