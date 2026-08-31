import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import 'package:kelal_studio/core/env/env.dart';
import 'package:kelal_studio/core/storage/secure_token_storage.dart';
import 'package:kelal_studio/features/brand_kit/data/datasources/brand_kit_api.dart';
import 'package:kelal_studio/features/brand_kit/data/datasources/brand_kit_remote_data_source.dart';
import 'package:kelal_studio/features/brand_kit/data/datasources/fake_brand_kit_remote_data_source.dart';
import 'package:kelal_studio/features/brand_kit/data/datasources/real_brand_kit_remote_data_source.dart';

/// The mock/real swap point promised by the architecture plan: exactly one
/// place decides which [BrandKitRemoteDataSource] implementation the rest
/// of the app gets, driven by [Env.useMockApi] — mirrors
/// `features/auth/data/datasources/auth_datasource_module.dart`. No other
/// file should instantiate [FakeBrandKitRemoteDataSource] or
/// [RealBrandKitRemoteDataSource] directly.
@module
abstract class BrandKitDataSourceModule {
  @lazySingleton
  BrandKitRemoteDataSource brandKitRemoteDataSource(
    Dio dio,
    SecureTokenStorage tokenStorage,
  ) {
    if (Env.useMockApi) return FakeBrandKitRemoteDataSource();
    return RealBrandKitRemoteDataSource(BrandKitApi(dio), tokenStorage);
  }
}
