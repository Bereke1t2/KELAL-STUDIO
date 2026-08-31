import 'package:equatable/equatable.dart';

/// PRD §6.12/§8.5's Local Post Reminder — one reminder is scheduled
/// against exactly one `Draft` (see
/// `features/drafts/domain/entities/draft.dart`), never a bare id with no
/// draft behind it. [scheduledAtUtc] is always UTC (PRD §6.12: convert
/// only at the presentation layer, e.g. `pickReminderDateTimeUtc`'s
/// `TimeOfDay`/`DateTime` round trip) — never store or compare a local
/// `DateTime` anywhere below the UI layer.
class Reminder extends Equatable {
  const Reminder({required this.draftLocalId, required this.scheduledAtUtc});

  final String draftLocalId;
  final DateTime scheduledAtUtc;

  /// The `flutter_local_notifications` notification id this reminder maps
  /// to — deterministically derived from [draftLocalId] rather than
  /// stored anywhere, so cancelling a reminder never needs a lookup table:
  /// given a draft, this id is always reproducible.
  int get notificationId => notificationIdFor(draftLocalId);

  /// Same derivation as [notificationId], usable without constructing a
  /// full [Reminder] — `ReminderRepositoryImpl.cancel` only ever has a bare
  /// `draftLocalId` on hand, no [scheduledAtUtc] to build one with.
  /// `.hashCode` can be negative; the platform notification id must be a
  /// non-negative 32-bit int, hence the `& 0x7FFFFFFF` mask (clears the
  /// sign bit) rather than `.abs()` (which can itself overflow at
  /// `Int32.minValue`).
  static int notificationIdFor(String draftLocalId) =>
      draftLocalId.hashCode & 0x7FFFFFFF;

  @override
  List<Object?> get props => [draftLocalId, scheduledAtUtc];
}
