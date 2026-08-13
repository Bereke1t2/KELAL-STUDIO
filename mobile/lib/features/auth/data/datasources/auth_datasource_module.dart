import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import 'package:kelal_studio/core/env/env.dart';
import 'package:kelal_studio/features/auth/data/datasources/auth_api.dart';
import 'package:kelal_studio/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:kelal_studio/features/auth/data/datasources/fake_auth_remote_data_source.dart';
import 'package:kelal_studio/features/auth/data/datasources/real_auth_remote_data_source.dart';

/// The mock/real swap point promised by the architecture plan: exactly one
/// place decides which [AuthRemoteDataSource] implementation the rest of
/// the app gets, driven by [Env.useMockApi] (a build-time `--dart-define`,
/// not a hardcoded choice). No other file should instantiate
/// [FakeAuthRemoteDataSource] or [RealAuthRemoteDataSource] directly.
@module
abstract class AuthDataSourceModule {
  @lazySingleton
  AuthRemoteDataSource authRemoteDataSource(Dio dio) {
    if (Env.useMockApi) return FakeAuthRemoteDataSource();
    return RealAuthRemoteDataSource(AuthApi(dio));
  }
}
