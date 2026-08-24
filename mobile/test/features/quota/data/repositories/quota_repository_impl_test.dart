import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/network/fake_backend_support.dart';
import 'package:kelal_studio/features/quota/data/datasources/quota_remote_data_source.dart';
import 'package:kelal_studio/features/quota/data/models/quota_dto.dart';
import 'package:kelal_studio/features/quota/data/repositories/quota_repository_impl.dart';
import 'package:kelal_studio/features/quota/domain/entities/quota.dart';
import 'package:mocktail/mocktail.dart';

class MockQuotaRemoteDataSource extends Mock implements QuotaRemoteDataSource {}

void main() {
  late MockQuotaRemoteDataSource remote;
  late QuotaRepositoryImpl repository;

  setUp(() {
    remote = MockQuotaRemoteDataSource();
    repository = QuotaRepositoryImpl(remote);
  });

  final dto = QuotaDto(
    textCallsUsed: 3,
    textCallsLimit: 10,
    imageCallsUsed: 1,
    imageCallsLimit: 5,
    resetsAt: DateTime.utc(2026, 1, 1, 18),
  );

  final entity = Quota(
    textCallsUsed: 3,
    textCallsLimit: 10,
    imageCallsUsed: 1,
    imageCallsLimit: 5,
    resetsAt: DateTime.utc(2026, 1, 1, 18),
  );

  group('getQuota', () {
    test('maps a successful DTO response to the domain entity', () async {
      when(remote.getQuota).thenAnswer((_) async => dto);

      final result = await repository.getQuota();

      expect(result.isOk, isTrue);
      expect(result.valueOrNull, entity);
    });

    test('maps an ApiException to a Result.err', () async {
      when(remote.getQuota).thenThrow(
        ApiException(
          const ApiFailure(
            type: ApiErrorType.network,
            message: 'No connection. Check your network and try again.',
          ),
        ),
      );

      final result = await repository.getQuota();

      expect(result.isErr, isTrue);
      result.when(
        ok: (_) => fail('expected an error'),
        err: (failure) => expect(failure, isA<ApiFailure>()),
      );
    });

    test('maps an unanticipated exception to UnexpectedFailure rather than '
        'propagating it', () async {
      when(remote.getQuota).thenThrow(StateError('boom'));

      final result = await repository.getQuota();

      expect(result.isErr, isTrue);
      result.when(
        ok: (_) => fail('expected an error'),
        err: (failure) => expect(failure, isA<UnexpectedFailure>()),
      );
    });
  });
}
