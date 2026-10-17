import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/bridge/win32/caption_region_bridge.dart';

/// runner 解包同口径 (windows/runner/caption_region.h ReadCaptionRect)。
List<int> _unpack(int packed) => [
  packed & 0xFFFF,
  (packed >> 16) & 0xFFFF,
  (packed >> 32) & 0xFFFF,
  (packed >> 48) & 0xFFFF,
];

void main() {
  group('packCaptionRect', () {
    test('packs LTRB in 16-bit lanes matching the runner layout', () {
      final packed = packCaptionRect(const Rect.fromLTRB(0, 0, 1043, 48));
      expect(_unpack(packed), [0, 0, 1043, 48]);
    });

    test('rounds outward to cover partial pixels', () {
      final packed = packCaptionRect(
        const Rect.fromLTRB(10.4, 0.6, 600.2, 47.5),
      );
      expect(_unpack(packed), [10, 0, 601, 48]);
    });

    test('null, empty and non-finite rects disable the region', () {
      expect(packCaptionRect(null), 0);
      expect(packCaptionRect(Rect.zero), 0);
      expect(packCaptionRect(const Rect.fromLTRB(5, 5, 5, 40)), 0);
      expect(
        packCaptionRect(const Rect.fromLTRB(0, 0, double.infinity, 32)),
        0,
      );
    });

    test('clamps to the 16-bit range', () {
      final packed = packCaptionRect(const Rect.fromLTRB(-20, -3, 70000, 48));
      expect(_unpack(packed), [0, 0, 0xFFFF, 48]);
    });
  });
}
