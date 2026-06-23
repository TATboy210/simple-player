/// PlatformFullscreen 接口契约测试 — 验证接口定义和 FullscreenSnapshot 不可变性。
///
/// 测试覆盖:
/// - FullscreenSnapshot 值对象语义
/// - PlatformFullscreen 接口方法签名（编译期 + 运行期）
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/bridge/platform_fullscreen.dart';

void main() {
  group('FullscreenSnapshot', () {
    test('stores windowStyle, position, size', () {
      const snapshot = FullscreenSnapshot(
        windowStyle: 0x00CF0000,
        position: Offset(100, 200),
        size: Size(1920, 1080),
      );

      expect(snapshot.windowStyle, 0x00CF0000);
      expect(snapshot.position, const Offset(100, 200));
      expect(snapshot.size, const Size(1920, 1080));
    });

    test('const constructor works', () {
      // 编译期常量 — 不可变保证
      const a = FullscreenSnapshot(
        windowStyle: 0,
        position: Offset.zero,
        size: Size.zero,
      );
      const b = FullscreenSnapshot(
        windowStyle: 0,
        position: Offset.zero,
        size: Size.zero,
      );
      expect(a.windowStyle, b.windowStyle);
      expect(a.position, b.position);
      expect(a.size, b.size);
    });

    test('zero values are valid', () {
      const snapshot = FullscreenSnapshot(
        windowStyle: 0,
        position: Offset.zero,
        size: Size.zero,
      );
      expect(snapshot.windowStyle, 0);
      expect(snapshot.position, Offset.zero);
      expect(snapshot.size, Size.zero);
    });
  });

  group('PlatformFullscreen interface', () {
    test('requiresStyleSave is a boolean getter', () {
      final platform = _StubPlatformFullscreen();
      expect(platform.requiresStyleSave, isA<bool>());
    });

    test('enter returns Future<FullscreenSnapshot>', () async {
      final platform = _StubPlatformFullscreen();
      final result = await platform.enter();
      expect(result, isA<FullscreenSnapshot>());
    });

    test('exit accepts FullscreenSnapshot without throwing', () {
      final platform = _StubPlatformFullscreen();
      const snapshot = FullscreenSnapshot(
        windowStyle: 0,
        position: Offset.zero,
        size: Size.zero,
      );
      expect(() => platform.exit(snapshot), returnsNormally);
    });
  });
}

/// 最小化 stub — 仅验证接口契约。
class _StubPlatformFullscreen implements PlatformFullscreen {
  @override
  bool get requiresStyleSave => false;

  @override
  Future<FullscreenSnapshot> enter() async {
    return const FullscreenSnapshot(
      windowStyle: 0,
      position: Offset.zero,
      size: Size.zero,
    );
  }

  @override
  void exit(FullscreenSnapshot snapshot) {}
}
