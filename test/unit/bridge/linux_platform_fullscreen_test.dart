/// Linux 平台全屏单元测试 — 测试 MethodChannel 窗口句柄缓存逻辑。
///
/// 测试覆盖:
/// - requiresStyleSave = false
/// - resetCache() 清除缓存（不抛异常）
///
/// 注意: GTK3 FFI 函数 (gtk_window_fullscreen/unfullscreen) 是 static final，
/// 无法在单元测试中 mock。enter/exit 的 FFI 调用需要真实 GTK 环境（Linux CI）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/bridge/linux/linux_platform_fullscreen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LinuxPlatformFullscreen.resetCache();
  });

  tearDown(() {
    LinuxPlatformFullscreen.resetCache();
  });

  group('LinuxPlatformFullscreen', () {
    test('requiresStyleSave is false', () {
      expect(LinuxPlatformFullscreen().requiresStyleSave, isFalse);
    });

    test('resetCache clears cached window handle', () {
      // resetCache 不抛异常即通过
      expect(LinuxPlatformFullscreen.resetCache, returnsNormally);
    });

    test('multiple resetCache calls are safe', () {
      LinuxPlatformFullscreen.resetCache();
      LinuxPlatformFullscreen.resetCache();
      LinuxPlatformFullscreen.resetCache();
      // 幂等性：多次调用不应抛异常
    });
  });
}
