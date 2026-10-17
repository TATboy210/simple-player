import 'dart:async';
import 'dart:ui';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_player_flutter/kernel/window_bridge/window_manager_service.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';

import '../../../helpers/fake_native_window_host.dart';

void main() {
  setUpAll(() {
    // shared_preferences 内存 mock 需要 test binding。
    TestWidgetsFlutterBinding.ensureInitialized();
    // WindowService callback methods use KernelLogger.I — must init first
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  tearDownAll(KernelLoggerImpl.resetForTesting);

  // 每个用例一份新的原生窗口端口 fake（取代 window_frame_kit channel mock）。
  late FakeNativeWindowHost host;
  setUp(() => host = FakeNativeWindowHost());

  group('WindowService composition', () {
    test('state.mode defaults to windowed', () {
      final service = WindowService(host: host);
      expect(service.mode.value, WindowMode.windowed);
      service.dispose();
    });

    test('mode getter delegates to state.mode', () {
      final service = WindowService(host: host);
      expect(service.mode.value, WindowMode.windowed);
      service.mode.value = WindowMode.maximized;
      expect(service.mode.value, WindowMode.maximized);
      service.dispose();
    });

    test('state windowSize defaults to defaultWindowSize', () {
      final service = WindowService(host: host);
      expect(service.windowSize.value, defaultWindowSize);
      service.dispose();
    });
  });

  group('WindowListener callbacks', () {
    test('onWindowMaximize sets mode to maximized', () {
      final service = WindowService(host: host);
      service.onWindowMaximize();
      expect(service.mode.value, WindowMode.maximized);
      service.dispose();
    });

    test('onWindowUnmaximize sets mode to windowed', () {
      final service = WindowService(host: host);
      service.mode.value = WindowMode.maximized;
      service.onWindowUnmaximize();
      expect(service.mode.value, WindowMode.windowed);
      service.dispose();
    });
  });

  group('dispose safety', () {
    test('callback after dispose does not throw', () {
      final service = WindowService(host: host);
      service.dispose();
      expect(() => service.onWindowMaximize(), returnsNormally);
      expect(() => service.onWindowUnmaximize(), returnsNormally);
      expect(() => service.onWindowResize(), returnsNormally);
    });

    test('double dispose does not throw', () {
      final service = WindowService(host: host);
      service.dispose();
      expect(() => service.dispose(), returnsNormally);
    });
  });

  // 待办: Phase 4 — rewrite driver creation tests without FullscreenDriver
  // WindowService no longer accepts driver parameter (Phase 1 removed it).

  // 待办: Phase 4 — rewrite FullscreenResult tests
  // FullscreenResult/FullscreenSuccess/FullscreenFailure sealed class deleted in Phase 1.

  // 待办: Phase 4 — rewrite confirmation chain tests
  // FullscreenDriver mock and WindowService(driver:) constructor deleted in Phase 1.

  group('isFullscreen derives from mode', () {
    test('isFullscreen returns false when mode is windowed', () {
      final service = WindowService(host: host);
      expect(service.isFullscreen, isFalse);
      expect(service.mode.value, WindowMode.windowed);
      service.dispose();
    });

    test('isFullscreen returns true when mode is fullscreen', () {
      final service = WindowService(host: host);
      service.mode.value = WindowMode.fullscreen;
      expect(service.isFullscreen, isTrue);
      service.dispose();
    });

    test('isFullscreen tracks mode changes', () {
      final service = WindowService(host: host);
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
    test('windowSize defaults to defaultWindowSize', () {
      final service = WindowService(host: host);
      expect(service.windowSize.value, defaultWindowSize);
      service.dispose();
    });

    test('mode defaults to windowed', () {
      final service = WindowService(host: host);
      expect(service.mode.value, WindowMode.windowed);
      service.dispose();
    });

    test('isResizing defaults to false', () {
      final service = WindowService(host: host);
      expect(service.isResizing.value, isFalse);
      service.dispose();
    });

    test('isAlwaysOnTop defaults to false', () {
      final service = WindowService(host: host);
      expect(service.isAlwaysOnTop.value, isFalse);
      service.dispose();
    });
  });

  // =========================================================================
  // Deep coverage: mode transitions
  // =========================================================================
  group('mode transitions', () {
    test('setting mode to same value does not fire extra notification', () {
      final service = WindowService(host: host);
      var count = 0;
      service.mode.addListener(() => count++);
      service.mode.value = WindowMode.maximized; // fires once
      service.mode.value = WindowMode.maximized; // same value — no fire
      expect(count, 1);
      service.dispose();
    });

    test('windowed → maximized → windowed cycle', () {
      final service = WindowService(host: host);
      expect(service.mode.value, WindowMode.windowed);

      service.mode.value = WindowMode.maximized;
      expect(service.mode.value, WindowMode.maximized);
      expect(service.isFullscreen, isFalse);

      service.mode.value = WindowMode.windowed;
      expect(service.mode.value, WindowMode.windowed);

      service.dispose();
    });

    test('windowed → fullscreen → windowed cycle', () {
      final service = WindowService(host: host);
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
      final service = WindowService(host: host);
      service.mode.value = WindowMode.maximized;
      service.onWindowMaximize();
      expect(service.mode.value, WindowMode.maximized);
      service.dispose();
    });

    test('onWindowUnmaximize from non-maximized is no-op', () {
      final service = WindowService(host: host);
      expect(service.mode.value, WindowMode.windowed);
      service.onWindowUnmaximize();
      expect(service.mode.value, WindowMode.windowed);
      service.dispose();
    });

    test('onWindowResize after dispose is no-op', () {
      final service = WindowService(host: host);
      service.dispose();
      expect(() => service.onWindowResize(), returnsNormally);
    });
  });

  // =========================================================================
  // Deep coverage: dispose safety expanded
  // =========================================================================
  group('dispose safety expanded', () {
    test('triple dispose does not throw', () {
      final service = WindowService(host: host);
      service.dispose();
      service.dispose();
      service.dispose();
    });

    test('all callbacks are safe after dispose', () {
      final service = WindowService(host: host);
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
      final service = WindowService(host: host);
      var notified = false;
      service.mode.addListener(() => notified = true);

      service.mode.value = WindowMode.maximized;
      expect(notified, isTrue);

      service.dispose();
    });

    test('windowSize notifier fires listeners', () {
      final service = WindowService(host: host);
      var notified = false;
      service.windowSize.addListener(() => notified = true);

      service.windowSize.value = const Size(1920, 1080);
      expect(notified, isTrue);

      service.dispose();
    });

    test('isResizing notifier fires listeners', () {
      final service = WindowService(host: host);
      var notified = false;
      service.isResizing.addListener(() => notified = true);

      service.isResizing.value = true;
      expect(notified, isTrue);

      service.dispose();
    });

    test('isAlwaysOnTop notifier fires listeners', () {
      final service = WindowService(host: host);
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
      final service = WindowService(host: host);
      await service.setMode(WindowMode.fullscreen);
      expect(service.mode.value, WindowMode.fullscreen);
      expect(service.isFullscreen, isTrue);
      service.dispose();
    });

    test(
      'onWindowMaximize during fullscreen intent keeps mode fullscreen',
      () async {
        // SC_MAXIMIZE 噪音不应覆盖 mode — _fullscreenIntent 守卫
        final service = WindowService(host: host);
        await service.setMode(WindowMode.fullscreen);
        service.onWindowMaximize();
        expect(service.mode.value, WindowMode.fullscreen);
        service.dispose();
      },
    );

    test('onWindowUnmaximize during fullscreen intent is no-op', () async {
      final service = WindowService(host: host);
      await service.setMode(WindowMode.fullscreen);
      service.onWindowUnmaximize();
      expect(service.mode.value, WindowMode.fullscreen);
      service.dispose();
    });

    test(
      'setMode(windowed) from fullscreen clears intent + sets windowed',
      () async {
        final service = WindowService(host: host);
        await service.setMode(WindowMode.fullscreen);
        await service.setMode(WindowMode.windowed);
        expect(service.mode.value, WindowMode.windowed);
        expect(service.isFullscreen, isFalse);
        service.dispose();
      },
    );

    test('onWindowMaximize without intent sets maximized (regression)', () {
      // 守卫不影响正常最大化路径
      final service = WindowService(host: host);
      service.onWindowMaximize();
      expect(service.mode.value, WindowMode.maximized);
      service.dispose();
    });

    test('setMode(fullscreen) no-op when already fullscreen', () async {
      final service = WindowService(host: host);
      await service.setMode(WindowMode.fullscreen);
      await service.setMode(WindowMode.fullscreen); // 同值, 早退
      expect(service.mode.value, WindowMode.fullscreen);
      service.dispose();
    });
  });

  // =========================================================================
  // 全屏过渡 resize 的 windowSize 污染防护
  // =========================================================================
  // media_kit 原生全屏将窗口 resize 到显示器尺寸(进入/退出各一次), 触发的
  // resize settle 若更新 windowSize, 显示器尺寸会经关闭路径持久化, 下次启动
  // 恢复成巨窗。settle 在全屏模式期间只清 isResizing, 不更新 windowSize。
  group('fullscreen transition resize settle guard', () {
    test('settle during fullscreen does not update windowSize', () {
      // 全屏进入/退出的 resize 是过渡: settle 只清 isResizing, 不更新
      // windowSize — 否则显示器尺寸会经关闭路径持久化, 下次启动巨窗。
      fakeAsync((async) {
        final service = WindowService(host: host);
        service.mode.value = WindowMode.fullscreen;
        host.size = const Size(1920, 1080); // 模拟进入全屏后的显示器尺寸
        service.onWindowResize();
        expect(service.isResizing.value, isTrue);
        async.elapse(const Duration(milliseconds: 600));
        // isResizing 必须清除 (filterQuality 恢复依赖)
        expect(service.isResizing.value, isFalse);
        // windowSize 保持窗口态尺寸, 不被显示器尺寸污染
        expect(service.windowSize.value, defaultWindowSize);
        service.dispose();
      });
    });
  });

  // =========================================================================
  // resize debounce + isResizing 恢复 (方向2 — isResizing 卡 true bug 回归)
  // =========================================================================
  group('resize debounce + isResizing recovery', () {
    test('onWindowResize sets isResizing true immediately', () {
      final service = WindowService(host: host);
      expect(service.isResizing.value, isFalse);
      service.onWindowResize();
      expect(service.isResizing.value, isTrue);
      service.dispose();
    });

    test('resize session ID 在上升沿先发布、活跃期不重复递增', () {
      fakeAsync((async) {
        host.size = const Size(1280, 752);
        final service = WindowService(host: host);
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
        host.size = const Size(1920, 1080);
        final service = WindowService(host: host);
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
        host.size = const Size(1280, 752);
        final service = WindowService(host: host);
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
        host.size = const Size(1920, 1080);
        final service = WindowService(host: host);
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
          host.deferGetSize = true;
          final service = WindowService(host: host);

          service.onWindowResize();
          async.elapse(const Duration(milliseconds: 500));
          async.flushMicrotasks();
          expect(host.pendingSizes, hasLength(1));

          service.onWindowResize();
          async.elapse(const Duration(milliseconds: 500));
          async.flushMicrotasks();
          expect(host.pendingSizes, hasLength(2));

          host.pendingSizes[1].complete(const Size(1920, 1080));
          async.flushMicrotasks();
          expect(service.windowSize.value, const Size(1920, 1080));
          expect(service.isResizing.value, isFalse);

          host.pendingSizes.first.complete(const Size(1600, 900));
          async.flushMicrotasks();
          expect(service.windowSize.value, const Size(1920, 1080));
          expect(service.isResizing.value, isFalse);
          service.dispose();
        });
      },
    );

    test('getSize failure still ends the current resize session', () {
      fakeAsync((async) {
        host.failGetSize = true;
        final service = WindowService(host: host);
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
        host.deferGetSize = true;
        final service = WindowService(host: host);
        final initialSize = service.windowSize.value;

        service.onWindowResize();
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();
        expect(host.pendingSizes, hasLength(1));

        service.dispose();
        host.pendingSizes.single.complete(const Size(1920, 1080));
        async.flushMicrotasks();

        expect(service.windowSize.value, initialSize);
      });
    });
  });

  // =========================================================================
  // resize 抑制标志生命周期 — init → reveal (261009-rp3 证伪测试)
  // =========================================================================
  // 假设: _initWindow 在隐藏 init 阶段置位 _activeResizeSuppression, 设计为
  // 吞掉几何恢复引发的那一次 WM_SIZE; 但只有"真的来了一次 resize 事件"才
  // 清零。若恢复尺寸与当前尺寸相同(首会话默认 1280×720 从未改过), 平台不
  // 产生 WM_SIZE → 标志滞留 → 亮窗后用户第一次真实拖拽被吞(isResizing 不
  // 置位/windowSize 不更新/几何不持久化), 第二次拖拽才恢复。
  group('resize suppression lifecycle (init → reveal)', () {
    setUp(() {
      // 首会话: 无持久化几何 → load() 回落默认 1280×720 (defaultWindowSize).
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    /// 走真实 init() 链路 (fake 端口 + 内存 prefs 全是 microtask 级),
    /// flush 后即完成; 同时校验"完成"与"无异常" — 挂起说明 fake 端口
    /// 有缺口 (fakeAsync 下永不完成的 future 静默无错误).
    void runInit(WindowService service, FakeAsync async) {
      var initDone = false;
      Object? initError;
      StackTrace? initStack;
      unawaited(
        service.init().then(
          (_) {
            initDone = true;
          },
          onError: (Object error, StackTrace stackTrace) {
            initError = error;
            initStack = stackTrace;
          },
        ),
      );
      async.flushMicrotasks();
      expect(
        initDone,
        isTrue,
        reason: 'init 必须在 flush 内完成: error=$initError\n$initStack',
      );
      expect(initError, isNull, reason: 'init 必须无异常: $initError\n$initStack');
    }

    test('first drag-resize after reveal is not swallowed when init restored '
        'the same size (no WM_SIZE)', () {
      fakeAsync((async) {
        host.size = defaultWindowSize; // 恢复尺寸 == 当前尺寸 → 无 WM_SIZE
        final service = WindowService(host: host);
        runInit(service, async);

        // 前提成立: 几何已恢复进状态, 平台全程无 WM_SIZE 回放.
        expect(service.windowSize.value, defaultWindowSize);
        expect(service.isResizing.value, isFalse);

        // 亮窗 — 生产时序: 组合根首帧栅格化后调用 (main.dart).
        unawaited(service.reveal());
        async.flushMicrotasks();

        // 用户启动后第一次真实拖拽缩放.
        host.size = const Size(1600, 900);
        service.onWindowResize();

        // === 决定性断言: 首拖必须生效 (不被抑制标志吞掉) ===
        expect(service.isResizing.value, isTrue);

        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();
        expect(service.isResizing.value, isFalse);
        expect(service.windowSize.value, const Size(1600, 900));

        // 几何持久化被触发 (windowWidth/Height 落盘到偏好存储).
        SharedPreferences? prefs;
        unawaited(SharedPreferences.getInstance().then((p) => prefs = p));
        async.flushMicrotasks();
        final resolvedPrefs = prefs;
        if (resolvedPrefs == null) fail('getInstance 必须已解析');
        expect(resolvedPrefs.getDouble('windowWidth'), 1600.0);
        expect(resolvedPrefs.getDouble('windowHeight'), 900.0);

        service.dispose();
      });
    });

    test('pre-reveal restore WM_SIZE is still swallowed once (suppression '
        'purpose preserved)', () {
      fakeAsync((async) {
        // 恢复尺寸(1280×720) != 当前尺寸 → init 的 setBounds 会引发
        // WM_SIZE, 在亮窗前送达 — 这正是抑制标志存在的目的场景.
        host.size = const Size(1600, 900);
        final service = WindowService(host: host);
        runInit(service, async);
        expect(service.windowSize.value, defaultWindowSize);

        // init 几何恢复引发的 WM_SIZE 到达 (亮窗前) — 必须被吞一次.
        service.onWindowResize();
        expect(service.isResizing.value, isFalse);

        // 亮窗后用户拖拽 — 必须恢复正常 (不被二次吞).
        service.onWindowResize();
        expect(service.isResizing.value, isTrue);
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();
        expect(service.windowSize.value, const Size(1600, 900));

        service.dispose();
      });
    });
  });

  // =========================================================================
  // 关窗路径 — hide-first 模式 (学自 BlueBubbles)
  // =========================================================================
  group('close path (hide-first)', () {
    test('onWindowClose hides the window before persisting and exiting', () {
      fakeAsync((async) {
        // host.calls 记录原生窗口端口上每个调用的顺序。
        host.position = const Offset(10, 20);
        final calls = host.calls;
        final exitCodes = <int>[];

        final service = WindowService(host: host, exitOnClose: exitCodes.add);
        service.onWindowClose();

        // 推进足够时间让 hide → persist(getPosition) → destroy(fire) → exit
        // 全部完成。
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        // hide 必须最先 — 用户点 X 后窗口立即消失（BlueBubbles 模式）。
        expect(calls.first, 'hide');
        // 持久化读取位置(getPosition)发生在 hide 之后、destroy 之前。
        final persistIndex = calls.indexOf('getPosition');
        final destroyIndex = calls.indexOf('destroy');
        expect(persistIndex, greaterThan(calls.indexOf('hide')));
        expect(destroyIndex, greaterThan(persistIndex));
        // 进程终止恰好一次、退出码 0（BB 同款硬杀 — 立即退出不留滞留）。
        expect(exitCodes, [0]);
        // 服务进入终态。
        expect(service.isResizing.value, isFalse);
      });
    });

    test('a stuck hide does not block persist or exit (timeout guard)', () {
      fakeAsync((async) {
        final calls = host.calls;
        // hide 永远不返回 — 模拟平台调用卡死。
        host.hideResult = Completer<void>().future;
        final exitCodes = <int>[];

        final service = WindowService(host: host, exitOnClose: exitCodes.add);
        service.onWindowClose();

        // 800ms hide 超时 + persist — 5s 足够全部走完。
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        // hide 卡死但 destroy 依然被触发、exit(0) 依然到达 — 超时兜底生效。
        expect(calls, contains('destroy'));
        expect(exitCodes, [0]);
      });
    });

    test('closing listener 在 exit 前被 await 完成 (v0.0.6.2)', () {
      fakeAsync((async) {
        final events = <String>[];
        host.position = const Offset(10, 20);

        final service = WindowService(
          host: host,
          exitOnClose: (code) => events.add('exit:$code'),
        );
        service.addClosingListener(() async {
          events.add('listener-start');
          await Future<void>.delayed(const Duration(milliseconds: 100));
          events.add('listener-done');
        });

        service.onWindowClose();
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        // 监听器完整执行（start→done）先于进程终止 — 断点落盘窗口有保证.
        expect(events, ['listener-start', 'listener-done', 'exit:0']);
      });
    });

    test('closing listener 抛异常不阻断退出 (v0.0.6.2)', () {
      fakeAsync((async) {
        host.position = const Offset(10, 20);
        final exitCodes = <int>[];

        final service = WindowService(host: host, exitOnClose: exitCodes.add);
        var called = false;
        service.addClosingListener(() async {
          called = true;
          throw Exception('listener boom');
        });

        service.onWindowClose();
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        expect(called, isTrue);
        expect(exitCodes, [0]); // 异常被 _runCloseCommand 吞掉记日志, 退出仍到达
      });
    });

    test('closing listener 卡死触发 800ms 超时后继续退出 (v0.0.6.2)', () {
      fakeAsync((async) {
        host.position = const Offset(10, 20);
        final exitCodes = <int>[];

        final service = WindowService(host: host, exitOnClose: exitCodes.add);
        // 返回永不完成的 future — 模拟落盘卡死 (磁盘满/杀毒锁文件等).
        final never = Completer<void>();
        service.addClosingListener(() => never.future);

        service.onWindowClose();

        // 800ms 超时 + 收尾 — 5s 足够走完.
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        expect(exitCodes, [0]); // 超时兜底生效, 绝不让用户面对滞留窗口
      });
    });
  });

  // =========================================================================
  // NativeWindowHost 端口接线 (2026-10 nativeapi 迁移)
  // =========================================================================
  group('native window host wiring', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    /// init 全链路在 fake 端口上是 microtask 级 — flush 后必须完成。
    void initNow(WindowService service, FakeAsync async) {
      Object? error;
      var done = false;
      unawaited(
        service.init().then(
          (_) => done = true,
          onError: (Object e, StackTrace _) => error = e,
        ),
      );
      async.flushMicrotasks();
      expect(error, isNull);
      expect(done, isTrue);
    }

    test('init attaches with the minimum window size before restoring', () {
      fakeAsync((async) {
        final service = WindowService(host: host);
        initNow(service, async);
        expect(host.calls.first, 'attach');
        expect(host.minimumSize, minimumWindowSize);
        expect(host.isAttached, isTrue);
        // 首会话无位置 → setSize + center（平台居中）。
        expect(host.calls, containsAllInOrder(['setSize', 'center']));
        service.dispose();
        expect(host.isAttached, isFalse);
      });
    });

    test('persisted maximized state is applied while hidden, before show', () {
      fakeAsync((async) {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'isMaximized': true,
        });
        final service = WindowService(host: host);
        initNow(service, async);
        expect(service.mode.value, WindowMode.maximized);
        expect(host.calls, contains('maximize'));
        expect(host.calls, isNot(contains('show')));
        unawaited(service.reveal());
        async.flushMicrotasks();
        expect(
          host.calls.indexOf('maximize'),
          lessThan(host.calls.indexOf('show')),
        );
        service.dispose();
      });
    });

    test('attach failure surfaces from init and leaves no listener', () {
      fakeAsync((async) {
        host.failAttach = true;
        final service = WindowService(host: host);
        Object? error;
        unawaited(service.init().catchError((Object e) => error = e));
        async.flushMicrotasks();
        expect(error, isA<Exception>());
        expect(host.isAttached, isFalse);
        // 降级亮窗在未绑定时不触碰宿主。
        unawaited(service.showDegraded());
        async.flushMicrotasks();
        expect(host.calls, isNot(contains('show')));
        service.dispose();
      });
    });

    test('maximized / restored events drive mode (restore re-queries)', () {
      fakeAsync((async) {
        final service = WindowService(host: host);
        initNow(service, async);
        host.emit(const NativeWindowMaximized());
        async.flushMicrotasks();
        expect(service.mode.value, WindowMode.maximized);

        // 最大化窗口最小化后恢复: 平台只报 restored, 宿主仍最大化。
        host.maximized = true;
        host.emit(const NativeWindowRestored());
        async.flushMicrotasks();
        expect(service.mode.value, WindowMode.maximized);

        host.maximized = false;
        host.emit(const NativeWindowRestored());
        async.flushMicrotasks();
        expect(service.mode.value, WindowMode.windowed);
        service.dispose();
      });
    });

    test('resize event starts a resize session', () {
      fakeAsync((async) {
        final service = WindowService(host: host);
        initNow(service, async);
        unawaited(service.reveal()); // 解除 init 抑制
        async.flushMicrotasks();
        host.size = const Size(1500, 800);
        host.emit(const NativeWindowResized());
        expect(service.isResizing.value, isTrue);
        async.elapse(const Duration(milliseconds: 600));
        expect(service.isResizing.value, isFalse);
        expect(service.windowSize.value, const Size(1500, 800));
        service.dispose();
      });
    });

    test('close request event runs the persist-then-exit path once', () {
      fakeAsync((async) {
        final exitCodes = <int>[];
        final service = WindowService(host: host, exitOnClose: exitCodes.add);
        initNow(service, async);
        host.emit(const NativeWindowCloseRequested());
        host.emit(const NativeWindowCloseRequested()); // 重复请求被忽略
        async.elapse(const Duration(seconds: 5));
        expect(host.calls.where((c) => c == 'hide'), hasLength(1));
        expect(host.calls, contains('destroy'));
        expect(exitCodes, [0]);
      });
    });

    test('fullscreen mode switches go through host.setFullScreen', () {
      fakeAsync((async) {
        final service = WindowService(host: host);
        initNow(service, async);
        unawaited(service.setMode(WindowMode.fullscreen));
        async.flushMicrotasks();
        expect(host.calls, contains('setFullScreen:true'));
        unawaited(service.setMode(WindowMode.windowed));
        async.flushMicrotasks();
        expect(host.calls, contains('setFullScreen:false'));
        expect(service.mode.value, WindowMode.windowed);

        // 最大化进入全屏: 原生退出恢复最大化 → 模式回到 maximized。
        host.maximized = true;
        unawaited(service.setMode(WindowMode.fullscreen));
        async.flushMicrotasks();
        unawaited(service.setMode(WindowMode.windowed));
        async.flushMicrotasks();
        expect(service.mode.value, WindowMode.maximized);
        service.dispose();
      });
    });

    test('always-on-top, minimize and dragging delegate to the host', () {
      fakeAsync((async) {
        final service = WindowService(host: host);
        initNow(service, async);
        unawaited(service.setAlwaysOnTop(true));
        unawaited(service.minimize());
        unawaited(service.startDragging());
        async.flushMicrotasks();
        expect(service.isAlwaysOnTop.value, isTrue);
        expect(
          host.calls,
          containsAll(['setAlwaysOnTop:true', 'minimize', 'startDragging']),
        );
        service.dispose();
      });
    });
  });
}
