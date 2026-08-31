import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/network/authenticated_asset_client.dart';
import 'package:kelal_studio/core/storage/secure_token_storage.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

class MockSecureTokenStorage extends Mock implements SecureTokenStorage {}

void main() {
  late MockDio dio;
  late MockSecureTokenStorage tokenStorage;
  late AuthenticatedAssetClient client;

  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(Options());
  });

  setUp(() {
    dio = MockDio();
    tokenStorage = MockSecureTokenStorage();
    client = AuthenticatedAssetClient(dio, tokenStorage);
  });

  Response<List<int>> bytesResponse(List<int> bytes) =>
      Response(data: bytes, requestOptions: RequestOptions());

  group('fetchBytes', () {
    // This is the exact bug this class exists to fix — see its own doc
    // comment. A relative/absolute-path URL is this app's own API, and
    // the real backend's `GET /assets/{id}` is bearer-authenticated; the
    // request must carry the token or every generated image/saved logo
    // 401s.
    test(
      'attaches the bearer token for a relative (same-origin) url',
      () async {
        when(
          () => tokenStorage.readAccessToken(),
        ).thenAnswer((_) async => 'token-123');
        when(
          () => dio.getUri<List<int>>(any(), options: any(named: 'options')),
        ).thenAnswer((_) async => bytesResponse([1, 2, 3]));

        await client.fetchBytes('/v1/assets/abc-123');

        final captured = verify(
          () => dio.getUri<List<int>>(
            captureAny(),
            options: captureAny(named: 'options'),
          ),
        ).captured;
        final uri = captured[0] as Uri;
        final options = captured[1] as Options;
        expect(uri.path, '/v1/assets/abc-123');
        expect(options.headers?['Authorization'], 'Bearer token-123');
      },
    );

    // The security-critical negative case: a genuinely third-party URL
    // must never receive this app's bearer token, or a compromised/
    // malicious `image_url` could exfiltrate it to an arbitrary host.
    test('never attaches the bearer token for a fully-qualified (third-party) '
        'url, even when one is stored', () async {
      when(
        () => tokenStorage.readAccessToken(),
      ).thenAnswer((_) async => 'token-123');
      when(
        () => dio.getUri<List<int>>(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => bytesResponse([1, 2, 3]));

      await client.fetchBytes('https://picsum.photos/seed/1/800');

      final captured = verify(
        () => dio.getUri<List<int>>(
          captureAny(),
          options: captureAny(named: 'options'),
        ),
      ).captured;
      final uri = captured[0] as Uri;
      final options = captured[1] as Options;
      expect(uri, Uri.parse('https://picsum.photos/seed/1/800'));
      expect(options.headers, isNull);
      verifyNever(() => tokenStorage.readAccessToken());
    });

    test("resolves a relative url against Env.apiBaseUrl's origin, "
        'replacing any existing path (not concatenating)', () async {
      when(() => tokenStorage.readAccessToken()).thenAnswer((_) async => null);
      when(
        () => dio.getUri<List<int>>(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => bytesResponse([1]));

      await client.fetchBytes('/v1/assets/xyz');

      final uri =
          verify(
                () => dio.getUri<List<int>>(
                  captureAny(),
                  options: captureAny(named: 'options'),
                ),
              ).captured.first
              as Uri;
      // Env.apiBaseUrl defaults to https://api.kelalstudio.app in tests
      // (no --dart-define override) — the resolved URI's origin must
      // match that, with the relative path substituted in wholesale.
      expect(uri.scheme, 'https');
      expect(uri.path, '/v1/assets/xyz');
    });

    test('a null response body throws rather than returning silently', () {
      when(() => tokenStorage.readAccessToken()).thenAnswer((_) async => null);
      when(
        () => dio.getUri<List<int>>(any(), options: any(named: 'options')),
      ).thenAnswer(
        (_) async => Response<List<int>>(requestOptions: RequestOptions()),
      );

      expect(client.fetchBytes('/v1/assets/empty'), throwsStateError);
    });
  });
}
