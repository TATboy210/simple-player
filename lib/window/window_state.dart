import 'package:flutter/foundation.dart';

class WindowState {
  final ValueNotifier<bool> fullscreen = ValueNotifier(false);
  final ValueNotifier<bool> maximized = ValueNotifier(false);
  final ValueNotifier<bool> alwaysOnTop = ValueNotifier(false);
  final ValueNotifier<bool> focused = ValueNotifier(true);

  void dispose() {
    fullscreen.dispose();
    maximized.dispose();
    alwaysOnTop.dispose();
    focused.dispose();
  }
}
