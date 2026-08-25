import 'package:kelal_studio/core/network/fake_backend_support.dart'
    show ApiException;

import 'package:kelal_studio/features/generation/data/datasources/fake_generation_remote_data_source.dart'
    show FakeGenerationRemoteDataSource;

import 'package:kelal_studio/features/generation/data/datasources/generation_api.dart'
    show GenerationApi;

import 'package:kelal_studio/features/generation/data/models/generate_text_response_dto.dart';

/// Implemented by both the [GenerationApi]-backed real data source and
/// [FakeGenerationRemoteDataSource]. The repository depends only on this
/// interface — see mobile/.claude/skills/flutter-networking-data/SKILL.md
/// for the mock/real swap mechanism (`generation_datasource_module.dart`).
///
/// Takes plain wire-ready strings (`inputLang`/`platform`), not the
/// domain `InputLanguage`/`ContentPlatform` enums — mirrors
/// `RealAuthRemoteDataSource`'s plain-named-params shape rather than
/// `BrandKitRemoteDataSource`'s DTO-in/DTO-out shape, since there's no
/// `GenerateTextRequest` DTO (the real client builds a `Map` body by hand,
/// same as `RealAuthRemoteDataSource`/`RealBrandKitRemoteDataSource`'s
/// `updateBrandKit` — see `RealGenerationRemoteDataSource`). The
/// domain-to-wire-string mapping (`.wireValue`) happens once, in
/// `GenerationRepositoryImpl`.
///
/// Throws [ApiException] (never a raw `DioException`) on failure —
/// mapping happens once, at the edge, via
/// `core/network/api_exception_mapper.dart`.
abstract class GenerationRemoteDataSource {
  Future<GenerateTextResponseDto> generateText({
    required String inputText,
    required String inputLang,
    required String platform,
    String? brandKitId,
  });
}
