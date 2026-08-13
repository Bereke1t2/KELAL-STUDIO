import 'package:envied/envied.dart';

part 'env.g.dart';

/// Build-time configuration, injected via `--dart-define-from-file` and
/// obfuscated by `envied` — never bundle a `.env` file as an asset (it's
/// trivially extracted from a release APK/IPA by unzipping). See
/// mobile/.claude/skills/flutter-security/SKILL.md.
///
/// Per the PRD, no AI-provider API key is ever meant to reach the client —
/// there should never be a provider key defined here. This class exists for
/// build-flavor toggles and the eventual real API base URL only.
@Envied(useConstantCase: true, obfuscate: true)
abstract class Env {
  /// When true (the default until a real backend exists), each feature's
  /// `*DataSourceModule` wires its `Fake*RemoteDataSource` instead of the
  /// real dio/retrofit client. See mobile/api_contract/ and
  /// mobile/.claude/skills/flutter-networking-data/SKILL.md.
  @EnviedField(varName: 'USE_MOCK_API', defaultValue: true)
  static final bool useMockApi = _Env.useMockApi;

  @EnviedField(
    varName: 'API_BASE_URL',
    defaultValue: 'https://api.kelalstudio.app',
  )
  static final String apiBaseUrl = _Env.apiBaseUrl;
}
