import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/persistence/window_persistence.dart';
import 'package:simple_player_flutter/kernel/window_bridge/native_window.dart';
import 'package:simple_player_flutter/kernel/window_bridge/window_geometry.dart';
import 'package:simple_player_flutter/kernel/window_bridge/window_service.dart';

import '../../../helpers/fake_native_window.dart';

/// 持久化快照 key（与 WindowPersistence 内部一致，仅测试直读用）。
const _snapshotKey = 'windowSnapshot';

void main() {
  setUpAll(() {
    // 诊断单例测试惯例: 先复位再 init。
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  late FakeNativeWindow window;
  late SharedPreferences preferences;
  late List<int> exitCodes;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    window = FakeNativeWindow();
    exitCodes = <int>[];
  });

  WindowService createService({bool dropDwmFrame = false}) => WindowService(
    persistence: WindowPersistence(preferences: preferences),
    bindWindow: () => window,
    exitOnClose: exitCodes.add,
    dropDwmFrame: dropDwmFrame,
  );

  Map<String, dynamic> savedSnapshot() {
    final raw = preferences.getString(_snapshotKey);
    expect(raw, isNotNull, reason: 'a snapshot should have been persisted');
    return jsonDecode(raw!) as Map<String, dynamic>;
  }

  Future<void> seed(PersistedWindowState state) =>
      WindowPersistence(preferences: preferences).save(state);

  /// 初始化并亮窗 — 多数用例的公共前置。
  Future<WindowService> startedService({bool dropDwmFrame = false}) async {
    final service = createService(dropDwmFrame: dropDwmFrame);
    await service.init();
    await service.reveal();
    return service;
  }

  /// 在 fakeAsync zone 内启动服务。事件订阅的回调运行在订阅时的 zone，
  /// 依赖假时钟的用例（防抖/超时）必须让 init 也发生在 fakeAsync 内，
  /// 否则服务里创建的 Timer 是真实计时器。
  WindowService startInZone(FakeAsync async) {
    late WindowService service;
    unawaited(startedService().then((started) => service = started));
    async.flushMicrotasks();
    return service;
  }

  group('init', () {
    test('configures the frame before restoring geometry', () async {
      final service = createService();
      addTearDown(service.dispose);

      await service.init();

      expect(window.calls.first, 'hideTitleBar');
      expect(window.minimumSizeValue, minimumWindowSize);
      expect(window.shadowValue, isNull);
    });

    test(
      'drops the DWM frame before hiding the title bar on Windows 10',
      () async {
        final service = createService(dropDwmFrame: true);
        addTearDown(service.dispose);

        await service.init();

        expect(window.calls.take(2), ['hasShadow=false', 'hideTitleBar']);
      },
    );

    test('restores reachable persisted bounds and always-on-top', () async {
      await seed(
        const PersistedWindowState(
          size: Size(1000, 600),
          position: Offset(200, 150),
          alwaysOnTop: true,
          isMaximized: false,
        ),
      );
      final service = createService();
      addTearDown(service.dispose);

      await service.init();

      expect(window.boundsValue, const Rect.fromLTWH(200, 150, 1000, 600));
      expect(window.alwaysOnTop, isTrue);
      expect(service.isAlwaysOnTop.value, isTrue);
      expect(service.mode.value, WindowMode.windowed);
    });

    test(
      'centers when the persisted position is on an unplugged display',
      () async {
        await seed(
          const PersistedWindowState(
            size: Size(1000, 600),
            position: Offset(2500, 150),
            alwaysOnTop: false,
            isMaximized: false,
          ),
        );
        final service = createService();
        addTearDown(service.dispose);

        await service.init();

        expect(window.calls.any((c) => c.startsWith('bounds=')), isFalse);
        expect(
          window.calls,
          containsAllInOrder(['setSize=Size(1000.0, 600.0)', 'center']),
        );
      },
    );

    test(
      'keeps the persisted position when work areas are unavailable',
      () async {
        await seed(
          const PersistedWindowState(
            size: Size(1000, 600),
            position: Offset(2500, 150),
            alwaysOnTop: false,
            isMaximized: false,
          ),
        );
        window.workAreasError = Exception('no display info');
        final service = createService();
        addTearDown(service.dispose);

        await service.init();

        expect(window.boundsValue, const Rect.fromLTWH(2500, 150, 1000, 600));
      },
    );

    test('centers on first launch without a stored position', () async {
      final service = createService();
      addTearDown(service.dispose);

      await service.init();

      expect(
        window.calls,
        containsAllInOrder(['setSize=$defaultWindowSize', 'center']),
      );
    });

    test('restores the maximized state hidden, before reveal', () async {
      await seed(
        const PersistedWindowState(
          size: Size(1000, 600),
          position: Offset(200, 150),
          alwaysOnTop: false,
          isMaximized: true,
        ),
      );
      final service = createService();
      addTearDown(service.dispose);

      await service.init();

      expect(window.calls, contains('maximize'));
      expect(window.calls, isNot(contains('show')));
      expect(service.mode.value, WindowMode.maximized);
    });

    test('can be retried after a failed bind', () async {
      var attempts = 0;
      final service = WindowService(
        persistence: WindowPersistence(preferences: preferences),
        bindWindow: () {
          attempts++;
          if (attempts == 1) throw StateError('host window not found');
          return window;
        },
        exitOnClose: exitCodes.add,
        dropDwmFrame: false,
      );
      addTearDown(service.dispose);

      await expectLater(service.init(), throwsStateError);
      await service.init();

      expect(attempts, 2);
    });
  });

  group('init lifecycle', () {
    test('a retry after a mid-init failure reuses the bound window', () async {
      var binds = 0;
      window.hideTitleBarError = StateError('frame update failed');
      final service = WindowService(
        persistence: WindowPersistence(preferences: preferences),
        bindWindow: () {
          binds++;
          return window;
        },
        exitOnClose: exitCodes.add,
        dropDwmFrame: false,
      );
      addTearDown(service.dispose);

      await expectLater(service.init(), throwsStateError);
      window.hideTitleBarError = null;
      await service.init();
      await service.reveal();

      expect(binds, 1);
      // 事件订阅只挂一次：一次最大化事件只让 mode 更新一次。
      var changes = 0;
      service.mode.addListener(() => changes++);
      window.completeMaximize();
      expect(changes, 1);
    });

    test('dispose during init does not touch the window afterwards', () async {
      final service = createService();

      final init = service.init();
      service.dispose();
      await init;

      expect(window.calls.any((c) => c.startsWith('bounds=')), isFalse);
      expect(window.calls.any((c) => c.startsWith('setSize=')), isFalse);
    });
  });

  group('reveal', () {
    test('shows then focuses the window', () async {
      final service = createService();
      addTearDown(service.dispose);
      await service.init();

      await service.reveal();

      expect(window.calls.skipWhile((c) => c != 'show').take(2), [
        'show',
        'focus',
      ]);
    });

    test('showDegraded is a no-op before the window is bound', () async {
      final service = createService();
      addTearDown(service.dispose);

      await service.showDegraded();

      expect(window.calls, isEmpty);
    });
  });

  group('mode', () {
    test('native maximize and restore events drive mode', () async {
      final service = await startedService();
      addTearDown(service.dispose);

      window.completeMaximize();
      expect(service.mode.value, WindowMode.maximized);

      window.completeUnmaximize();
      expect(service.mode.value, WindowMode.windowed);
    });

    test(
      'restore keeps maximized when the window is still maximized',
      () async {
        final service = await startedService();
        addTearDown(service.dispose);
        window.completeMaximize();

        // 最大化窗口最小化后恢复只报 restored，宿主仍是最大化。
        window.emit(const NativeRestored());

        expect(service.mode.value, WindowMode.maximized);
      },
    );

    test('entering fullscreen sets the intent and the native flag', () async {
      final service = await startedService();
      addTearDown(service.dispose);

      await service.setMode(WindowMode.fullscreen);

      expect(service.mode.value, WindowMode.fullscreen);
      expect(window.fullScreen, isTrue);
    });

    test(
      'native maximize during fullscreen does not downgrade the mode',
      () async {
        final service = await startedService();
        addTearDown(service.dispose);
        await service.setMode(WindowMode.fullscreen);

        window.completeMaximize();

        expect(service.mode.value, WindowMode.fullscreen);
      },
    );

    test('leaving fullscreen returns to windowed', () async {
      final service = await startedService();
      addTearDown(service.dispose);
      await service.setMode(WindowMode.fullscreen);

      await service.setMode(WindowMode.windowed);

      expect(window.fullScreen, isFalse);
      expect(service.mode.value, WindowMode.windowed);
    });

    test(
      'leaving fullscreen falls back to maximized when the host is maximized',
      () async {
        final service = await startedService();
        addTearDown(service.dispose);
        window.completeMaximize();
        await service.setMode(WindowMode.fullscreen);

        await service.setMode(WindowMode.windowed);

        expect(service.mode.value, WindowMode.maximized);
      },
    );

    test(
      'setMode(maximized) returns only after the native event arrives',
      () async {
        final service = await startedService();
        addTearDown(service.dispose);
        window.deferSettling = true;

        var done = false;
        unawaited(
          service.setMode(WindowMode.maximized).then((_) => done = true),
        );
        await pumpEventQueue();
        expect(done, isFalse);

        window.completeMaximize();
        await pumpEventQueue();
        expect(done, isTrue);
        expect(service.mode.value, WindowMode.maximized);
      },
    );

    test('setMode gives up waiting after the settle timeout', () {
      fakeAsync((async) {
        final service = startInZone(async);
        window.deferSettling = true;

        var done = false;
        unawaited(
          service.setMode(WindowMode.maximized).then((_) => done = true),
        );
        async.flushMicrotasks();
        // 事件从未到达 — 超时前仍在等待。
        async.elapse(const Duration(milliseconds: 900));
        expect(done, isFalse);

        async.elapse(const Duration(milliseconds: 200));
        async.flushMicrotasks();
        expect(done, isTrue);
        service.dispose();
      });
    });

    test('dispose while waiting for a state change returns promptly', () async {
      final service = await startedService();
      window.deferSettling = true;

      var done = false;
      unawaited(service.setMode(WindowMode.maximized).then((_) => done = true));
      await pumpEventQueue();
      expect(done, isFalse);

      service.dispose();
      await pumpEventQueue();

      // 事件流关闭即放行，不必白等满 1s 超时。
      expect(done, isTrue);
    });

    test('minimize waits for the minimized event', () async {
      final service = await startedService();
      addTearDown(service.dispose);

      await service.minimize();

      expect(window.minimized, isTrue);
    });
  });

  group('resize session', () {
    test('events before reveal are ignored', () async {
      final service = createService();
      addTearDown(service.dispose);
      await service.init();

      window.emit(const NativeResized());

      expect(service.isResizing.value, isFalse);
      expect(service.resizeSessionId.value, 0);
    });

    test('debounces into one session and bumps the id per session', () {
      fakeAsync((async) {
        final service = startInZone(async);

        window.emit(const NativeResized());
        async.elapse(const Duration(milliseconds: 100));
        window.emit(const NativeResized());
        async.elapse(const Duration(milliseconds: 100));
        window.emit(const NativeResized());

        expect(service.isResizing.value, isTrue);
        expect(service.resizeSessionId.value, 1);

        async.elapse(const Duration(milliseconds: 499));
        expect(service.isResizing.value, isTrue);
        async.elapse(const Duration(milliseconds: 2));
        expect(service.isResizing.value, isFalse);

        window.emit(const NativeResized());
        expect(service.resizeSessionId.value, 2);
        async.elapse(const Duration(seconds: 1));
        service.dispose();
      });
    });

    // SharedPreferences 的内存缓存在 setString 时同步更新、写盘 Future 另行
    // 完成 — 持久化断言须在 fakeAsync 内读缓存（zone 外 await 落盘 Future
    // 会因续体困在假时钟里而永远不返回）。
    test('a settled resize persists the new geometry', () {
      fakeAsync((async) {
        final service = startInZone(async);
        window.boundsValue = const Rect.fromLTWH(50, 60, 1100, 650);

        window.emit(const NativeResized());
        async.elapse(const Duration(milliseconds: 600));
        async.flushMicrotasks();

        final saved = savedSnapshot();
        expect(saved['width'], 1100);
        expect(saved['height'], 650);
        expect(saved['x'], 50);
        expect(saved['y'], 60);
        service.dispose();
      });
    });

    test('a resize during fullscreen settles without persisting', () {
      fakeAsync((async) {
        final service = startInZone(async);
        unawaited(service.setMode(WindowMode.fullscreen));
        async.flushMicrotasks();

        window.emit(const NativeResized());
        expect(service.isResizing.value, isTrue);
        async.elapse(const Duration(milliseconds: 600));
        async.flushMicrotasks();
        expect(service.isResizing.value, isFalse);
        expect(preferences.getString(_snapshotKey), isNull);

        // 对照：退出全屏后同样的 resize 会落盘 — 证明上面的 null 不是落盘
        // 链路根本没跑。
        unawaited(service.setMode(WindowMode.windowed));
        async.flushMicrotasks();
        window.emit(const NativeResized());
        async.elapse(const Duration(milliseconds: 600));
        async.flushMicrotasks();
        expect(preferences.getString(_snapshotKey), isNotNull);
        service.dispose();
      });
    });
  });

  group('persistence', () {
    test('maximizing does not overwrite the restore size', () async {
      final service = await startedService();
      addTearDown(service.dispose);
      window.boundsValue = const Rect.fromLTWH(70, 80, 1000, 600);
      window.emit(const NativeResized());

      // 最大化: bounds 变成工作区，先 resize 事件、后 maximized 事件。
      window.maximized = true;
      window.boundsValue = window.workAreasValue.first;
      window.emit(const NativeResized());
      window.emit(const NativeMaximized());
      await service.close();

      final saved = savedSnapshot();
      expect(saved['isMaximized'], isTrue);
      expect(saved['width'], 1000);
      expect(saved['height'], 600);
      expect(saved['x'], 70);
      expect(saved['y'], 80);
    });

    test('minimized off-screen coordinates are not recorded', () async {
      final service = await startedService();
      addTearDown(service.dispose);
      window.boundsValue = const Rect.fromLTWH(70, 80, 1000, 600);
      window.emit(const NativeMoved());

      window.minimized = true;
      window.boundsValue = const Rect.fromLTWH(-32000, -32000, 160, 28);
      window.emit(const NativeMoved());
      await service.close();

      expect(savedSnapshot()['x'], 70);
    });

    test('sizes below the minimum are clamped up when saving', () async {
      final service = await startedService();
      addTearDown(service.dispose);
      window.boundsValue = const Rect.fromLTWH(10, 10, 300, 200);
      window.emit(const NativeResized());

      await service.close();

      expect(savedSnapshot()['width'], minimumWindowSize.width);
      expect(savedSnapshot()['height'], minimumWindowSize.height);
    });

    test('toggling always-on-top persists the choice', () async {
      final service = await startedService();
      addTearDown(service.dispose);

      await service.setAlwaysOnTop(true);
      await service.pendingPersist;

      expect(window.alwaysOnTop, isTrue);
      expect(savedSnapshot()['alwaysOnTop'], isTrue);
    });

    test(
      'always-on-top applies but does not persist while fullscreen',
      () async {
        final service = await startedService();
        addTearDown(service.dispose);
        await service.setMode(WindowMode.fullscreen);

        await service.setAlwaysOnTop(true);
        await service.pendingPersist;

        expect(window.alwaysOnTop, isTrue);
        expect(preferences.getString(_snapshotKey), isNull);
      },
    );

    test('fullscreen never persists geometry', () async {
      final service = await startedService();
      addTearDown(service.dispose);
      await service.setMode(WindowMode.fullscreen);

      await service.close();

      expect(preferences.getString(_snapshotKey), isNull);
    });
  });

  group('close sequence', () {
    test('runs hide, persist, listeners, then exits once', () async {
      final service = await startedService();
      // 在监听器里抓取此刻的状态：hide 已执行、快照已落盘、尚未 exit。
      final seen = <String, Object?>{};
      service.addClosingListener(() async {
        seen['hiddenFirst'] = window.calls.last == 'hide';
        seen['persisted'] = preferences.getString(_snapshotKey) != null;
        seen['exitedYet'] = exitCodes.isNotEmpty;
      });

      await service.close();

      expect(seen, {
        'hiddenFirst': true,
        'persisted': true,
        'exitedYet': false,
      });
      expect(exitCodes, [0]);
    });

    test('concurrent triggers share one execution', () async {
      final service = await startedService();
      var listenerRuns = 0;
      service.addClosingListener(() async => listenerRuns++);

      // ✕ 连点 + 外部关闭请求，全部发生在序列完成之前。
      final first = service.close();
      window.requestClose();
      final second = service.close();
      await Future.wait([first, second]);

      expect(listenerRuns, 1);
      expect(exitCodes, [0]);
    });

    test('cancels the default close synchronously inside the event', () async {
      final service = await startedService();
      addTearDown(service.dispose);

      final cancelled = window.requestClose();
      await service.closeOperation;

      expect(cancelled, isTrue);
      expect(exitCodes, [0]);
    });

    test('a forced close that cannot be cancelled still shuts down', () async {
      final service = await startedService();
      addTearDown(service.dispose);

      window.requestClose(cancelable: false);
      await service.closeOperation;

      expect(exitCodes, [0]);
    });

    test('a failing listener does not block exit', () async {
      final service = await startedService();
      var secondRan = false;
      service.addClosingListener(() async => throw StateError('boom'));
      service.addClosingListener(() async => secondRan = true);

      await service.close();

      expect(secondRan, isTrue);
      expect(exitCodes, [0]);
    });

    test('a hung listener is abandoned after the step timeout', () {
      fakeAsync((async) {
        final service = startInZone(async);
        service.addClosingListener(() => Completer<void>().future);

        unawaited(service.close());
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 700));
        expect(exitCodes, isEmpty);

        async.elapse(const Duration(milliseconds: 200));
        async.flushMicrotasks();
        expect(exitCodes, [0]);
      });
    });

    test('removing a closing listener is idempotent', () async {
      final service = await startedService();
      var runs = 0;
      final remove = service.addClosingListener(() async => runs++);
      remove();
      remove();

      await service.close();

      expect(runs, 0);
    });
  });

  group('title bar actions', () {
    test('forward to the native window', () async {
      final service = await startedService();
      addTearDown(service.dispose);

      await service.startDragging();
      service.titleBarDoubleClick();

      expect(window.calls.skipWhile((c) => c != 'startDragging'), [
        'startDragging',
        'titleBarDoubleClick',
      ]);
    });

    test('are no-ops after dispose', () async {
      final service = await startedService();
      service.dispose();
      window.calls.clear();

      await service.startDragging();
      service.titleBarDoubleClick();

      expect(window.calls, isEmpty);
    });
  });

  group('degraded mode (init never ran)', () {
    test('gestures and commands are silent no-ops', () async {
      final service = createService();
      addTearDown(service.dispose);

      await service.startDragging();
      service.titleBarDoubleClick();
      await service.minimize();
      await service.setMode(WindowMode.maximized);
      await service.setAlwaysOnTop(true);

      expect(window.calls, isEmpty);
    });

    test('close still persists nothing but exits', () async {
      final service = createService();

      await service.close();

      expect(exitCodes, [0]);
    });
  });

  test('dispose is idempotent and releases the native window', () async {
    final service = await startedService();

    service.dispose();
    service.dispose();

    expect(window.disposed, isTrue);
  });
}
