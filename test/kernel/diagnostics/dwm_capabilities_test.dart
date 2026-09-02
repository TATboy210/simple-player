import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/dwm_capabilities.dart';
import 'package:simple_player_flutter/kernel/diagnostics/dwm_capabilities_probe.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_reporter.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/window_bridge/window_service_state.dart';

import '../../helpers/fake_kernel_logger.dart';

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

  group('D-04 failure reporting', () {
    late RecordingLogSink sink;
    late DwmCapabilitiesProbe probe;

    setUp(() async {
      await ErrorReporterImpl.resetForTesting();
      ErrorReporterImpl.init();
      sink = RecordingLogSink();
      probe = DwmCapabilitiesProbe(logger: KernelLoggerImpl(sink));
    });

    tearDown(() async {
      await ErrorReporterImpl.resetForTesting();
    });

    test('非 S_OK HRESULT 逐次记录错误日志，含 attribute/build 上下文（每次必记）', () {
      // Act — 两个不同属性在同一窗口内失败
      probe.processHResult(0x80070057, 34, 22000);
      probe.processHResult(0x80070057, 33, 22000);

      // Assert — D-04「每次失败必记」：不抑制、不聚合日志
      final errors = sink.records.where((r) => r.$1 == LogLevel.error).toList();
      expect(errors.length, 2, reason: 'D-04: 每次失败必记');
      expect(errors.first.$2, contains('[DwmCapabilities]'));
      expect(errors.first.$3?['attribute'], 34);
      expect(errors.first.$3?['build'], 22000);
    });

    test('同类失败首次聚合为一条 ErrorReport（10s 窗去重，卡片不刷屏）', () {
      // Act — 两个不同属性失败，通用消息 + 同源栈 → 语义身份相同
      probe.processHResult(0x80070057, 34, 22000);
      probe.processHResult(0x80070057, 33, 22000);

      // Assert — 仅首条入队，第二条合并进 occurrenceCount
      expect(ErrorReporterImpl.I.queuedReports.length, 1);
    });

    test('S_OK 不产生错误日志与报告', () {
      // Act
      final available = probe.processHResult(0, 34, 22000);

      // Assert
      expect(available, isTrue);
      expect(sink.records.where((r) => r.$1 == LogLevel.error), isEmpty);
      expect(ErrorReporterImpl.I.queuedReports, isEmpty);
    });
  });
}
