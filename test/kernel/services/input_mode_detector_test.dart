// input_mode_detector_test.dart — Phase 32 Task 1 (NAV-02/NAV-03/NAV-06) 单元测试。
//
// 13 个 fakeAsync 行为覆盖 InputModeDetector 启发式状态机：鼠标 hover、idle+arrow、
// 手动 toggle 持久 (D-03)、dispose 取消计时器、touch 过滤、辉光生命周期、面板关闭取消。
//
// 全部用隔离的 InputModeDetector.forTest(...) 实例 + 注入 fakeAsync clock ——
// fakeAsync 推进 Timer 实例但不推进 DateTime.now，故 clock 注入使时间戳与伪调度器
// 同步推进。永不 dispose 进程级 InputModeDetector.instance（保留给生产 + Plan 02）。
// 依赖 fake_async（flutter_test 的传递依赖，测试文件直接导入；非生产依赖，不新增包）。

library;

import 'package:fake_async/fake_async.dart'; // ignore: depend_on_referenced_packages
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/services/input_mode_detector.dart';

/// 构造隔离的 [InputModeDetector.forTest] 实例 —— idleTimeout 5s、glowReset 100ms、
/// clock 取自 [FakeAsync.getClock]（与伪调度器同步推进，fakeAsync 不推进 DateTime.now）。
InputModeDetector _detector(FakeAsync async) {
  final clock = async.getClock(DateTime(2020));
  return InputModeDetector.forTest(
    idleTimeout: const Duration(seconds: 5),
    glowResetDuration: const Duration(milliseconds: 100),
    clock: clock.now,
  );
}

/// 鼠标 hover 事件（kind=mouse）。
PointerHoverEvent _mouseHover() =>
    const PointerHoverEvent(kind: PointerDeviceKind.mouse);

/// 触摸 hover 事件（kind=touch，用于 D-02 鼠标过滤测试）。
PointerHoverEvent _touchHover() =>
    const PointerHoverEvent(kind: PointerDeviceKind.touch);

void main() {
  group('InputModeDetector', () {
    // ── Test 1: hover → keyboard (preference auto) ──
    test('Test 1: mouse hover under auto → effectiveMode keyboard', () {
      fakeAsync((async) {
        final d = _detector(async);
        d.recordPointerActivity(_mouseHover());
        expect(d.effectiveMode.value, InputMode.keyboard);
        d.dispose();
      });
    });

    // ── Test 2: 5s idle + arrow → gamepad (preference auto) ──
    test('Test 2: idle + arrow under auto → effectiveMode gamepad', () {
      fakeAsync((async) {
        final d = _detector(async);
        d.recordArrowKey(); // 无鼠标活动 → lastMouseActivity=null → 视为空闲倾向 gamepad
        async.elapse(const Duration(seconds: 5));
        expect(d.effectiveMode.value, InputMode.gamepad);
        d.dispose();
      });
    });

    // ── Test 3: manual toggle keyboard persists across heuristic signals (D-03) ──
    test('Test 3: toggle keyboard persists across hover + idle+arrow', () {
      fakeAsync((async) {
        final d = _detector(async);
        d.toggle(InputMode.keyboard); // preference=keyboard，显式选择
        d.recordPointerActivity(_mouseHover()); // D-03: preference!=auto → 不覆盖
        d.recordArrowKey();
        async.elapse(const Duration(seconds: 5)); // 计时器触发但 D-03 保留 keyboard
        expect(d.effectiveMode.value, InputMode.keyboard);
        d.dispose();
      });
    });

    // ── Test 4: toggle auto re-engages heuristic (hover→keyboard) ──
    test('Test 4: toggle auto re-engages heuristic (hover→keyboard)', () {
      fakeAsync((async) {
        final d = _detector(async);
        d.toggle(InputMode.gamepad); // 显式 gamepad —— heuristic 此前被覆盖
        expect(d.effectiveMode.value, InputMode.gamepad);
        d.toggle(InputMode.auto); // 重新启用启发式（baseline keyboard + 取消计时器）
        expect(d.effectiveMode.value, InputMode.keyboard);
        d.recordPointerActivity(_mouseHover()); // 鼠标信号现在能影响 effectiveMode
        expect(d.effectiveMode.value, InputMode.keyboard);
        d.dispose();
      });
    });

    // ── Test 5: dispose cancels pending gamepad timer (no post-dispose fire, T-32-02) ──
    test('Test 5: dispose cancels pending 5s gamepad timer', () {
      fakeAsync((async) {
        final d = _detector(async);
        d.recordArrowKey(); // 启动 5s 计时器
        d.dispose(); // 取消计时器 + dispose 三个 ValueNotifier
        // 若计时器未取消，触发时会调用 effectiveMode 的 setter on disposed → assert throw
        async.elapse(const Duration(seconds: 10));
        // .value 读取 dispose 后安全（只有 setter/notifyListeners 断言）
        expect(d.effectiveMode.value, InputMode.keyboard);
      });
    });

    // ── Test 6: touch filtered (mouse-only, D-02) ──
    test('Test 6: recordPointerActivity kind=touch does NOT change mode', () {
      fakeAsync((async) {
        final d = _detector(async);
        // 先 idle+arrow → gamepad，证明 touch 不会把它重置回 keyboard
        d.recordArrowKey();
        async.elapse(const Duration(seconds: 5));
        expect(d.effectiveMode.value, InputMode.gamepad);
        d.recordPointerActivity(_touchHover()); // D-02: kind!=mouse → 过滤，无操作
        expect(d.effectiveMode.value, InputMode.gamepad); // 不变
        d.dispose();
      });
    });

    // ── Test 7: D-03 gamepad persists across mouse ──
    test('Test 7: toggle gamepad persists across mouse hover (D-03)', () {
      fakeAsync((async) {
        final d = _detector(async);
        d.toggle(InputMode.gamepad);
        d.recordPointerActivity(_mouseHover()); // preference!=auto → 不覆盖
        expect(d.effectiveMode.value, InputMode.gamepad);
        d.dispose();
      });
    });

    // ── Test 8: D-03 keyboard persists across timer ──
    test('Test 8: toggle keyboard persists across idle+arrow timer (D-03)', () {
      fakeAsync((async) {
        final d = _detector(async);
        d.toggle(InputMode.keyboard);
        d.recordArrowKey();
        async.elapse(const Duration(seconds: 5)); // 计时器触发但 preference!=auto → 不翻 gamepad
        expect(d.effectiveMode.value, InputMode.keyboard);
        d.dispose();
      });
    });

    // ── Test 9: recordArrowKey schedules + refreshes the 5s timer (NAV-02) ──
    // 注：检测器的 recordArrowKey 无方向参数；up/down/left/right 的接线由
    // panel_key_bindings.handle() 负责（Task 2 containment spy 验证四向遏制）。
    // 此处验证 recordArrowKey 调度并刷新同一个 5s 检测计时器 (NAV-02 启发式契约)。
    test('Test 9: recordArrowKey schedules + refreshes 5s detection timer', () {
      fakeAsync((async) {
        final d = _detector(async);
        d.recordArrowKey(); // t=0: 计时器 A 于 t=5s 触发
        async.elapse(const Duration(seconds: 3)); // t=3s: 未到 5s
        expect(d.effectiveMode.value, InputMode.keyboard);
        d.recordArrowKey(); // t=3s: 取消 A，计时器 B 于 t=8s 触发（刷新窗口）
        async.elapse(const Duration(seconds: 3)); // t=6s: B 未触发（若未刷新，A 应在 t=5s 已触发→gamepad）
        expect(d.effectiveMode.value, InputMode.keyboard);
        async.elapse(const Duration(seconds: 2)); // t=8s: B 触发 → gamepad
        expect(d.effectiveMode.value, InputMode.gamepad);
        d.dispose();
      });
    });

    // ── Test 10: glow successive-press replacement (no stacking, NAV-06) ──
    test('Test 10: two rapid setArrowGlow calls replace (no stacking)', () {
      fakeAsync((async) {
        final d = _detector(async);
        d.setArrowGlow(ArrowDirection.up); // t=0: glow=up, reset1 于 t=100ms→null
        async.elapse(const Duration(milliseconds: 50)); // t=50ms
        d.setArrowGlow(ArrowDirection.down); // t=50: 取消 reset1, glow=down, reset2 于 t=150ms→null
        async.elapse(const Duration(milliseconds: 50)); // t=100: 若 reset1 未取消应→null；取消则仍 down
        expect(d.arrowGlow.value, ArrowDirection.down); // 证明替换（非堆叠）
        async.elapse(const Duration(milliseconds: 50)); // t=150: reset2 触发→null
        expect(d.arrowGlow.value, null);
        d.dispose();
      });
    });

    // ── Test 11: glow auto-expiry to null (NAV-06) ──
    test('Test 11: setArrowGlow auto-expires to null after duration', () {
      fakeAsync((async) {
        final d = _detector(async);
        d.setArrowGlow(ArrowDirection.up);
        expect(d.arrowGlow.value, ArrowDirection.up);
        async.elapse(const Duration(milliseconds: 100));
        expect(d.arrowGlow.value, null);
        d.dispose();
      });
    });

    // ── Test 12: dispose cancels in-flight glow-reset timer (T-32-02) ──
    test('Test 12: dispose cancels in-flight glow-reset timer', () {
      fakeAsync((async) {
        final d = _detector(async);
        d.setArrowGlow(ArrowDirection.up); // glow=up + reset 计时器
        d.dispose(); // 取消 reset 计时器 + dispose arrowGlow
        // 若未取消，reset 触发时 setter on disposed → assert throw
        async.elapse(const Duration(milliseconds: 200));
        expect(d.arrowGlow.value, ArrowDirection.up); // .value 读取 dispose 后安全，值不变
      });
    });

    // ── Test 13: panel-close cancels pending timer + resets glow (T-32-06) ──
    test('Test 13: onPanelClosed cancels timer + resets glow (no late flip)', () {
      fakeAsync((async) {
        final d = _detector(async);
        d.recordArrowKey(); // 启动 5s 计时器
        d.onPanelClosed(); // 取消两计时器 + arrowGlow=null，但不 dispose
        // 若未取消，5s 后计时器触发翻 effectiveMode→gamepad
        async.elapse(const Duration(seconds: 10));
        expect(d.effectiveMode.value, InputMode.keyboard); // 不翻转
        expect(d.arrowGlow.value, null); // 已重置
        d.dispose();
      });
    });
  });
}
