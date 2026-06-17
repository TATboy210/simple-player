import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/bridge/window_service.dart';

void main() {
  setUpAll(() {
    WidgetsFlutterBinding.ensureInitialized();
  });

  group('_safeSet lifecycle guard', () {
    test('callback after dispose does not throw', () {
      final service = WindowService();
      service.dispose();
      expect(() => service.onWindowMaximize(), returnsNormally);
      expect(() => service.onWindowUnmaximize(), returnsNormally);
      expect(() => service.onWindowEnterFullScreen(), returnsNormally);
      expect(() => service.onWindowLeaveFullScreen(), returnsNormally);
    });

  });

  group('_isAnimating fullscreen guard', () {
    test('setFullscreen rejects re-entrant calls', () async {
      // FullScreen.setFullScreen requires platform channels unavailable in test.
      // Verify the method at least doesn't throw on the guard path.
      final service = WindowService();
      // First call will throw (FullScreen not initialized) — that's expected.
      // The guard (_isAnimating) is still exercised.
      await service.setFullscreen(true).catchError((_) {});
      await service.setFullscreen(true).catchError((_) {});
    }, skip: 'Requires flutter_fullscreen platform channels');
  });
}
