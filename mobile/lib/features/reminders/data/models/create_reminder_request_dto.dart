import 'package:freezed_annotation/freezed_annotation.dart';

part 'create_reminder_request_dto.freezed.dart';
part 'create_reminder_request_dto.g.dart';

/// Wire model matching `POST /reminders`'s request body in
/// mobile/api_contract/openapi.yaml — `draft_local_id`/`scheduled_at_utc`,
/// both required. The endpoint returns a bare `201 Created` with no
/// response body, so there's no matching response DTO (see
/// `ReminderApi.createReminder`'s `Future<void>` return type).
@freezed
abstract class CreateReminderRequestDto with _$CreateReminderRequestDto {
  const factory CreateReminderRequestDto({
    @JsonKey(name: 'draft_local_id') required String draftLocalId,
    @JsonKey(name: 'scheduled_at_utc') required DateTime scheduledAtUtc,
  }) = _CreateReminderRequestDto;

  factory CreateReminderRequestDto.fromJson(Map<String, dynamic> json) =>
      _$CreateReminderRequestDtoFromJson(json);
}
