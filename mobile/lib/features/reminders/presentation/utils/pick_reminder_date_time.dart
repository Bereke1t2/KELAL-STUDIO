import 'package:flutter/material.dart';

/// Drives Material's built-in date + time pickers back-to-back and combines
/// the result into a single UTC `DateTime`, ready to hand straight to
/// `DraftReminderRequested` (PRD §6.12: convert to UTC at the presentation
/// layer, store/compare UTC everywhere below it).
///
/// No custom `AppBottomSheet`-based picker UI exists for this — `showDatePicker`/
/// `showTimePicker` are the platform's own accessible, localized picker
/// widgets and there's no design-system-catalogued custom picker in Figma
/// for this flow, so reusing the Material default is the deliberate choice
/// here rather than a gap.
///
/// Returns `null` if the user backs out of either step. Only ever offers
/// times from "now" onward — a reminder scheduled in the past would never
/// fire.
Future<DateTime?> pickReminderDateTimeUtc(BuildContext context) async {
  final now = DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: now,
    firstDate: now,
    lastDate: now.add(const Duration(days: 365)),
  );
  if (date == null) return null;
  if (!context.mounted) return null;

  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(now),
  );
  if (time == null) return null;

  return combineReminderDateTimeUtc(date: date, time: time, now: now);
}

/// The pure combine-and-clamp step, split out so it's unit-testable without
/// driving real `showDatePicker`/`showTimePicker` widgets.
///
/// **Past-time clamp (a real edge case, not a hypothetical)**: `showDatePicker`
/// only refuses a date before [now], but [time] is picked independently and
/// has no such floor — picking today's date, then a time earlier than [now]
/// (e.g. it's 3pm and the user picks 1pm), combines into a moment already in
/// the past. Scheduling a past `zonedSchedule` call is undefined/plugin-
/// dependent behavior (fires immediately on some platforms, throws on
/// others), so this clamps forward to one minute from [now] instead of
/// passing a past `DateTime` through — the least surprising outcome given
/// the user asked to be reminded "now-ish", not for a crash.
@visibleForTesting
DateTime combineReminderDateTimeUtc({
  required DateTime date,
  required TimeOfDay time,
  required DateTime now,
}) {
  final local = DateTime(
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
  );
  if (!local.isAfter(now)) {
    return now.toUtc().add(const Duration(minutes: 1));
  }
  return local.toUtc();
}
