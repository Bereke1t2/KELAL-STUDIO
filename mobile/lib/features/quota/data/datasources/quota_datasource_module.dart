import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import 'package:kelal_studio/core/env/env.dart';
import 'package:kelal_studio/features/quota/data/datasources/fake_quota_remote_data_source.dart';
import 'package:kelal_studio/features/quota/data/datasources/quota_api.dart';
import 'package:kelal_studio/features/quota/data/datasources/quota_remote_data_source.dart';
import 'package:kelal_studio/features/quota/data/datasources/real_quota_remote_data_source.dart';

/// The mock/real swap point promised by the architecture plan: exactly one
/// place decides which [QuotaRemoteDataSource] implementation the rest of
/// the app gets, driven by [Env.useMockApi] — mirrors
/// `features/brand_kit/data/datasources/brand_kit_datasource_module.dart`.
/// No other file should instantiate [FakeQuotaRemoteDataSource] or
/// [RealQuotaRemoteDataSource] directly.
@module
abstract class QuotaDataSourceModule {
  @lazySingleton
  QuotaRemoteDataSource quotaRemoteDataSource(Dio dio) {
    if (Env.useMockApi) return FakeQuotaRemoteDataSource();
    return RealQuotaRemoteDataSource(QuotaApi(dio));
  }
}
