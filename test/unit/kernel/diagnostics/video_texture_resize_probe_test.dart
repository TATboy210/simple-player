import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/diagnostics/video_texture_resize_probe.dart';

void main() {
  group('VideoTextureResizeProbe', () {
    test('会话结束输出固定 schema、共享 sessionId 与起止快照', () {
      final resizing = ValueNotifier<bool>(false);
      final resizeSessionId = ValueNotifier<int>(41);
      final rect = ValueNotifier<Rect?>(const Rect.fromLTWH(1, 2, 100, 50));
      final textureId = ValueNotifier<int?>(7);
      final logger = _RecordingLogger();
      final clock = _FakeMonotonicClock();
      final probe = VideoTextureResizeProbe(
        isResizing: resizing,
        resizeSessionId: resizeSessionId,
        rect: rect,
        textureId: textureId,
        logger: logger,
        monotonicNow: clock.now,
        enabled: true,
      );

      resizing.value = true;
      clock.advance(const Duration(microseconds: 7000));
      resizing.value = false;

      expect(logger.entries, hasLength(1));
      final entry = logger.entries.single;
      expect(entry.message, 'video_texture_resize_probe');
      expect(entry.context?.keys.toSet(), VideoTextureResizeProbe.contextKeys);
      expect(entry.context?['sessionId'], 41);
      expect(entry.context?['probeUnavailable'], isFalse);
      expect(entry.context?['durationUs'], 7000);
      expect(entry.context?['classification'], 'no-dart-signal-change');
      expect(entry.context?['rectChanges'], 0);
      expect(entry.context?['textureIdChanges'], 0);
      expect(entry.context?['rectAtStart'], _rectMap(1, 2, 101, 52));
      expect(entry.context?['rectAtEnd'], _rectMap(1, 2, 101, 52));
      expect(entry.context?['textureIdAtStart'], 7);
      expect(entry.context?['textureIdAtEnd'], 7);

      probe.dispose();
      resizing.dispose();
      resizeSessionId.dispose();
      rect.dispose();
      textureId.dispose();
    });

    test('缺少 video controller 信号时输出完整的 probeUnavailable 摘要', () {
      final resizing = ValueNotifier<bool>(false);
      final resizeSessionId = ValueNotifier<int>(42);
      final logger = _RecordingLogger();
      final probe = VideoTextureResizeProbe(
        isResizing: resizing,
        resizeSessionId: resizeSessionId,
        logger: logger,
        enabled: true,
      );

      resizing.value = true;
      resizing.value = false;

      expect(logger.entries, hasLength(1));
      final context = logger.entries.single.context;
      expect(context?.keys.toSet(), VideoTextureResizeProbe.contextKeys);
      expect(context?['sessionId'], 42);
      expect(context?['probeUnavailable'], isTrue);
      expect(context?['classification'], isNull);
      expect(context?['rectChanges'], 0);
      expect(context?['textureIdChanges'], 0);
      expect(context?['rectAtStart'], isNull);
      expect(context?['rectAtEnd'], isNull);
      expect(context?['textureIdAtStart'], isNull);
      expect(context?['textureIdAtEnd'], isNull);
      expect(context?['rectTrail'], isEmpty);
      expect(context?['textureIdTrail'], isEmpty);
      expect(context?['rectTrailOmitted'], 0);
      expect(context?['textureIdTrailOmitted'], 0);

      probe.dispose();
      resizing.dispose();
      resizeSessionId.dispose();
    });

    test('仅缺少一个 controller observer 时仍标记 probeUnavailable', () {
      final resizing = ValueNotifier<bool>(false);
      final resizeSessionId = ValueNotifier<int>(43);
      final rect = ValueNotifier<Rect?>(Rect.zero);
      final logger = _RecordingLogger();
      final probe = VideoTextureResizeProbe(
        isResizing: resizing,
        resizeSessionId: resizeSessionId,
        rect: rect,
        logger: logger,
        enabled: true,
      );

      resizing.value = true;
      rect.value = const Rect.fromLTWH(1, 2, 100, 50);
      resizing.value = false;

      final context = logger.entries.single.context;
      expect(context?['sessionId'], 43);
      expect(context?['probeUnavailable'], isTrue);
      expect(context?['classification'], isNull);
      expect(context?['rectChanges'], 0);
      expect(context?['rectAtStart'], isNull);
      expect(context?['rectAtEnd'], isNull);
      expect(context?['rectTrail'], isEmpty);

      probe.dispose();
      resizing.dispose();
      resizeSessionId.dispose();
      rect.dispose();
    });

    test('日志 sink 重入开启下一会话时不清空新会话快照', () {
      final resizing = ValueNotifier<bool>(false);
      final resizeSessionId = ValueNotifier<int>(51);
      final rect = ValueNotifier<Rect?>(Rect.zero);
      final textureId = ValueNotifier<int?>(7);
      final logger = _ReentrantProbeLogger(
        onFirstEntry: () {
          resizeSessionId.value = 52;
          resizing.value = true;
        },
      );
      final probe = VideoTextureResizeProbe(
        isResizing: resizing,
        resizeSessionId: resizeSessionId,
        rect: rect,
        textureId: textureId,
        logger: logger,
        enabled: true,
      );

      resizing.value = true;
      resizing.value = false;
      rect.value = const Rect.fromLTWH(1, 0, 100, 50);
      resizing.value = false;

      expect(logger.entries, hasLength(2));
      expect(logger.entries[0].context?['sessionId'], 51);
      expect(logger.entries[1].context?['sessionId'], 52);
      expect(logger.entries[1].context?['rectAtStart'], _rectMap(0, 0, 0, 0));
      expect(logger.entries[1].context?['rectChanges'], 1);

      probe.dispose();
      resizing.dispose();
      resizeSessionId.dispose();
      rect.dispose();
      textureId.dispose();
    });

    test('会话开始后 sessionId 变化仍输出冻结的 ID', () {
      final resizing = ValueNotifier<bool>(false);
      final resizeSessionId = ValueNotifier<int>(41);
      final rect = ValueNotifier<Rect?>(Rect.zero);
      final textureId = ValueNotifier<int?>(7);
      final logger = _RecordingLogger();
      final probe = VideoTextureResizeProbe(
        isResizing: resizing,
        resizeSessionId: resizeSessionId,
        rect: rect,
        textureId: textureId,
        logger: logger,
        enabled: true,
      );

      resizing.value = true;
      resizeSessionId.value = 42;
      resizing.value = false;

      expect(logger.entries.single.context?['sessionId'], 41);

      probe.dispose();
      resizing.dispose();
      resizeSessionId.dispose();
      rect.dispose();
      textureId.dispose();
    });

    test('连续会话使用各自 sessionId 且变化计数不串线', () {
      final resizing = ValueNotifier<bool>(false);
      final resizeSessionId = ValueNotifier<int>(51);
      final rect = ValueNotifier<Rect?>(Rect.zero);
      final textureId = ValueNotifier<int?>(7);
      final logger = _RecordingLogger();
      final probe = VideoTextureResizeProbe(
        isResizing: resizing,
        resizeSessionId: resizeSessionId,
        rect: rect,
        textureId: textureId,
        logger: logger,
        enabled: true,
      );

      resizing.value = true;
      textureId.value = 8;
      resizing.value = false;
      resizeSessionId.value = 52;
      resizing.value = true;
      rect.value = const Rect.fromLTWH(2, 0, 100, 50);
      resizing.value = false;

      expect(logger.entries, hasLength(2));
      expect(logger.entries[0].context?['sessionId'], 51);
      expect(logger.entries[0].context?['textureIdChanges'], 1);
      expect(logger.entries[0].context?['rectChanges'], 0);
      expect(logger.entries[1].context?['sessionId'], 52);
      expect(logger.entries[1].context?['textureIdChanges'], 0);
      expect(logger.entries[1].context?['rectChanges'], 1);

      probe.dispose();
      resizing.dispose();
      resizeSessionId.dispose();
      rect.dispose();
      textureId.dispose();
    });

    test('rect-only 变化保留完整 Rect 与单调相对时间', () {
      final resizing = ValueNotifier<bool>(false);
      final resizeSessionId = ValueNotifier<int>(1);
      final rect = ValueNotifier<Rect?>(const Rect.fromLTWH(0, 0, 100, 50));
      final textureId = ValueNotifier<int?>(7);
      final logger = _RecordingLogger();
      final clock = _FakeMonotonicClock();
      final probe = VideoTextureResizeProbe(
        isResizing: resizing,
        resizeSessionId: resizeSessionId,
        rect: rect,
        textureId: textureId,
        logger: logger,
        monotonicNow: clock.now,
        enabled: true,
      );

      resizing.value = true;
      clock.advance(const Duration(microseconds: 3000));
      rect.value = const Rect.fromLTWH(4, 5, 120, 60);
      clock.advance(const Duration(microseconds: 5000));
      rect.value = const Rect.fromLTWH(8, 9, 140, 70);
      resizing.value = false;

      final context = logger.entries.single.context;
      expect(context?['classification'], 'rect-only-changed');
      expect(context?['rectChanges'], 2);
      expect(context?['textureIdChanges'], 0);
      expect(context?['rectAtEnd'], _rectMap(8, 9, 148, 79));
      expect(context?['rectTrail'], [
        {'elapsedUs': 3000, 'rect': _rectMap(4, 5, 124, 65)},
        {'elapsedUs': 8000, 'rect': _rectMap(8, 9, 148, 79)},
      ]);

      probe.dispose();
      resizing.dispose();
      resizeSessionId.dispose();
      rect.dispose();
      textureId.dispose();
    });

    test('texture ID 变化记录 previous 与 next', () {
      final resizing = ValueNotifier<bool>(false);
      final resizeSessionId = ValueNotifier<int>(1);
      final rect = ValueNotifier<Rect?>(const Rect.fromLTWH(0, 0, 100, 50));
      final textureId = ValueNotifier<int?>(7);
      final logger = _RecordingLogger();
      final clock = _FakeMonotonicClock();
      final probe = VideoTextureResizeProbe(
        isResizing: resizing,
        resizeSessionId: resizeSessionId,
        rect: rect,
        textureId: textureId,
        logger: logger,
        monotonicNow: clock.now,
        enabled: true,
      );

      resizing.value = true;
      clock.advance(const Duration(microseconds: 2000));
      textureId.value = 8;
      clock.advance(const Duration(microseconds: 3000));
      textureId.value = 9;
      resizing.value = false;

      final context = logger.entries.single.context;
      expect(context?['classification'], 'texture-id-changed');
      expect(context?['rectChanges'], 0);
      expect(context?['textureIdChanges'], 2);
      expect(context?['textureIdAtEnd'], 9);
      expect(context?['textureIdTrail'], [
        {'elapsedUs': 2000, 'previousId': 7, 'nextId': 8},
        {'elapsedUs': 5000, 'previousId': 8, 'nextId': 9},
      ]);

      probe.dispose();
      resizing.dispose();
      resizeSessionId.dispose();
      rect.dispose();
      textureId.dispose();
    });

    test('构造时已在 resize 会同步接管当前会话', () {
      final resizing = ValueNotifier<bool>(true);
      final resizeSessionId = ValueNotifier<int>(3);
      final rect = ValueNotifier<Rect?>(const Rect.fromLTWH(0, 0, 100, 50));
      final textureId = ValueNotifier<int?>(3);
      final logger = _RecordingLogger();
      final clock = _FakeMonotonicClock();
      final probe = VideoTextureResizeProbe(
        isResizing: resizing,
        resizeSessionId: resizeSessionId,
        rect: rect,
        textureId: textureId,
        logger: logger,
        monotonicNow: clock.now,
        enabled: true,
      );

      clock.advance(const Duration(microseconds: 1000));
      textureId.value = 4;
      resizing.value = false;

      expect(logger.entries, hasLength(1));
      expect(logger.entries.single.context?['sessionId'], 3);
      expect(logger.entries.single.context?['textureIdChanges'], 1);
      expect(logger.entries.single.context?['textureIdAtStart'], 3);

      probe.dispose();
      resizing.dispose();
      resizeSessionId.dispose();
      rect.dispose();
      textureId.dispose();
    });

    test('长 rect trail 仅保留前八后四并报告省略数量', () {
      final resizing = ValueNotifier<bool>(false);
      final resizeSessionId = ValueNotifier<int>(1);
      final rect = ValueNotifier<Rect?>(Rect.zero);
      final textureId = ValueNotifier<int?>(1);
      final logger = _RecordingLogger();
      final clock = _FakeMonotonicClock();
      final probe = VideoTextureResizeProbe(
        isResizing: resizing,
        resizeSessionId: resizeSessionId,
        rect: rect,
        textureId: textureId,
        logger: logger,
        monotonicNow: clock.now,
        enabled: true,
      );

      resizing.value = true;
      for (var index = 1; index <= 13; index++) {
        clock.advance(const Duration(microseconds: 1));
        rect.value = Rect.fromLTWH(index.toDouble(), 0, 10, 10);
      }
      resizing.value = false;

      final context = logger.entries.single.context;
      final trail = context?['rectTrail'] as List<Object?>?;
      expect(context?['rectChanges'], 13);
      expect(context?['rectTrailOmitted'], 1);
      expect(trail, hasLength(12));
      expect((trail?[7] as Map<String, Object?>?)?['elapsedUs'], 8);
      expect((trail?[8] as Map<String, Object?>?)?['elapsedUs'], 10);
      expect((trail?[11] as Map<String, Object?>?)?['elapsedUs'], 13);

      probe.dispose();
      resizing.dispose();
      resizeSessionId.dispose();
      rect.dispose();
      textureId.dispose();
    });

    test('首帧日志同时记录源、窗口和渲染区域的逻辑与物理分辨率', () {
      final resizing = ValueNotifier<bool>(false);
      final resizeSessionId = ValueNotifier<int>(1);
      final rect = ValueNotifier<Rect?>(const Rect.fromLTWH(10, 20, 640, 360));
      final textureId = ValueNotifier<int?>(9);
      final windowSize = ValueNotifier<Size?>(const Size(1280, 720));
      final dpr = ValueNotifier<double?>(1.5);
      final logger = _RecordingLogger();
      final probe = VideoTextureResizeProbe(
        isResizing: resizing,
        resizeSessionId: resizeSessionId,
        rect: rect,
        textureId: textureId,
        windowSize: windowSize,
        devicePixelRatio: dpr,
        logger: logger,
        enabled: true,
      );

      probe.recordFirstFrame(
        observed: true,
        sourceSize: const Size(1920, 1080),
      );

      final entry = logger.entries.single;
      expect(entry.message, 'video_texture_first_frame');
      expect(
        entry.context?.keys.toSet(),
        VideoTextureResizeProbe.firstFrameContextKeys,
      );
      expect(entry.context?['sourceResolution'], _sizeMap(1920, 1080));
      expect(entry.context?['windowLogicalSize'], _sizeMap(1280, 720));
      expect(entry.context?['windowPhysicalSize'], _sizeMap(1920, 1080));
      expect(entry.context?['devicePixelRatio'], 1.5);
      expect(entry.context?['renderedRect'], _rectMap(10, 20, 650, 380));
      expect(entry.context?['renderedPhysicalSize'], _sizeMap(960, 540));
      expect(entry.context?['textureId'], 9);
      expect(entry.context?['firstFrameObserved'], isTrue);
      expect(entry.context?['classification'], 'first-frame-observed');

      probe.dispose();
      resizing.dispose();
      resizeSessionId.dispose();
      rect.dispose();
      textureId.dispose();
      windowSize.dispose();
      dpr.dispose();
    });

    test('首帧分类按可观测缺口指示问题来源', () {
      final resizing = ValueNotifier<bool>(false);
      final resizeSessionId = ValueNotifier<int>(1);
      final textureId = ValueNotifier<int?>(null);
      final windowSize = ValueNotifier<Size?>(const Size(1280, 720));
      final dpr = ValueNotifier<double?>(1);
      final logger = _RecordingLogger();
      final probe = VideoTextureResizeProbe(
        isResizing: resizing,
        resizeSessionId: resizeSessionId,
        textureId: textureId,
        windowSize: windowSize,
        devicePixelRatio: dpr,
        logger: logger,
        enabled: true,
      );

      probe.recordFirstFrame(observed: false, sourceSize: const Size(1, 1));
      expect(
        logger.entries.single.context?['classification'],
        'flutter-frame-not-observed',
      );

      probe.recordFirstFrame(observed: true, sourceSize: null);
      expect(
        logger.entries[1].context?['classification'],
        'source-metadata-missing',
      );

      probe.dispose();
      resizing.dispose();
      resizeSessionId.dispose();
      textureId.dispose();
      windowSize.dispose();
      dpr.dispose();
    });

    test('禁用与 dispose 后均不继续监听或输出', () {
      final resizing = ValueNotifier<bool>(false);
      final resizeSessionId = ValueNotifier<int>(1);
      final rect = ValueNotifier<Rect?>(Rect.zero);
      final textureId = ValueNotifier<int?>(1);
      final logger = _RecordingLogger();
      final disabled = VideoTextureResizeProbe(
        isResizing: resizing,
        resizeSessionId: resizeSessionId,
        rect: rect,
        textureId: textureId,
        logger: logger,
        enabled: false,
      );

      resizing.value = true;
      rect.value = const Rect.fromLTWH(0, 0, 20, 20);
      resizing.value = false;
      disabled.dispose();
      expect(logger.entries, isEmpty);

      final active = VideoTextureResizeProbe(
        isResizing: resizing,
        resizeSessionId: resizeSessionId,
        rect: rect,
        textureId: textureId,
        logger: logger,
        enabled: true,
      );
      resizing.value = true;
      active.dispose();
      active.dispose();
      rect.value = const Rect.fromLTWH(0, 0, 30, 30);
      textureId.value = 2;
      resizing.value = false;

      expect(logger.entries, isEmpty);
      resizing.dispose();
      resizeSessionId.dispose();
      rect.dispose();
      textureId.dispose();
    });
  });
}

Map<String, Object?> _sizeMap(double width, double height) => {
  'width': width,
  'height': height,
};

Map<String, Object?> _rectMap(
  double left,
  double top,
  double right,
  double bottom,
) => {
  'left': left,
  'top': top,
  'right': right,
  'bottom': bottom,
  'width': right - left,
  'height': bottom - top,
};

final class _FakeMonotonicClock {
  Duration _elapsed = Duration.zero;

  Duration now() => _elapsed;

  void advance(Duration delta) {
    _elapsed += delta;
  }
}

final class _LogEntry {
  const _LogEntry(this.message, this.context);

  final String message;
  final Map<String, Object?>? context;
}

class _RecordingLogger extends KernelLogger {
  final List<_LogEntry> entries = [];

  @override
  void trace(String message, {Map<String, Object?>? context}) {
    // Trace output is intentionally ignored by this test logger.
  }

  @override
  void debug(String message, {Map<String, Object?>? context}) {
    // Debug output is intentionally ignored by this test logger.
  }

  @override
  void info(String message, {Map<String, Object?>? context}) {
    entries.add(_LogEntry(message, context));
  }

  @override
  void warn(String message, {Map<String, Object?>? context}) {
    // Warning output is intentionally ignored by this test logger.
  }

  @override
  void error(
    String message, {
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    // Error output is intentionally ignored by this test logger.
  }

  @override
  void fatal(
    String message, {
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    // Fatal output is intentionally ignored by this test logger.
  }
}

final class _ReentrantProbeLogger extends _RecordingLogger {
  _ReentrantProbeLogger({required this.onFirstEntry});

  final void Function() onFirstEntry;
  bool _hasReentered = false;

  @override
  void info(String message, {Map<String, Object?>? context}) {
    super.info(message, context: context);
    if (_hasReentered) return;
    _hasReentered = true;
    // 模拟同步日志 sink 在旧摘要写出期间立刻启动下一段 resize。
    onFirstEntry();
  }
}
