import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/utils/time_utils.dart';

void main() {
  group('formatMs', () {
    test('returns 00:00 for zero', () {
      expect(formatMs(0), '00:00');
    });

    test('returns 00:00 for negative', () {
      expect(formatMs(-100), '00:00');
    });

    test('formats seconds only', () {
      expect(formatMs(5000), '00:05');
    });

    test('formats minutes and seconds', () {
      expect(formatMs(90000), '01:30');
    });

    test('formats hours, minutes, and seconds', () {
      expect(formatMs(3661000), '1:01:01');
    });
  });
}
