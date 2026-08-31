import 'package:freezed_annotation/freezed_annotation.dart';

part 'quota_dto.freezed.dart';
part 'quota_dto.g.dart';

/// Wire model matching `Quota` in mobile/api_contract/openapi.yaml. DTOs
/// stay in `data/` — domain code never sees this class, only `Quota` (see
/// ../../domain/entities/quota.dart).
@freezed
abstract class QuotaDto with _$QuotaDto {
  const factory QuotaDto({
    @JsonKey(name: 'text_calls_used') required int textCallsUsed,
    @JsonKey(name: 'text_calls_limit') required int textCallsLimit,
    @JsonKey(name: 'image_calls_used') required int imageCallsUsed,
    @JsonKey(name: 'image_calls_limit') required int imageCallsLimit,
    @JsonKey(name: 'resets_at') required DateTime resetsAt,
  }) = _QuotaDto;

  factory QuotaDto.fromJson(Map<String, dynamic> json) =>
      _$QuotaDtoFromJson(json);
}
