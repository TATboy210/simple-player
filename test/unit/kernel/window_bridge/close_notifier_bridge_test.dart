import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/window_bridge/platform/close_notifier_bridge.dart';

// install() 的占位回调闭包（`() {}`）语义即“注册了但无操作”——
// DCM 的 no-empty-block 会逐个误报，文件级豁免。
// ignore_for_file: no-empty-block

/// 关门专线注册桥（CONTRACT.md 契约 7 的宿主触发半边）的可测行为。
///
/// 测试宿主（flutter_tester）不导出 `SetCloseNotifier` — 走「符号缺失 →
/// 降级返回 false」路径；三平台 runner 的成功路径在真机集成测试锁定
/// （backend_soak / close flow），此处锁降级契约：
/// 安装失败不得抛、不得置 installed 槽、调用方退回旧关闭路径。
void main() {
  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  setUp(() {
    // 隔离用例间的保活槽残留（覆盖注册语义的观察位）。
    CloseNotifierBridge.installed = null;
  });

  group('CloseNotifierBridge.install（宿主未导出符号的环境）', () {
    test('符号缺失 → 返回 false 且不抛（调用方退回旧关闭路径）', () {
      var handlerRan = false;
      final installed = CloseNotifierBridge.install(() => handlerRan = true);
      expect(installed, isFalse, reason: 'flutter_tester 无 SetCloseNotifier 导出');
      expect(handlerRan, isFalse);
    });

    test('降级路径不留下保活槽 — installed 恒为 null', () {
      CloseNotifierBridge.install(() {});
      expect(CloseNotifierBridge.installed, isNull);
    });

    test('重复安装仍幂等降级 — 不抛、不累积槽位', () {
      expect(CloseNotifierBridge.install(() {}), isFalse);
      expect(CloseNotifierBridge.install(() {}), isFalse);
      expect(CloseNotifierBridge.installed, isNull);
    });

    test('回退查找顺序：process() 失败后尝试 executable() — 两者皆无即降级',
        () {
      // 行为断言同上（降级）；此用例锁定查找顺序不产生中间副作用：
      // executable() 作用域（静态链入 dart_tester 的符号表）同样无该符号。
      final installed = CloseNotifierBridge.install(() {});
      expect(installed, isFalse);
    });
  });
}
