import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/bridge/window_bridge.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';

void main() {
  setUpAll(() {
    // 用 TestWidgetsFlutterBinding (非 WidgetsFlutterBinding) — 其
    // defaultBinaryMessenger 是 TestDefaultBinaryMessenger, 支持 mock
    // MethodChannel (resize 测试需 mock window_manager.getSize).
    TestWidgetsFlutterBinding.ensureInitialized();
    // WindowService callback methods use KernelLogger.I — must init first
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  tearDownAll(KernelLoggerImpl.resetForTesting);

  group('WindowService composition', () {
    test('state.mode defaults to windowed', () {
      final service = WindowService();
      expect(service.mode.value, WindowMode.windowed);
      service.dispose();
    });

    test('mode getter delegates to state.mode', () {
      final service = WindowService();
      expect(service.mode.value, WindowMode.windowed);
      service.mode.value = WindowMode.maximized;
      expect(service.mode.value, WindowMode.maximized);
      service.dispose();
    });

    test('state windowSize defaults to 1280x752', () {
      final service = WindowService();
      expect(service.windowSize.value.width, 1280);
      expect(service.windowSize.value.height, 752);
      service.dispose();
    });
  });

  group('WindowListener callbacks', () {
    test('onWindowMaximize sets mode to maximized', () {
      final service = WindowService();
      service.onWindowMaximize();
      expect(service.mode.value, WindowMode.maximized);
      service.dispose();
    });

    test('onWindowUnmaximize sets mode to windowed', () {
      final service = WindowService();
      service.mode.value = WindowMode.maximized;
      service.onWindowUnmaximize();
      expect(service.mode.value, WindowMode.windowed);
      service.dispose();
    });
  });

  group('dispose safety', () {
    test('callback after dispose does not throw', () {
      final service = WindowService();
      service.dispose();
      expect(() => service.onWindowMaximize(), returnsNormally);
      expect(() => service.onWindowUnmaximize(), returnsNormally);
      expect(() => service.onWindowResize(), returnsNormally);
    });

    test('double dispose does not throw', () {
      final service = WindowService();
      service.dispose();
      expect(() => service.dispose(), returnsNormally);
    });
  });

  // TODO: Phase 4 — rewrite driver creation tests without FullscreenDriver
  // WindowService no longer accepts driver parameter (Phase 1 removed it).

  // TODO: Phase 4 — rewrite FullscreenResult tests
  // FullscreenResult/FullscreenSuccess/FullscreenFailure sealed class deleted in Phase 1.

  // TODO: Phase 4 — rewrite confirmation chain tests
  // FullscreenDriver mock and WindowService(driver:) constructor deleted in Phase 1.

  group('isFullscreen derives from mode', () {
    test('isFullscreen returns false when mode is windowed', () {
      final service = WindowService();
      expect(service.isFullscreen, isFalse);
      expect(service.mode.value, WindowMode.windowed);
      service.dispose();
    });

    test('isFullscreen returns true when mode is fullscreen', () {
      final service = WindowService();
      service.mode.value = WindowMode.fullscreen;
      expect(service.isFullscreen, isTrue);
      service.dispose();
    });

    test('isFullscreen tracks mode changes', () {
      final service = WindowService();
      expect(service.isFullscreen, isFalse);
      service.mode.value = WindowMode.fullscreen;
      expect(service.isFullscreen, isTrue);
      service.mode.value = WindowMode.windowed;
      expect(service.isFullscreen, isFalse);
      service.dispose();
    });
  });

  // =========================================================================
  // Deep coverage: WindowState fields
  // =========================================================================
  group('WindowState', () {
    test('windowSize defaults to 1280x752', () {
      final service = WindowService();
      expect(service.windowSize.value.width, 1280);
      expect(service.windowSize.value.height, 752);
      service.dispose();
    });

    test('mode defaults to windowed', () {
      final service = WindowService();
      expect(service.mode.value, WindowMode.windowed);
      service.dispose();
    });

    test('isResizing defaults to false', () {
      final service = WindowService();
      expect(service.isResizing.value, isFalse);
      service.dispose();
    });

    test('isAlwaysOnTop defaults to false', () {
      final service = WindowService();
      expect(service.isAlwaysOnTop.value, isFalse);
      service.dispose();
    });
  });

  // =========================================================================
  // Deep coverage: mode transitions
  // =========================================================================
  group('mode transitions', () {
    test('setting mode to same value does not fire extra notification', () {
      final service = WindowService();
      var count = 0;
      service.mode.addListener(() => count++);
      service.mode.value = WindowMode.maximized; // fires once
      service.mode.value = WindowMode.maximized; // same value — no fire
      expect(count, 1);
      service.dispose();
    });

    test('windowed → maximized → windowed cycle', () {
      final service = WindowService();
      expect(service.mode.value, WindowMode.windowed);

      service.mode.value = WindowMode.maximized;
      expect(service.mode.value, WindowMode.maximized);
      expect(service.isFullscreen, isFalse);

      service.mode.value = WindowMode.windowed;
      expect(service.mode.value, WindowMode.windowed);

      service.dispose();
    });

    test('windowed → fullscreen → windowed cycle', () {
      final service = WindowService();
      service.mode.value = WindowMode.fullscreen;
      expect(service.isFullscreen, isTrue);

      service.mode.value = WindowMode.windowed;
      expect(service.isFullscreen, isFalse);

      service.dispose();
    });
  });

  // =========================================================================
  // Deep coverage: WindowListener callback details
  // =========================================================================
  group('WindowListener callback deep', () {
    test('onWindowMaximize is idempotent when already maximized', () {
      final service = WindowService();
      service.mode.value = WindowMode.maximized;
      service.onWindowMaximize();
      expect(service.mode.value, WindowMode.maximized);
      service.dispose();
    });

    test('onWindowUnmaximize from non-maximized is no-op', () {
      final service = WindowService();
      expect(service.mode.value, WindowMode.windowed);
      service.onWindowUnmaximize();
      expect(service.mode.value, WindowMode.windowed);
      service.dispose();
    });

    test('onWindowResize after dispose is no-op', () {
      final service = WindowService();
      service.dispose();
      expect(() => service.onWindowResize(), returnsNormally);
    });
  });

  // =========================================================================
  // Deep coverage: dispose safety expanded
  // =========================================================================
  group('dispose safety expanded', () {
    test('triple dispose does not throw', () {
      final service = WindowService();
      service.dispose();
      service.dispose();
      service.dispose();
    });

    test('all callbacks are safe after dispose', () {
      final service = WindowService();
      service.dispose();
      expect(() => service.onWindowMaximize(), returnsNormally);
      expect(() => service.onWindowUnmaximize(), returnsNormally);
      expect(() => service.onWindowResize(), returnsNormally);
    });
  });

  // =========================================================================
  // Deep coverage: WindowMode enum
  // =========================================================================
  group('WindowMode enum', () {
    test('has 3 values', () {
      expect(WindowMode.values, hasLength(3));
    });

    test('windowed isFullscreen is false', () {
      expect(WindowMode.windowed.isFullscreen, isFalse);
    });

    test('fullscreen isFullscreen is true', () {
      expect(WindowMode.fullscreen.isFullscreen, isTrue);
    });

    test('maximized isMaximized is true', () {
      expect(WindowMode.maximized.isMaximized, isTrue);
    });

    test('windowed isWindowed is true', () {
      expect(WindowMode.windowed.isWindowed, isTrue);
    });

    test('enum names are correct', () {
      expect(WindowMode.windowed.name, 'windowed');
      expect(WindowMode.maximized.name, 'maximized');
      expect(WindowMode.fullscreen.name, 'fullscreen');
    });
  });

  // =========================================================================
  // Deep coverage: ValueNotifier listeners
  // =========================================================================
  group('ValueNotifier listeners', () {
    test('mode notifier fires listeners', () {
      final service = WindowService();
      var notified = false;
      service.mode.addListener(() => notified = true);

      service.mode.value = WindowMode.maximized;
      expect(notified, isTrue);

      service.dispose();
    });

    test('windowSize notifier fires listeners', () {
      final service = WindowService();
      var notified = false;
      service.windowSize.addListener(() => notified = true);

      service.windowSize.value = const Size(1920, 1080);
      expect(notified, isTrue);

      service.dispose();
    });

    test('isResizing notifier fires listeners', () {
      final service = WindowService();
      var notified = false;
      service.isResizing.addListener(() => notified = true);

      service.isResizing.value = true;
      expect(notified, isTrue);

      service.dispose();
    });

    test('isAlwaysOnTop notifier fires listeners', () {
      final service = WindowService();
      var notified = false;
      service.isAlwaysOnTop.addListener(() => notified = true);

      service.isAlwaysOnTop.value = true;
      expect(notified, isTrue);

      service.dispose();
    });
  });

  // =========================================================================
  // 全屏 mode 同步 — _fullscreenIntent 守卫 (需求1 治本方案 A)
  // =========================================================================
  group('fullscreen mode sync (_fullscreenIntent guard)', () {
    // 方案 B: setMode(fullscreen/windowed) 只设 intent+mode, 不调平台接口
    // (实际全屏由 media_kit VideoState.toggleFullscreen 完成). 守卫测试验证 mode 同步.

    test('setMode(fullscreen) sets mode + intent', () async {
      final service = WindowService();
      await service.setMode(WindowMode.fullscreen);
      expect(service.mode.value, WindowMode.fullscreen);
      expect(service.isFullscreen, isTrue);
      service.dispose();
    });

    test(
      'onWindowMaximize during fullscreen intent keeps mode fullscreen',
      () async {
        // SC_MAXIMIZE 噪音不应覆盖 mode — _fullscreenIntent 守卫
        final service = WindowService();
        await service.setMode(WindowMode.fullscreen);
        service.onWindowMaximize();
        expect(service.mode.value, WindowMode.fullscreen);
        service.dispose();
      },
    );

    test('onWindowUnmaximize during fullscreen intent is no-op', () async {
      final service = WindowService();
      await service.setMode(WindowMode.fullscreen);
      service.onWindowUnmaximize();
      expect(service.mode.value, WindowMode.fullscreen);
      service.dispose();
    });

    test(
      'setMode(windowed) from fullscreen clears intent + sets windowed',
      () async {
        final service = WindowService();
        await service.setMode(WindowMode.fullscreen);
        await service.setMode(WindowMode.windowed);
        expect(service.mode.value, WindowMode.windowed);
        expect(service.isFullscreen, isFalse);
        service.dispose();
      },
    );

    test('onWindowMaximize without intent sets maximized (regression)', () {
      // 守卫不影响正常最大化路径
      final service = WindowService();
      service.onWindowMaximize();
      expect(service.mode.value, WindowMode.maximized);
      service.dispose();
    });

    test('setMode(fullscreen) no-op when already fullscreen', () async {
      final service = WindowService();
      await service.setMode(WindowMode.fullscreen);
      await service.setMode(WindowMode.fullscreen); // 同值, 早退
      expect(service.mode.value, WindowMode.fullscreen);
      service.dispose();
    });
  });

  // =========================================================================
  // resize debounce + isResizing 恢复 (方向2 — isResizing 卡 true bug 回归)
  // =========================================================================
  group('resize debounce + isResizing recovery', () {
    // window_manager 包用 MethodChannel('window_manager')，getSize() 内部走
    // getBounds 并返回 x/y/width/height。mock 之以便 fakeAsync 推进 500ms
    // timer 后验证回调逻辑（无需真实窗口）。
    const wmChannel = MethodChannel('window_manager');
    Size? mockSize;
    var shouldFailBounds = false;
    final pendingBounds = <Completer<Map<String, double>>>[];
    var deferBounds = false;

    /// 取测试用 messenger — setUpAll 已初始化 TestWidgetsFlutterBinding,
    /// 其 defaultBinaryMessenger 静态类型即 TestDefaultBinaryMessenger
    /// (无需 is 提升或 as cast).
    TestDefaultBinaryMessenger messenger() =>
        TestWidgetsFlutterBinding.instance.defaultBinaryMessenger;

    setUp(() {
      mockSize = null;
      shouldFailBounds = false;
      deferBounds = false;
      pendingBounds.clear();
      messenger().setMockMethodCallHandler(wmChannel, (call) async {
        // window_manager 0.5.2: getSize() 内部调 getBounds() (非 getWindowSize
        // method — 该 method 从不被调用, 勿 mock). getBounds 期望返回 Map 字段
        // x/y/width/height (非 left/top — 否则 Rect.fromLTWH 读 null →
        // type 'Null' is not subtype of double). 局部提升消除 bang.
        if (call.method != 'getBounds') return null;
        if (shouldFailBounds) throw Exception('getBounds failed');
        if (deferBounds) {
          final result = Completer<Map<String, double>>();
          pendingBounds.add(result);
          return result.future;
        }
        final sz = mockSize;
        if (sz == null) return null;
        return {'x': 0.0, 'y': 0.0, 'width': sz.width, 'height': sz.height};
      });
    });

    tearDown(() {
      messenger().setMockMethodCallHandler(wmChannel, null);
    });

    test('onWindowResize sets isResizing true immediately', () {
      final service = WindowService();
      expect(service.isResizing.value, isFalse);
      service.onWindowResize();
      expect(service.isResizing.value, isTrue);
      service.dispose();
    });

    test('resize session ID 在上升沿先发布、活跃期不重复递增', () {
      fakeAsync((async) {
        mockSize = const Size(1280, 752);
        final service = WindowService();
        final sessionIdsSeenAtStart = <int>[];
        service.isResizing.addListener(() {
          if (service.isResizing.value) {
            sessionIdsSeenAtStart.add(service.resizeSessionId.value);
          }
        });

        service.onWindowResize();
        service.onWindowResize();
        expect(service.resizeSessionId.value, 1);
        expect(sessionIdsSeenAtStart, [1]);

        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();
        expect(service.isResizing.value, isFalse);

        service.onWindowResize();
        expect(service.resizeSessionId.value, 2);
        expect(sessionIdsSeenAtStart, [1, 2]);
        service.dispose();
      });
    });

    test('isResizing recovers false after debounce when size changed', () {
      fakeAsync((async) {
        mockSize = const Size(1920, 1080);
        final service = WindowService();
        service.onWindowResize();
        expect(service.isResizing.value, isTrue);

        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        expect(service.isResizing.value, isFalse);
        expect(service.windowSize.value, const Size(1920, 1080));
        service.dispose();
      });
    });

    test('isResizing recovers false even when size unchanged (regression)', () {
      // 旧 bug: isResizing=false 包在 if(size!=windowSize) 内, size 净变化
      // 为零时不落 false → 控制栏永不恢复. 默认 windowSize=1280x752, mock
      // getSize 返回同值 → 触发 bug 场景. 修复后无论 size 是否变化都落 false.
      fakeAsync((async) {
        mockSize = const Size(1280, 752);
        final service = WindowService();
        service.onWindowResize();
        expect(service.isResizing.value, isTrue);

        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        expect(service.isResizing.value, isFalse);
        service.dispose();
      });
    });

    test('repeated onWindowResize resets debounce timer', () {
      fakeAsync((async) {
        mockSize = const Size(1920, 1080);
        final service = WindowService();
        service.onWindowResize();
        async.elapse(const Duration(milliseconds: 400));
        expect(service.isResizing.value, isTrue);

        service.onWindowResize(); // 重置 500ms timer
        async.elapse(const Duration(milliseconds: 400));
        expect(service.isResizing.value, isTrue);

        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();
        expect(service.isResizing.value, isFalse);
        service.dispose();
      });
    });

    test(
      'stale getSize completion cannot overwrite a newer resize session',
      () {
        fakeAsync((async) {
          deferBounds = true;
          final service = WindowService();

          service.onWindowResize();
          async.elapse(const Duration(milliseconds: 500));
          async.flushMicrotasks();
          expect(pendingBounds, hasLength(1));

          service.onWindowResize();
          async.elapse(const Duration(milliseconds: 500));
          async.flushMicrotasks();
          expect(pendingBounds, hasLength(2));

          pendingBounds[1].complete({
            'x': 0.0,
            'y': 0.0,
            'width': 1920.0,
            'height': 1080.0,
          });
          async.flushMicrotasks();
          expect(service.windowSize.value, const Size(1920, 1080));
          expect(service.isResizing.value, isFalse);

          pendingBounds.first.complete({
            'x': 0.0,
            'y': 0.0,
            'width': 1600.0,
            'height': 900.0,
          });
          async.flushMicrotasks();
          expect(service.windowSize.value, const Size(1920, 1080));
          expect(service.isResizing.value, isFalse);
          service.dispose();
        });
      },
    );

    test('getSize failure still ends the current resize session', () {
      fakeAsync((async) {
        shouldFailBounds = true;
        final service = WindowService();
        final initialSize = service.windowSize.value;

        service.onWindowResize();
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        expect(service.isResizing.value, isFalse);
        expect(service.windowSize.value, initialSize);
        service.dispose();
      });
    });

    test('pending getSize completion is ignored after dispose', () {
      fakeAsync((async) {
        deferBounds = true;
        final service = WindowService();
        final initialSize = service.windowSize.value;

        service.onWindowResize();
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();
        expect(pendingBounds, hasLength(1));

        service.dispose();
        pendingBounds.single.complete({
          'x': 0.0,
          'y': 0.0,
          'width': 1920.0,
          'height': 1080.0,
        });
        async.flushMicrotasks();

        expect(service.windowSize.value, initialSize);
      });
    });
  });
}
