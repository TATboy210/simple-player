import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/dwm_capabilities.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/window_bridge/window_service_state.dart';

void main() {
  setUpAll(() {
    // Kernel 惯例：诊断单例先于任何 kernel 访问初始化（CLAUDE.md test setup）。
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  group('DwmCapabilitySnapshot', () {
    test('const 构造产出不可变快照，字段齐备', () {
      // Arrange + Act
      const snapshot = DwmCapabilitySnapshot(
        buildNumber: 22000,
        supportsBorderColor: true,
        supportsCornerPreference: true,
        supportsCaptionColor: true,
        supportsTextColor: true,
      );

      // Assert — 全字段 final（immutability 由编译器保证），值正确
      expect(snapshot.buildNumber, 22000);
      expect(snapshot.supportsBorderColor, isTrue);
      expect(snapshot.supportsCornerPreference, isTrue);
      expect(snapshot.supportsCaptionColor, isTrue);
      expect(snapshot.supportsTextColor, isTrue);
    });

    test('kWin11BuildFloor 常量为 22000（阈值唯一来源）', () {
      expect(kWin11BuildFloor, 22000);
    });

    test('isWin11OrLater 边界：21999=false / 22000=true（一步两侧）', () {
      // Arrange — ENAB-01 boundary：build 21999 = Win10，22000 = Win11
      const win10 = DwmCapabilitySnapshot(
        buildNumber: 21999,
        supportsBorderColor: false,
        supportsCornerPreference: false,
        supportsCaptionColor: false,
        supportsTextColor: false,
      );
      const win11 = DwmCapabilitySnapshot(
        buildNumber: 22000,
        supportsBorderColor: true,
        supportsCornerPreference: true,
        supportsCaptionColor: true,
        supportsTextColor: true,
      );

      // Assert — 整数精确 >= 比较，无浮点
      expect(win10.isWin11OrLater, isFalse);
      expect(win11.isWin11OrLater, isTrue);
    });
  });

  group('DwmCapabilities facade', () {
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test('snapshot notifier 初始为 null（未探测）', () {
      // Arrange + Assert
      expect(DwmCapabilities.I.snapshot.value, isNull);
    });

    test('LinuxCompositorCapabilities 占位 probe 返回 null（Phase 11 槽位）', () {
      // Arrange
      const placeholder = LinuxCompositorCapabilities();

      // Act + Assert — D-01 对等形态：Linux 分支编译通过且返回 null
      expect(placeholder.probe(), isNull);
    });

    test('非 Windows 默认测试平台下 probe() 走占位分支，snapshot 保持 null', () {
      // Arrange — 测试默认平台非 Windows → 命中 placeholder/default 分支，
      // 不触发 FFI（真实 Windows FFI 路径由 06-UAT.md 实机清单覆盖）。
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      // Act
      DwmCapabilities.I.probe();

      // Assert
      expect(DwmCapabilities.I.snapshot.value, isNull);
    });
  });

  group('WindowServiceState integration', () {
    test('dwmCapabilities notifier 暴露且初始为 null', () {
      // Arrange
      final state = WindowServiceState();

      // Act + Assert
      expect(state.dwmCapabilities.value, isNull);
      state.dispose();
    });

    test('dispose 幂等且不抛出（快照通知器生命周期由门面持有）', () {
      // Arrange
      final state = WindowServiceState();
      state.dispose();

      // Act + Assert — 重复 dispose 安全（既有容器契约）
      expect(state.dispose, returnsNormally);
    });
  });
}
