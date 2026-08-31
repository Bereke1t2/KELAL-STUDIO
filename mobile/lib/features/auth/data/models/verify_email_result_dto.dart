import 'package:freezed_annotation/freezed_annotation.dart';

part 'verify_email_result_dto.freezed.dart';
part 'verify_email_result_dto.g.dart';

/// Wire model matching `POST /auth/verify-email`'s real `200` response
/// shape in `backend/api/openapi.yaml` — `{verified: bool}`.
@freezed
abstract class VerifyEmailResultDto with _$VerifyEmailResultDto {
  const factory VerifyEmailResultDto({required bool verified}) =
      _VerifyEmailResultDto;

  factory VerifyEmailResultDto.fromJson(Map<String, dynamic> json) =>
      _$VerifyEmailResultDtoFromJson(json);
}
