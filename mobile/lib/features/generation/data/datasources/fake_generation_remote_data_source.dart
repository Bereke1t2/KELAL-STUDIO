import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/network/fake_backend_support.dart';
import 'package:kelal_studio/features/generation/data/datasources/generation_remote_data_source.dart';
import 'package:kelal_studio/features/generation/data/models/generate_text_response_dto.dart';

/// Professional fake: realistic latency (via [FakeBackendSupport.latency])
/// plus deliberate, low-probability failure injection across the
/// `/generate/*` typed error taxonomy (PRD §11) — see
/// mobile/.claude/skills/flutter-networking-data/SKILL.md. This is the
/// first `Fake*RemoteDataSource` in this codebase to actually call
/// [FakeBackendSupport.maybeFail]/[FakeBackendSupport.chance]:
/// `FakeQuotaRemoteDataSource`/`FakeBrandKitRemoteDataSource` always
/// succeed, because there was nothing product-critical riding on their
/// error paths actually being reachable without a mocked repository. Here
/// there is — `ComposerPage`/`GenerationBloc` must handle every
/// `ApiErrorType` `/generate/text` can produce (PRD-mandated, not
/// optional), so whoever drives the app manually should be able to
/// stumble into each one without needing to attach a debugger.
///
/// **Rates are a judgment call, not a product number** (nothing in the
/// PRD specifies how often a real provider fails) — individually low
/// (3-5%) so a manual run mostly succeeds, but not so low that a short
/// testing session is unlikely to ever see one. `ApiErrorType.unauthorized`
/// is deliberately *not* injected here: a 401 is a token/session concern
/// `AuthInterceptor` already owns end-to-end, and manufacturing one from
/// inside an otherwise-valid generation call would just be confusing to
/// exercise manually, not a realistic simulation of anything this
/// endpoint itself would produce.
class FakeGenerationRemoteDataSource implements GenerationRemoteDataSource {
  @override
  Future<GenerateTextResponseDto> generateText({
    required String inputText,
    required String inputLang,
    required String platform,
    String? brandKitId,
  }) async {
    await FakeBackendSupport.latency();

    FakeBackendSupport.maybeFail(
      ApiFailure(
        type: ApiErrorType.quotaExceeded,
        message: "You've used today's generation quota. It resets soon.",
        resetsAt: DateTime.now().toUtc().add(const Duration(hours: 6)),
      ),
      rate: 0.05,
    );
    FakeBackendSupport.maybeFail(
      const ApiFailure(
        type: ApiErrorType.moderationRefused,
        message:
            "This idea can't be generated as written. Please adjust it "
            'and try again.',
        moderationReason:
            "This idea can't be generated as written. Please adjust it "
            'and try again.',
      ),
      rate: 0.04,
    );
    FakeBackendSupport.maybeFail(
      const ApiFailure(
        type: ApiErrorType.malformedOutput,
        message: "We couldn't generate that. Please try again.",
      ),
      rate: 0.03,
    );
    FakeBackendSupport.maybeFail(
      const ApiFailure(
        type: ApiErrorType.validationError,
        message: 'Please check your input and try again.',
      ),
      rate: 0.03,
    );
    FakeBackendSupport.maybeFail(
      const ApiFailure(
        type: ApiErrorType.network,
        message: 'No connection. Check your network and try again.',
      ),
      rate: 0.03,
    );

    // PRD §6.2: "Fallback path: on LLM timeout/failure, return a
    // pre-cached template response rather than a raw error." Simulated as
    // two nested probabilities: first, whether a provider hiccup happens
    // at all; then, whether it's the common case a real backend's own
    // fallback would quietly absorb (return fallback content, `isFallback:
    // true`) or the rarer case where even the fallback isn't available
    // and the raw `providerTimeout` error must still reach the UI — both
    // paths need to be real and reachable, not just the happy one.
    if (FakeBackendSupport.chance(rate: 0.09)) {
      if (FakeBackendSupport.chance(rate: 0.7)) {
        return _fallbackTemplateResponse();
      }
      throw ApiException(
        const ApiFailure(
          type: ApiErrorType.providerTimeout,
          message: 'Generation is taking longer than usual. Please try again.',
        ),
      );
    }

    return _successResponse(inputText: inputText, platform: platform);
  }

  GenerateTextResponseDto _successResponse({
    required String inputText,
    required String platform,
  }) {
    final topic = inputText.trim().isEmpty
        ? 'your latest update'
        : inputText.trim();

    return GenerateTextResponseDto(
      captionEn:
          'Check out $topic — crafted just for your $platform '
          'audience.',
      // Best-effort, non-native-speaker placeholder translation — pending
      // native-speaker review before shipping, same flagging convention
      // as mobile/CLAUDE.md's Localization section and app_am.arb's
      // file-level note. This is fake/demo data, not app-interface copy,
      // but it renders in the same "Amharic caption" field a real
      // backend response would, so it gets the same disclosure.
      captionAm: '$topic ይመልከቱ — ለእርስዎ ታዳሚ የተዘጋጀ።',
      callToAction: 'Tell us what you think in the comments!',
      hashtags: const [
        '#KelalStudio',
        '#SmallBusiness',
        '#Ethiopia',
        '#ShopLocal',
        '#GrowYourBusiness',
        '#EthiopianBusiness',
      ],
    );
  }

  /// Deliberately generic, platform-agnostic canned content — a real
  /// cached fallback would presumably be smarter (per-platform, per-input
  /// pre-approved copy), but that's backend content-design work outside
  /// this branch's scope. This exists only to prove the client-side
  /// "transparently show fallback content, and flag it as such in the UI"
  /// path (`GenerationResult.isFallback` -> the "saved template" notice
  /// on `GenerationResultView`) actually works end-to-end in mock mode.
  GenerateTextResponseDto _fallbackTemplateResponse() {
    return const GenerateTextResponseDto(
      captionEn:
          "We're having trouble generating something fresh right now — "
          "here's a starting point you can edit.",
      // Same unverified-placeholder-translation flag as _successResponse's
      // captionAm above.
      captionAm:
          'አሁን ትኩስ ይዘት ማመንጨት ላይ ችግር እያጋጠመን ነው — '
          'ሊያርትዑት የሚችሉት መነሻ ነጥብ ይኸውና።',
      callToAction: 'Tell us what you think in the comments!',
      hashtags: [
        '#KelalStudio',
        '#SmallBusiness',
        '#Ethiopia',
        '#ShopLocal',
        '#GrowYourBusiness',
      ],
      isFallback: true,
    );
  }
}
