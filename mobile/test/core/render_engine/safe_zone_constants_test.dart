import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/render_engine/safe_zone_constants.dart';

void main() {
  group('clampNormalizedOffsetY', () {
    test('leaves a dy already inside the safe area untouched', () {
      final result = SafeZoneConstants.clampNormalizedOffsetY(
        dy: 0.5,
        layerHeightFraction: 0.05,
      );

      expect(result, 0.5);
    });

    test('clamps a dy inside the top obstruction band up to the safe edge', () {
      final result = SafeZoneConstants.clampNormalizedOffsetY(
        dy: 0.02,
        layerHeightFraction: 0.05,
      );

      expect(result, SafeZoneConstants.topObstructionFraction);
    });

    test('clamps a dy that would push the layer into the bottom obstruction '
        'band, accounting for layerHeightFraction', () {
      final result = SafeZoneConstants.clampNormalizedOffsetY(
        dy: 0.9,
        layerHeightFraction: 0.1,
      );

      // maxY = 1.0 - bottomObstructionFraction - layerHeightFraction
      expect(
        result,
        closeTo(1.0 - SafeZoneConstants.bottomObstructionFraction - 0.1, 1e-9),
      );
    });

    test('pins to the top of the safe area rather than an inverted range when '
        'the layer is taller than the whole safe area', () {
      final result = SafeZoneConstants.clampNormalizedOffsetY(
        dy: 0.5,
        layerHeightFraction: 0.9,
      );

      expect(result, SafeZoneConstants.topObstructionFraction);
    });

    test('the two obstruction fractions are the PRD §6.5 flat placeholder '
        'figures (OQ-06), not arbitrary values', () {
      expect(SafeZoneConstants.topObstructionFraction, 0.10);
      expect(SafeZoneConstants.bottomObstructionFraction, 0.15);
    });
  });
}
