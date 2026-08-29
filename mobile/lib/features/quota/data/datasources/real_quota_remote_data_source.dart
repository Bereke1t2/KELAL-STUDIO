import 'package:kelal_studio/core/network/api_exception_mapper.dart';
import 'package:kelal_studio/core/network/fake_backend_support.dart';
import 'package:kelal_studio/features/quota/data/datasources/quota_api.dart';
import 'package:kelal_studio/features/quota/data/datasources/quota_remote_data_source.dart';
import 'package:kelal_studio/features/quota/data/models/quota_dto.dart';

/// Wraps the generated [QuotaApi], translating every `DioException` into an
/// [ApiException] at the boundary — same shape as
/// `features/brand_kit/data/datasources/real_brand_kit_remote_data_source.dart`.
/// Selected instead of `FakeQuotaRemoteDataSource` by
/// `quota_datasource_module.dart` when `Env.useMockApi` is false.
///
/// Unlike `RealBrandKitRemoteDataSource`, `GET /quota/me` has no id-in-path
/// problem — it's a bearer-auth-scoped "my quota" endpoint, so this class
/// has no equivalent contract gap to flag.
class RealQuotaRemoteDataSource implements QuotaRemoteDataSource {
  RealQuotaRemoteDataSource(this._api);

  final QuotaApi _api;
  static const _mapper = ApiExceptionMapper();

  @override
  Future<QuotaDto> getQuota() async {
    try {
      return await _api.getMyQuota();
    } catch (error) {
      throw ApiException(_mapper.map(error));
    }
  }
}
