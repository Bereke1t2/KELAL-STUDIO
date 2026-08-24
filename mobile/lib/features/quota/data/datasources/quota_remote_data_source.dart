import 'package:kelal_studio/core/network/fake_backend_support.dart'
    show ApiException;

import 'package:kelal_studio/features/quota/data/datasources/fake_quota_remote_data_source.dart'
    show FakeQuotaRemoteDataSource;

import 'package:kelal_studio/features/quota/data/datasources/quota_api.dart'
    show QuotaApi;

import 'package:kelal_studio/features/quota/data/models/quota_dto.dart';

/// Implemented by both the [QuotaApi]-backed real data source and
/// [FakeQuotaRemoteDataSource]. The repository depends only on this
/// interface — see mobile/.claude/skills/flutter-networking-data/SKILL.md
/// for the mock/real swap mechanism (`quota_datasource_module.dart`).
///
/// Throws [ApiException] (never a raw `DioException`) on failure — mapping
/// happens once, at the edge, via `core/network/api_exception_mapper.dart`.
abstract class QuotaRemoteDataSource {
  Future<QuotaDto> getQuota();
}
