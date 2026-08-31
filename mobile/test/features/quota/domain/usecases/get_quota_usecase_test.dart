import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/quota/domain/entities/quota.dart';
import 'package:kelal_studio/features/quota/domain/repositories/quota_repository.dart';
import 'package:kelal_studio/features/quota/domain/usecases/get_quota_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockQuotaRepository extends Mock implements QuotaRepository {}

void main() {
  late MockQuotaRepository repository;
  late GetQuotaUseCase useCase;

  setUp(() {
    repository = MockQuotaRepository();
    useCase = GetQuotaUseCase(repository);
  });

  final quota = Quota(
    textCallsUsed: 3,
    textCallsLimit: 10,
    imageCallsUsed: 1,
    imageCallsLimit: 5,
    resetsAt: DateTime.utc(2026, 1, 1, 18),
  );

  test('delegates directly to QuotaRepository.getQuota and forwards its '
      'Result unchanged', () async {
    when(repository.getQuota).thenAnswer((_) async => Result.ok(quota));

    final result = await useCase();

    expect(result.isOk, isTrue);
    expect(result.valueOrNull, quota);
    verify(repository.getQuota).called(1);
  });

  test('forwards a failure Result unchanged', () async {
    const failure = ApiFailure(
      type: ApiErrorType.network,
      message: 'No connection. Check your network and try again.',
    );
    when(
      repository.getQuota,
    ).thenAnswer((_) async => const Result.err(failure));

    final result = await useCase();

    expect(result.isErr, isTrue);
    result.when(
      ok: (_) => fail('expected an error'),
      err: (f) => expect(f, failure),
    );
  });
}
