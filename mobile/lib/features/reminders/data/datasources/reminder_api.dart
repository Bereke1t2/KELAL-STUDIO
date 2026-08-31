import 'package:dio/dio.dart' hide Headers;
import 'package:kelal_studio/features/reminders/data/models/create_reminder_request_dto.dart';
import 'package:retrofit/retrofit.dart';

part 'reminder_api.g.dart';

/// Retrofit-generated real client, code-first but kept in sync by hand
/// with mobile/api_contract/openapi.yaml (`POST /reminders`). Run
/// `dart run build_runner build` after editing. See
/// mobile/.claude/skills/flutter-networking-data/SKILL.md for why this
/// project doesn't (yet) auto-generate from the YAML directly.
@RestApi()
abstract class ReminderApi {
  factory ReminderApi(Dio dio, {String baseUrl}) = _ReminderApi;

  @POST('/reminders')
  Future<void> createReminder(@Body() CreateReminderRequestDto body);
}
