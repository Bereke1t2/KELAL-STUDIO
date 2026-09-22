import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import 'package:kelal_studio/core/env/env.dart';
import 'package:kelal_studio/features/generation/data/datasources/fake_generation_remote_data_source.dart';
import 'package:kelal_studio/features/generation/data/datasources/generation_api.dart';
import 'package:kelal_studio/features/generation/data/datasources/generation_remote_data_source.dart';
import 'package:kelal_studio/features/generation/data/datasources/real_generation_remote_data_source.dart';
import 'package:kelal_studio/features/quota/data/datasources/fake_quota_remote_data_source.dart';
import 'package:kelal_studio/features/quota/data/datasources/quota_remote_data_source.dart';

/// The mock/real swap point promised by the architecture plan: exactly one
/// place decides which [GenerationRemoteDataSource] implementation the
/// rest of the app gets, driven by [Env.useMockApi] — mirrors
/// `features/quota/data/datasources/quota_datasource_module.dart`. No
/// other file should instantiate [FakeGenerationRemoteDataSource] or
/// [RealGenerationRemoteDataSource] directly.
@module
abstract class GenerationDataSourceModule {
  @lazySingleton
  GenerationRemoteDataSource generationRemoteDataSource(
    Dio dio,
    // Same `@lazySingleton` instance `QuotaBloc`/`QuotaStatusBadge` reads
    // (see `QuotaDataSourceModule`) — `FakeGenerationRemoteDataSource`
    // needs the concrete fake to share its counters, not just the
    // interface `getQuota()` alone can't offer. The cast is safe exactly
    // because it's guarded by the same `Env.useMockApi` branch the quota
    // module itself branches on: when true, `quotaRemoteDataSource` is
    // always the fake, never `RealQuotaRemoteDataSource`.
    QuotaRemoteDataSource quotaRemoteDataSource,
  ) {
    if (Env.useMockApi) {
      return FakeGenerationRemoteDataSource(
        quotaRemoteDataSource as FakeQuotaRemoteDataSource,
      );
    }
    return RealGenerationRemoteDataSource(GenerationApi(dio));
  }
}
