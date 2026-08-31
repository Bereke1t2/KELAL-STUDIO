import 'package:kelal_studio/core/network/api_exception_mapper.dart';
import 'package:kelal_studio/core/network/fake_backend_support.dart';
import 'package:kelal_studio/features/reminders/data/datasources/reminder_api.dart';
import 'package:kelal_studio/features/reminders/data/datasources/reminder_remote_data_source.dart';
import 'package:kelal_studio/features/reminders/data/models/create_reminder_request_dto.dart';

/// Wraps the generated [ReminderApi], translating every `DioException` into
/// an [ApiException] at the boundary — same shape as
/// `features/quota/data/datasources/real_quota_remote_data_source.dart`.
/// Selected instead of `FakeReminderRemoteDataSource` by
/// `reminder_datasource_module.dart` when `Env.useMockApi` is false.
class RealReminderRemoteDataSource implements ReminderRemoteDataSource {
  RealReminderRemoteDataSource(this._api);

  final ReminderApi _api;
  static const _mapper = ApiExceptionMapper();

  @override
  Future<void> createReminder({
    required String draftLocalId,
    required DateTime scheduledAtUtc,
  }) async {
    try {
      await _api.createReminder(
        CreateReminderRequestDto(
          draftLocalId: draftLocalId,
          scheduledAtUtc: scheduledAtUtc,
        ),
      );
    } catch (error) {
      throw ApiException(_mapper.map(error));
    }
  }
}
