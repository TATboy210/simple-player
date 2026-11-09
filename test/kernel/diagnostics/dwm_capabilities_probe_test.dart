import 'dart:ffi';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/dwm_capabilities_probe.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';

import '../../helpers/fake_kernel_logger.dart';

/// DwmCapabilitiesProbe FFI 叶子单测 — 261009-fio H1。
///
/// 全程注入 fake 绑定束（fakes-over-mocks 惯例），绝不触达真实 @Native
/// 解析（`DwmProbeBindings.defaults()` 在这些测试中从不调用，三个
/// external 绑定保持惰性未解析）——无 DLL 依赖、无平台 gate，全 CI 平台
/// 安全（ubuntu job 含）。
void main() {
  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  group('DwmCapabilitiesProbe — @Native assetId 解析失败降级 (261009-fio H1)', () {
    late RecordingLogSink sink;
    late List<String> invocations;

    /// 手写 fake 绑定束 — 在三个调用点边界注入，按需抛 ArgumentError
    /// 模拟 @Native external 绑定首调解析失败（DLL/符号缺失的环境性失败）。
    DwmProbeBindings fakeBindings({
      Object? buildNumberError,
      Object? shellWindowError,
      Object? Function(int attributeId)? attributeError,
      int Function(int attributeId)? attributeResults,
      int buildNumber = 26200,
    }) {
      invocations = <String>[];
      return DwmProbeBindings(
        readBuildNumber: () {
          invocations.add('readBuildNumber');
          final error = buildNumberError;
          if (error != null) throw error;
          return buildNumber;
        },
        getShellWindow: () {
          invocations.add('getShellWindow');
          final error = shellWindowError;
          if (error != null) throw error;
          return Pointer<Void>.fromAddress(0x1000);
        },
        dwmGetWindowAttribute: (hwnd, attributeId, pvAttribute, cbAttribute) {
          invocations.add('dwmGetWindowAttribute:$attributeId');
          final error = attributeError?.call(attributeId);
          if (error != null) throw error;
          return attributeResults?.call(attributeId) ?? 0;
        },
      );
    }

    DwmCapabilitiesProbe probeWith(DwmProbeBindings bindings) {
      sink = RecordingLogSink();
      return DwmCapabilitiesProbe(
        logger: KernelLoggerImpl(sink),
        bindings: bindings,
      );
    }

    test('readBuildNumber 抛 ArgumentError — 降级 null 不抛且记 error 日志', () {
      final probe = probeWith(
        fakeBindings(
          buildNumberError: ArgumentError('ntdll binding unavailable'),
        ),
      );

      expect(probe.probe(), isNull);
      expect(invocations, ['readBuildNumber'], reason: '绑定解析失败即止, 不得继续后续探测步骤');
      final errorRecords = sink.records
          .where((r) => r.$1 == LogLevel.error)
          .toList();
      expect(errorRecords, hasLength(1), reason: 'Error 族降级不得静默');
      expect(errorRecords.single.$2, contains('binding'));
    });

    test('getShellWindow 抛 ArgumentError — 降级 null 不抛且记 error 日志', () {
      final probe = probeWith(
        fakeBindings(
          shellWindowError: ArgumentError('user32 binding unavailable'),
        ),
      );

      expect(probe.probe(), isNull);
      expect(invocations, ['readBuildNumber', 'getShellWindow']);
      expect(sink.records.where((r) => r.$1 == LogLevel.error), hasLength(1));
    });

    test('dwmGetWindowAttribute 抛 ArgumentError — 降级 null 不抛且记 error 日志', () {
      final probe = probeWith(
        fakeBindings(
          attributeError: (_) => ArgumentError('dwmapi binding unavailable'),
        ),
      );

      expect(probe.probe(), isNull);
      // fake 先记录后抛错 — 最后一次调用即首个 DWM 属性探测 (corner=33)。
      expect(invocations.last, 'dwmGetWindowAttribute:33');
      expect(sink.records.where((r) => r.$1 == LogLevel.error), hasLength(1));
    });

    test('happy path — Win11 build — 完整快照全 true, 只 Get 探测可读的属性 33', () {
      final probe = probeWith(fakeBindings());

      final snapshot = probe.probe();

      expect(snapshot, isNotNull);
      expect(snapshot!.buildNumber, 26200);
      expect(snapshot.isWin11OrLater, isTrue);
      expect(snapshot.supportsCornerPreference, isTrue);
      expect(snapshot.supportsBorderColor, isTrue);
      expect(snapshot.supportsCaptionColor, isTrue);
      expect(snapshot.supportsTextColor, isTrue);
      // 34/35/36 是只写属性, Get 恒返回 E_INVALIDARG — 不得再被探测.
      expect(
        invocations
            .where((s) => s.startsWith('dwmGetWindowAttribute'))
            .toList(),
        <String>['dwmGetWindowAttribute:33'],
      );
      expect(
        sink.records.where((r) => r.$1 == LogLevel.warn),
        isEmpty,
        reason: 'Win11 上探测不得再产生"属性不可用"警告噪声',
      );
    });

    test('圆角属性 33 非 S_OK — 仅该属性 false, 颜色属性按版本推导仍为 true', () {
      final probe = probeWith(
        fakeBindings(
          attributeResults: (attributeId) => attributeId == 33 ? 0x80004005 : 0,
        ),
      );

      final snapshot = probe.probe();

      expect(snapshot, isNotNull);
      expect(
        snapshot!.supportsCornerPreference,
        isFalse,
        reason: '属性 33 hr 非 S_OK → 探测答案 false (processHResult 语义不变)',
      );
      expect(snapshot.supportsBorderColor, isTrue);
      expect(snapshot.supportsCaptionColor, isTrue);
      expect(snapshot.supportsTextColor, isTrue);
      expect(sink.records.where((r) => r.$1 == LogLevel.warn), hasLength(1));
    });

    test('Win10 build (<22000) — 颜色属性按版本推导为 false', () {
      final probe = probeWith(fakeBindings(buildNumber: 19045));

      final snapshot = probe.probe();

      expect(snapshot, isNotNull);
      expect(snapshot!.isWin11OrLater, isFalse);
      expect(snapshot.supportsBorderColor, isFalse);
      expect(snapshot.supportsCaptionColor, isFalse);
      expect(snapshot.supportsTextColor, isFalse);
    });
  });
}
