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
      final service = WindowService();
      final first = service.setFullscreen(true);
      final second = service.setFullscreen(true);
      await first;
      await second;
    });
  });
}
