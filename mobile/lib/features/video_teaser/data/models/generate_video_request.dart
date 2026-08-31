import 'package:freezed_annotation/freezed_annotation.dart';

part 'generate_video_request.freezed.dart';
part 'generate_video_request.g.dart';

@freezed
abstract class GenerateVideoRequest with _$GenerateVideoRequest {
  const factory GenerateVideoRequest({
    @JsonKey(name: 'storyboard_text') required String storyboardText,
    @JsonKey(name: 'brand_kit_id') required String brandKitId,
  }) = _GenerateVideoRequest;

  factory GenerateVideoRequest.fromJson(Map<String, dynamic> json) =>
      _$GenerateVideoRequestFromJson(json);
}
