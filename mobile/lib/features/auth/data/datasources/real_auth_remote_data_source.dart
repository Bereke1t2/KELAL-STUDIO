import 'package:dio/dio.dart' show DioException;
import 'package:kelal_studio/core/network/api_exception_mapper.dart';
import 'package:kelal_studio/core/network/fake_backend_support.dart';
import 'package:kelal_studio/features/auth/data/datasources/auth_api.dart';
import 'package:kelal_studio/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:kelal_studio/features/auth/data/datasources/fake_auth_remote_data_source.dart'
    show FakeAuthRemoteDataSource;
import 'package:kelal_studio/features/auth/data/models/auth_tokens_dto.dart';
import 'package:kelal_studio/features/auth/data/models/registration_result_dto.dart';

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

  @override
  Future<RegistrationResultDto> register({
    required String email,
    required String password,
  }) async {
    try {
      return await _api.register({'email': email, 'password': password});
    } catch (error) {
      throw ApiException(_mapper.map(error));
    }
  }

  @override
  Future<bool> verifyEmail({required String token}) async {
    try {
      final result = await _api.verifyEmail({'token': token});
      return result.verified;
    } catch (error) {
      throw ApiException(_mapper.map(error));
    }
  }

  @override
  Future<void> resendVerification({required String email}) async {
    try {
      await _api.resendVerification({'email': email});
    } catch (error) {
      throw ApiException(_mapper.map(error));
    }
  }

  @override
  Future<AuthTokensDto> refresh({required String refreshToken}) async {
    try {
      return await _api.refresh({'refresh_token': refreshToken});
    } catch (error) {
      // A reuse/expiry signal from the real backend surfaces here as a
      // mapped 401 -> ApiErrorType.unauthorized, same as every other
      // endpoint — no special-casing needed; the caller (AuthInterceptor)
      // already treats any ApiException from this call as "refresh
      // failed, force re-auth."
      throw ApiException(_mapper.map(error));
    }
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    try {
      await _api.requestPasswordReset({'email': email});
    } catch (error) {
      throw ApiException(_mapper.map(error));
    }
  }

  @override
  Future<void> confirmPasswordReset({
    required String token,
    required String newPassword,
  }) async {
    try {
      await _api.confirmPasswordReset({
        'token': token,
        'new_password': newPassword,
      });
    } catch (error) {
      throw ApiException(_mapper.map(error));
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      await _api.deleteAccount();
    } catch (error) {
      throw ApiException(_mapper.map(error));
    }
  }
}
