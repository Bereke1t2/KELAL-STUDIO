import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/features/generation/data/models/generate_image_response_dto.dart';

void main() {
  group('GenerateImageResponseDto.fromJson', () {
    test('maps every snake_case wire field to its camelCase Dart field', () {
      final dto = GenerateImageResponseDto.fromJson(const {
        'asset_id': 'asset-1',
        'image_url': 'https://picsum.photos/seed/1/1080/1080',
        'width': 1080,
        'height': 1080,
      });

      expect(dto.assetId, 'asset-1');
      expect(dto.imageUrl, 'https://picsum.photos/seed/1/1080/1080');
      expect(dto.width, 1080);
      expect(dto.height, 1080);
    });
  });

  test('round-trips through toJson using the same snake_case keys', () {
    const dto = GenerateImageResponseDto(
      assetId: 'asset-1',
      imageUrl: 'https://picsum.photos/seed/1/1080/1080',
      width: 1080,
      height: 1350,
    );

    final json = dto.toJson();

    expect(json['asset_id'], 'asset-1');
    expect(json['image_url'], 'https://picsum.photos/seed/1/1080/1080');
    expect(json['width'], 1080);
    expect(json['height'], 1350);
  });
}
