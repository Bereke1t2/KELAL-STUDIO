import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import 'package:kelal_studio/core/env/env.dart';
import 'package:kelal_studio/features/reminders/data/datasources/fake_reminder_remote_data_source.dart';
import 'package:kelal_studio/features/reminders/data/datasources/real_reminder_remote_data_source.dart';
import 'package:kelal_studio/features/reminders/data/datasources/reminder_api.dart';
import 'package:kelal_studio/features/reminders/data/datasources/reminder_remote_data_source.dart';

/// The mock/real swap point promised by the architecture plan: exactly one
/// place decides which [ReminderRemoteDataSource] implementation the rest
/// of the app gets, driven by [Env.useMockApi] — mirrors
/// `features/quota/data/datasources/quota_datasource_module.dart`. No other
/// file should instantiate [FakeReminderRemoteDataSource] or
/// [RealReminderRemoteDataSource] directly.
@module
abstract class ReminderDataSourceModule {
  @lazySingleton
  ReminderRemoteDataSource reminderRemoteDataSource(Dio dio) {
    if (Env.useMockApi) return FakeReminderRemoteDataSource();
    return RealReminderRemoteDataSource(ReminderApi(dio));
  }
}
