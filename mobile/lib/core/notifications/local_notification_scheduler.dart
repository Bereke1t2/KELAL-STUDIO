import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:injectable/injectable.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Provides the single [FlutterLocalNotificationsPlugin] instance — every
/// scheduling call goes through [LocalNotificationScheduler] below, never a
/// second raw plugin instance. Mirrors `core/network/dio_client.dart`'s
/// "one instance, one module" pattern.
@module
abstract class NotificationsModule {
  @lazySingleton
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin() =>
      FlutterLocalNotificationsPlugin();
}

/// Wraps `flutter_local_notifications` for PRD §10.5/§8.5's Local Post
/// Reminders: scheduling a one-shot local notification against a draft, and
/// surfacing taps on a fired notification so the app can deep-link (see
/// [onNotificationTapped]).
///
/// **Permission model**: uses `permission_handler`'s
/// [Permission.notification] rather than the plugin's own iOS-only
/// `requestPermissions()` method, so one call covers Android 13+'s runtime
/// `POST_NOTIFICATIONS` prompt and iOS's authorization prompt identically —
/// see the justification comment on `permission_handler` in `pubspec.yaml`.
///
/// **Scheduling mode**: [AndroidScheduleMode.inexactAllowWhileIdle] is used
/// deliberately instead of an exact alarm. A Local Post Reminder firing a
/// few minutes late is an acceptable trade PRD §10.5 doesn't rule out, and
/// avoids requiring the far more invasive `SCHEDULE_EXACT_ALARM`/
/// `USE_EXACT_ALARM` permission (a user-facing "Alarms & reminders" special
/// access grant on Android 12+) for what's explicitly a soft nudge, not a
/// time-critical alarm. See `AndroidManifest.xml`'s matching comment.
@lazySingleton
class LocalNotificationScheduler {
  LocalNotificationScheduler(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  final _tapController = StreamController<String>.broadcast();

  static const _channelId = 'post_reminders';
  static const _channelName = 'Post reminders';
  static const _channelDescription =
      'Reminders to publish a saved draft, scheduled from the Drafts tab.';

  /// Emits a draft's `localId` whenever the user taps a fired reminder
  /// notification — see `AndroidManifest.xml`/`bootstrap.dart` for where
  /// this is wired to `AppRouter`'s deep-link handling (PRD §8.5).
  Stream<String> get onNotificationTapped => _tapController.stream;

  bool _initialized = false;

  /// Must be called once, before the first [schedule]/[cancel] call — see
  /// `bootstrap.dart`. Idempotent so tests/hot-restart can call it safely
  /// more than once.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (response) {
        final draftLocalId = response.payload;
        if (draftLocalId != null && draftLocalId.isNotEmpty) {
          _tapController.add(draftLocalId);
        }
      },
    );
  }

  /// Prompts for notification permission if not already determined. Call
  /// this at the point the user actually asks for a reminder (the "Remind
  /// me" action on a draft), not unconditionally at app start — asking in
  /// context is standard platform guidance for both Android 13+ and iOS.
  Future<bool> requestPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Schedules a one-shot local notification for [draftLocalId] at
  /// [scheduledAtUtc]. [scheduledAtUtc] is stored/passed as UTC throughout
  /// (PRD §6.12) and converted to the device's local timezone only here, at
  /// the scheduling boundary, via [tz.TZDateTime.from].
  Future<void> schedule({
    required String draftLocalId,
    required DateTime scheduledAtUtc,
    required int notificationId,
    required String title,
    required String body,
  }) async {
    await _plugin.zonedSchedule(
      id: notificationId,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledAtUtc, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: draftLocalId,
    );
  }

  Future<void> cancel(int notificationId) => _plugin.cancel(id: notificationId);
}
