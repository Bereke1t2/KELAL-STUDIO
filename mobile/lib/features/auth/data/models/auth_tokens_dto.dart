import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_tokens_dto.freezed.dart';
part 'auth_tokens_dto.g.dart';

/// Wire model matching `AuthTokens` in mobile/api_contract/openapi.yaml.
/// DTOs stay in `data/` — domain code never sees this class, only
/// `AuthSession` (see ../../domain/entities/auth_session.dart).
@freezed
abstract class AuthTokensDto with _$AuthTokensDto {
  const factory AuthTokensDto({
    @JsonKey(name: 'access_token') required String accessToken,
    @JsonKey(name: 'refresh_token') required String refreshToken,
  }) = _AuthTokensDto;

  factory AuthTokensDto.fromJson(Map<String, dynamic> json) =>
      _$AuthTokensDtoFromJson(json);
}
