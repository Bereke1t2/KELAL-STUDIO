import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/features/generation/data/models/generate_text_response_dto.dart';

void main() {
  group('GenerateTextResponseDto.fromJson', () {
    test('maps every snake_case wire field to its camelCase Dart field', () {
      final dto = GenerateTextResponseDto.fromJson(const {
        'caption_en': 'Check out our new arrivals!',
        'caption_am': 'አዲስ ምርቶቻችንን ይመልከቱ!',
        'call_to_action': 'Shop now',
        'hashtags': ['#new', '#shop', '#sale', '#ethiopia', '#local'],
      });

      expect(dto.captionEn, 'Check out our new arrivals!');
      expect(dto.captionAm, 'አዲስ ምርቶቻችንን ይመልከቱ!');
      expect(dto.callToAction, 'Shop now');
      expect(dto.hashtags, ['#new', '#shop', '#sale', '#ethiopia', '#local']);
    });

    test('isFallback always defaults to false when parsing real JSON — it is '
        'not part of the GenerateTextResponse wire contract, even if a '
        'response body happened to include the key', () {
      final dto = GenerateTextResponseDto.fromJson(const {
        'caption_en': 'a',
        'caption_am': 'b',
        'call_to_action': 'c',
        'hashtags': <String>[],
        // A real backend would never send this key (see the field's
        // own doc comment), but even if something upstream injected it,
        // includeFromJson: false means it must still be ignored.
        'isFallback': true,
      });

      expect(dto.isFallback, isFalse);
    });
  });

  test(
    'isFallback is never written back out to JSON (includeToJson: false)',
    () {
      const dto = GenerateTextResponseDto(
        captionEn: 'a',
        captionAm: 'b',
        callToAction: 'c',
        hashtags: [],
        isFallback: true,
      );

      expect(dto.toJson().containsKey('isFallback'), isFalse);
      expect(dto.toJson().containsKey('is_fallback'), isFalse);
    },
  );
}
