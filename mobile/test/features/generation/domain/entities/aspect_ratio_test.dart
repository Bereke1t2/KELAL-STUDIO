import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/features/generation/domain/entities/aspect_ratio.dart';

void main() {
  group('GenerationAspectRatio.wireValue', () {
    test('maps to the exact GenerateImageRequest.aspect_ratio enum values', () {
      expect(GenerationAspectRatio.oneToOne.wireValue, '1:1');
      expect(GenerationAspectRatio.fourToFive.wireValue, '4:5');
    });
  });

  group('GenerationAspectRatio.canvasSize', () {
    test('oneToOne is a square', () {
      final size = GenerationAspectRatio.oneToOne.canvasSize;
      expect(size.width, size.height);
    });

    test('fourToFive is taller than it is wide, in a 4:5 ratio', () {
      final size = GenerationAspectRatio.fourToFive.canvasSize;
      expect(size.height, greaterThan(size.width));
      expect(size.width / size.height, closeTo(4 / 5, 0.01));
    });
  });

  test('has no nineBySixteen member — OQ-02 is not silently resolved', () {
    expect(
      GenerationAspectRatio.values,
      containsAllInOrder([
        GenerationAspectRatio.oneToOne,
        GenerationAspectRatio.fourToFive,
      ]),
    );
    expect(GenerationAspectRatio.values.length, 2);
  });
}
