import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/window_manager_service/window_manager_service.dart';

void main() {
  group('WindowMode', () {
    test('convenience getters return correct values', () {
      expect(WindowMode.windowed.isWindowed, isTrue);
      expect(WindowMode.windowed.isFullscreen, isFalse);
      expect(WindowMode.windowed.isMaximized, isFalse);
      expect(WindowMode.fullscreen.isFullscreen, isTrue);
      expect(WindowMode.maximized.isMaximized, isTrue);
    });
  });
}
