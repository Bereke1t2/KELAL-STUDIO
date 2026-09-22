import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/network/fake_backend_support.dart';
import 'package:kelal_studio/features/generation/data/datasources/fake_generation_remote_data_source.dart';
import 'package:kelal_studio/features/quota/data/datasources/fake_quota_remote_data_source.dart';

// This app's demo/mock login credentials seed FakeQuotaRemoteDataSource at
// 3/10 text calls and 1/5 image calls used (see that class's doc comment)
// — driven to the boundary below via its public recordTextCall/
// recordImageCall rather than the private counters, since real
// FakeGenerationRemoteDataSource.generateText/generateImage calls also roll
// other, unrelated random failures (moderationRefused etc.) that would
// make a test relying on repeated real calls flaky.

void main() {
  group('generateText quota enforcement', () {
    test(
      'throws ApiException(quotaExceeded) once the shared quota counter is '
      'already at its limit, without ever reaching the random-failure rolls',
      () async {
        final quota = FakeQuotaRemoteDataSource();
        // Seeded at 3; 7 more reaches the placeholder 10 limit.
        for (var i = 0; i < 7; i++) {
          quota.recordTextCall();
        }
        expect(quota.isTextQuotaExceeded, isTrue);
        final source = FakeGenerationRemoteDataSource(quota);

        await expectLater(
          source.generateText(
            inputText: 'A sale this weekend',
            inputLang: 'en',
            platform: 'instagram',
          ),
          throwsA(
            isA<ApiException>().having(
              (e) => e.failure.type,
              'type',
              ApiErrorType.quotaExceeded,
            ),
          ),
        );
      },
    );

    test(
      'a call accepted below the quota limit records usage against the '
      'shared counter — this is what keeps QuotaStatusBadge and Generate '
      'in agreement (the bug this class was changed to fix)',
      () async {
        final quota = FakeQuotaRemoteDataSource();
        // Drive to one below the limit (3 seeded + 6 = 9), deterministically.
        for (var i = 0; i < 6; i++) {
          quota.recordTextCall();
        }
        expect(quota.isTextQuotaExceeded, isFalse);
        final source = FakeGenerationRemoteDataSource(quota);

        // The call may itself throw one of the unrelated random failures
        // (moderationRefused, providerTimeout, ...) — that's fine and
        // expected some of the time; what matters here is that usage was
        // still recorded on acceptance either way (see generateText's own
        // doc comment for why acceptance, not eventual success, counts).
        try {
          await source.generateText(
            inputText: 'A sale this weekend',
            inputLang: 'en',
            platform: 'instagram',
          );
        } on ApiException catch (_) {
          // Ignored — any non-quota typed failure still means the call was
          // accepted and should have recorded usage.
        }

        expect(quota.isTextQuotaExceeded, isTrue);
      },
    );
  });

  group('generateImage quota enforcement', () {
    test(
      'throws ApiException(quotaExceeded) once the shared quota counter is '
      'already at its limit',
      () async {
        final quota = FakeQuotaRemoteDataSource();
        // Seeded at 1; 4 more reaches the placeholder 5 limit.
        for (var i = 0; i < 4; i++) {
          quota.recordImageCall();
        }
        expect(quota.isImageQuotaExceeded, isTrue);
        final source = FakeGenerationRemoteDataSource(quota);

        await expectLater(
          source.generateImage(
            captionEn: 'Check out our weekend sale',
            aspectRatio: '1:1',
            brandKitId: 'brand-kit-1',
          ),
          throwsA(
            isA<ApiException>().having(
              (e) => e.failure.type,
              'type',
              ApiErrorType.quotaExceeded,
            ),
          ),
        );
      },
    );
  });
}
