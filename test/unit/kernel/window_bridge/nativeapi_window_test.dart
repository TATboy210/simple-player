import 'package:flutter_test/flutter_test.dart';
import 'package:nativeapi/nativeapi.dart' as na;
import 'package:simple_player_flutter/kernel/window_bridge/native_window.dart';
import 'package:simple_player_flutter/kernel/window_bridge/nativeapi_window.dart';

void main() {
  group('mapWindowEvent', () {
    test('maps the events the service reacts to', () {
      expect(
        mapWindowEvent(const na.WindowMaximizedEvent(windowId: 1)),
        isA<NativeMaximized>(),
      );
      expect(
        mapWindowEvent(const na.WindowRestoredEvent(windowId: 1)),
        isA<NativeRestored>(),
      );
      expect(
        mapWindowEvent(const na.WindowMinimizedEvent(windowId: 1)),
        isA<NativeMinimized>(),
      );
      expect(
        mapWindowEvent(
          const na.WindowResizedEvent(
            windowId: 1,
            newSize: na.Size(width: 800, height: 600),
          ),
        ),
        isA<NativeResized>(),
      );
      expect(
        mapWindowEvent(
          const na.WindowMovedEvent(
            windowId: 1,
            newPosition: na.Point(x: 10, y: 20),
          ),
        ),
        isA<NativeMoved>(),
      );
    });

    test('drops events without application semantics', () {
      expect(mapWindowEvent(const na.WindowFocusedEvent(windowId: 1)), isNull);
      expect(mapWindowEvent(const na.WindowBlurredEvent(windowId: 1)), isNull);
    });
  });
}
