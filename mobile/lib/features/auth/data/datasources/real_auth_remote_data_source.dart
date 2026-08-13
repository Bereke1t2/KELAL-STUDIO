import 'package:dio/dio.dart' show DioException;
import 'package:kelal_studio/core/network/api_exception_mapper.dart';
import 'package:kelal_studio/core/network/fake_backend_support.dart';
import 'package:kelal_studio/features/auth/data/datasources/auth_api.dart';
import 'package:kelal_studio/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:kelal_studio/features/auth/data/datasources/fake_auth_remote_data_source.dart'
    show FakeAuthRemoteDataSource;
import 'package:kelal_studio/features/auth/data/models/auth_tokens_dto.dart';

/// Wraps the generated [AuthApi], translating every [DioException] into an
/// [ApiException] at the boundary so nothing above `data/datasources` ever
/// has to know dio exists. Selected instead of [FakeAuthRemoteDataSource]
/// by `core/di/auth_datasource_module.dart` when `Env.useMockApi` is false.
class RealAuthRemoteDataSource implements AuthRemoteDataSource {
  RealAuthRemoteDataSource(this._api);

  final AuthApi _api;
  static const _mapper = ApiExceptionMapper();

  @override
  Future<AuthTokensDto> login({
    required String email,
    required String password,
  }) async {
    try {
      return await _api.login({'email': email, 'password': password});
    } catch (error) {
      throw ApiException(_mapper.map(error));
    }
  }
}
