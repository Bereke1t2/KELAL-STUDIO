import 'package:injectable/injectable.dart';

import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/network/fake_backend_support.dart';
import 'package:kelal_studio/features/quota/data/datasources/quota_remote_data_source.dart';
import 'package:kelal_studio/features/quota/data/models/quota_dto.dart';
import 'package:kelal_studio/features/quota/domain/entities/quota.dart';
import 'package:kelal_studio/features/quota/domain/repositories/quota_repository.dart';

@LazySingleton(as: QuotaRepository)
class QuotaRepositoryImpl implements QuotaRepository {
  QuotaRepositoryImpl(this._remote);

  final QuotaRemoteDataSource _remote;

  Quota _toDomain(QuotaDto dto) => Quota(
    textCallsUsed: dto.textCallsUsed,
    textCallsLimit: dto.textCallsLimit,
    imageCallsUsed: dto.imageCallsUsed,
    imageCallsLimit: dto.imageCallsLimit,
    resetsAt: dto.resetsAt,
  );

  @override
  Future<Result<Failure, Quota>> getQuota() async {
    try {
      final dto = await _remote.getQuota();
      return Result.ok(_toDomain(dto));
    } on ApiException catch (e) {
      return Result.err(e.failure);
    }
    // Deliberate catch-all: this is the repository boundary — per
    // flutter-architecture, nothing above this layer may throw, so any
    // exception type we didn't anticipate still needs to become a
    // Result.err rather than propagate.
    // ignore: avoid_catches_without_on_clauses
    catch (_) {
      return const Result.err(
        UnexpectedFailure('Something went wrong. Please try again.'),
      );
    }
  }
}
