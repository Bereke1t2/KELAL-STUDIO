import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import 'package:kelal_studio/core/env/env.dart';
import 'package:kelal_studio/features/generation/data/datasources/fake_generation_remote_data_source.dart';
import 'package:kelal_studio/features/generation/data/datasources/generation_api.dart';
import 'package:kelal_studio/features/generation/data/datasources/generation_remote_data_source.dart';
import 'package:kelal_studio/features/generation/data/datasources/real_generation_remote_data_source.dart';

/// The mock/real swap point promised by the architecture plan: exactly one
/// place decides which [GenerationRemoteDataSource] implementation the
/// rest of the app gets, driven by [Env.useMockApi] — mirrors
/// `features/quota/data/datasources/quota_datasource_module.dart`. No
/// other file should instantiate [FakeGenerationRemoteDataSource] or
/// [RealGenerationRemoteDataSource] directly.
@module
abstract class GenerationDataSourceModule {
  @lazySingleton
  GenerationRemoteDataSource generationRemoteDataSource(Dio dio) {
    if (Env.useMockApi) return FakeGenerationRemoteDataSource();
    return RealGenerationRemoteDataSource(GenerationApi(dio));
  }
}
