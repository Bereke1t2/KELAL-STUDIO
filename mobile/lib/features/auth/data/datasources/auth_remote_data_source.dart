import 'package:dio/dio.dart' show DioException;

import 'package:kelal_studio/core/network/fake_backend_support.dart'
    show ApiException;

import 'package:kelal_studio/features/auth/data/datasources/auth_api.dart'
    show AuthApi;

import 'package:kelal_studio/features/auth/data/datasources/fake_auth_remote_data_source.dart'
    show FakeAuthRemoteDataSource;

import 'package:kelal_studio/features/auth/data/models/auth_tokens_dto.dart';

/// Implemented by both [AuthApi]-backed real data source and
/// [FakeAuthRemoteDataSource]. The repository depends only on this
/// interface — see mobile/.claude/skills/flutter-networking-data/SKILL.md
/// for the mock/real swap mechanism (`core/di/auth_datasource_module.dart`).
///
/// Throws [ApiException] (never a raw [DioException]) on failure — mapping
/// happens once, at the edge, via `core/network/api_exception_mapper.dart`.
abstract class AuthRemoteDataSource {
  Future<AuthTokensDto> login({
    required String email,
    required String password,
  });
}
