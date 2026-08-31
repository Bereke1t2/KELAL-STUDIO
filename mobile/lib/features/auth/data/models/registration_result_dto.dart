import 'package:freezed_annotation/freezed_annotation.dart';

part 'registration_result_dto.freezed.dart';
part 'registration_result_dto.g.dart';

/// Wire model matching `RegisterResult` in `backend/api/openapi.yaml` —
/// `POST /auth/register`'s real `201` response. Replaces the old
/// assumption (baked into `AuthTokensDto` before a real backend existed)
/// that register returned a session directly — see
/// `RegistrationOutcome`'s own doc comment for the full story.
@freezed
abstract class RegistrationResultDto with _$RegistrationResultDto {
  const factory RegistrationResultDto({
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'verification_sent') required bool verificationSent,
  }) = _RegistrationResultDto;

  factory RegistrationResultDto.fromJson(Map<String, dynamic> json) =>
      _$RegistrationResultDtoFromJson(json);
}
