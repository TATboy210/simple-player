// input_mode_detector.dart — Phase 32 NAV-02/NAV-06 唯一新基础设施。
//
// 职责：在设置面板内区分 keyboard / gamepad 输入模式，供 UI 决定是否显示方向
// 键辉光 (NAV-06) 与后续 plan 的布局适配。启发式采用 "鼠标空闲 + 方向键出现"
// 信号 —— Steam Input 注入的键盘箭头在 Flutter 层失去 controller provenance
// (D-01: key event 本身无法区分来源)，故只能用鼠标空闲 + 箭头出现启发式推断。
//
// 状态机要点 (D-03 split)：preference ∈ {keyboard, gamepad, auto}；effectiveMode
// 永不取 auto —— auto 仅作 preference，派生 effective 只有 keyboard/gamepad 两态。
// 鼠标/箭头计时器仅在 preference==auto 时允许变更 effectiveMode，保护显式选择。

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

import '../../ui/theme/tokens.dart';

/// 用户输入模式偏好 (D-03)。
///
/// - [keyboard] / [gamepad]: 用户显式选择，持久到用户再次选 [auto]。
/// - [auto]: 启发式驱动（鼠标空闲 + 箭头计时器自动切换 keyboard/gamepad）。
///
/// 注意：[InputModeDetector.effectiveMode] 永不取 [auto] —— auto 仅作 preference，
/// 派生有效模式只有 keyboard / gamepad 两态 (D-03 split)。
enum InputMode {
  keyboard,
  gamepad,
  auto,
}

/// 方向键辉光方向 (NAV-06)，由上下箭头经 [InputModeDetector.setArrowGlow] 设置，
/// 供 Plan 03 的 OptionListNavigationOverlay 消费。
enum ArrowDirection {
  up,
  down,
}

/// 输入模式检测器 —— singleton，持有三个 [ValueNotifier]：[preference] /
/// [effectiveMode] / [arrowGlow]。
///
/// 启发式（仅当 [preference] == [InputMode.auto] 时生效，D-03 保留显式选择）：
/// - 鼠标 hover ([recordPointerActivity]) → 立即 [InputMode.keyboard] + 取消
///   待触发的 gamepad 计时器。
/// - 方向键 ([recordArrowKey]) → 启动/刷新 5s 计时器；触发时若鼠标空闲超过阈值
///   → [InputMode.gamepad] (D-01: 不查 physicalKey/deviceType)。
///
/// 时间源注入：[DateTime Function] clock 默认 [DateTime.now]。测试注入
/// `fakeAsync.getClock(...).now` 使 clock 与 fake timer 同步推进 —— fakeAsync
/// 推进 [Timer] 实例但不推进 [DateTime.now]，故所有时间戳必须读注入的 [_clock]
/// 而非 [DateTime.now]，否则 idle 比较永不前进 (PLAN acceptance: injected clock)。
class InputModeDetector {
  InputModeDetector._({
    required Duration idleTimeout,
    required Duration glowResetDuration,
    required DateTime Function() clock,
  })  : _idleTimeout = idleTimeout,
        _glowResetDuration = glowResetDuration,
        _clock = clock;

  // ── singleton ──
  static InputModeDetector? _instance;

  /// 进程级单例 —— 懒构造，默认用 [Tokens] 驱动的超时 (D-06: 无硬编码) 与
  /// [DateTime.now] clock。
  static InputModeDetector get instance {
    final existing = _instance;
    if (existing != null) return existing;
    final created = InputModeDetector._(
      idleTimeout: const Duration(seconds: Tokens.inputModeIdleTimeoutSec),
      glowResetDuration: const Duration(milliseconds: Tokens.arrowGlowDuration),
      clock: DateTime.now,
    );
    _instance = created;
    return created;
  }

  /// 测试专用：把单例重建到干净状态（setUp 调用，隔离测试间状态）。
  @visibleForTesting
  static void resetInstance() => _instance = null;

  /// 测试专用：构造隔离的非单例实例 —— 13 个行为测试（含 dispose/计时器测试）
  /// 都用它，永不 dispose 进程级 [instance]（否则后续测试无可用检测器）。
  @visibleForTesting
  factory InputModeDetector.forTest({
    required Duration idleTimeout,
    required Duration glowResetDuration,
    required DateTime Function() clock,
  }) =>
      InputModeDetector._(
        idleTimeout: idleTimeout,
        glowResetDuration: glowResetDuration,
        clock: clock,
      );

  // ── 注入配置 ──
  final Duration _idleTimeout;
  final Duration _glowResetDuration;
  final DateTime Function() _clock;

  // ── 状态 ValueNotifiers ──

  /// 用户偏好 (D-03)。默认 [InputMode.auto] —— 启发式驱动。
  final ValueNotifier<InputMode> preference =
      ValueNotifier<InputMode>(InputMode.auto);

  /// 派生有效模式 —— hints 读取此值，永不取 [InputMode.auto] (D-03 split)。
  final ValueNotifier<InputMode> effectiveMode =
      ValueNotifier<InputMode>(InputMode.keyboard);

  /// 方向辉光 (NAV-06)，上下箭头经 [setArrowGlow] 设置，Plan 03 overlay 消费。
  /// 默认 null —— 无辉光。
  final ValueNotifier<ArrowDirection?> arrowGlow =
      ValueNotifier<ArrowDirection?>(null);

  // ── 内部计时器与时间戳 ──
  DateTime? _lastMouseActivity;
  Timer? _gamepadDetectionTimer;
  Timer? _glowResetTimer;

  /// 记录指针活动 —— 仅鼠标 hover 有效 (D-02 mouse filter)。
  ///
  /// 仅当 [preference] == [InputMode.auto] (D-03) 时把 [effectiveMode] 置
  /// [InputMode.keyboard] 并取消待触发的 gamepad 计时器；显式 keyboard/gamepad
  /// 偏好不受鼠标影响。时间戳读 [_clock] 而非 [DateTime.now] —— 测试注入
  /// fakeAsync clock 使其与 fake timer 同步推进。
  void recordPointerActivity(PointerEvent event) {
    if (event.kind != PointerDeviceKind.mouse) return; // D-02: 仅鼠标
    _lastMouseActivity = _clock();
    if (preference.value != InputMode.auto) return; // D-03: 保留显式选择
    effectiveMode.value = InputMode.keyboard;
    _gamepadDetectionTimer?.cancel();
    _gamepadDetectionTimer = null;
  }

  /// 记录方向键 —— 启动/刷新 gamepad 检测计时器 (idleTimeout)。
  ///
  /// 计时器触发时比较 [_clock] 与 [_lastMouseActivity]：鼠标空闲超过阈值
  /// 且 [preference] == [InputMode.auto] (D-03) → 切 [InputMode.gamepad]。
  /// D-01: 不查 physicalKey / deviceType —— Steam Input 注入的键盘箭头在
  /// Flutter 层无可保留的 controller provenance，启发式只能依赖鼠标空闲信号。
  void recordArrowKey() {
    _gamepadDetectionTimer?.cancel();
    _gamepadDetectionTimer = Timer(_idleTimeout, _onGamepadDetectionFire);
  }

  /// gamepad 检测计时器回调 —— 鼠标空闲超阈值且 preference==auto 则切 gamepad。
  void _onGamepadDetectionFire() {
    final lastMouse = _lastMouseActivity;
    // D-01: 用注入 clock 比较鼠标空闲，不查 key source。null = 从无鼠标活动
    // —— 视为始终空闲（倾向 gamepad 检测）。
    final idle = lastMouse == null ||
        _clock().difference(lastMouse) >= _idleTimeout;
    if (!idle) return;
    if (preference.value != InputMode.auto) return; // D-03: 保留显式选择
    effectiveMode.value = InputMode.gamepad;
  }

  /// 设置方向辉光 (NAV-06) —— 取消在飞 reset 计时器、置方向、启新 reset 计时器。
  ///
  /// 连续按键替换而非堆叠 (Test 10) —— 新方向键取消在飞计时器并启新计时器，
  /// 任意时刻仅一个辉光活跃。计时器到期回 null。
  void setArrowGlow(ArrowDirection direction) {
    _glowResetTimer?.cancel();
    arrowGlow.value = direction;
    _glowResetTimer = Timer(_glowResetDuration, () {
      arrowGlow.value = null;
    });
  }

  /// 手动切换偏好 (D-03)。
  ///
  /// [InputMode.keyboard] / [InputMode.gamepad] → 直接置 [effectiveMode]
  /// （显式选择，后续 mouse/arrow 信号不再覆盖）。
  /// [InputMode.auto] → 重新启用启发式：回到 [InputMode.keyboard] 基线，
  /// 等下次鼠标/箭头信号驱动（取消在飞 gamepad 计时器避免残留翻转）。
  void toggle(InputMode mode) {
    preference.value = mode;
    if (mode == InputMode.auto) {
      _gamepadDetectionTimer?.cancel();
      _gamepadDetectionTimer = null;
      effectiveMode.value = InputMode.keyboard;
    } else {
      effectiveMode.value = mode;
    }
  }

  /// 面板关闭钩子 (T-32-06) —— 取消两个计时器 + 重置辉光，但不 dispose
  /// ValueNotifiers 或单例：检测器跨 open/close 存活，避免面板关闭后 5s 迟到的
  /// gamepad 检测翻转 [effectiveMode]（箭头在关闭前一刻按下、计时器在关闭后
  /// 触发的竞态）。Plan 02 在 isOpen→false 时调用此钩子。
  void onPanelClosed() {
    _gamepadDetectionTimer?.cancel();
    _gamepadDetectionTimer = null;
    _glowResetTimer?.cancel();
    _glowResetTimer = null;
    arrowGlow.value = null;
  }

  /// 端生命周期销毁 —— 取消两计时器 + dispose 三个 ValueNotifier
  /// (T-32-02: dispose 后计时器不再触发，无 use-after-dispose DoS)。
  /// 仅用于隔离测试实例 ([forTest])；进程级 [instance] 永不被测试 dispose。
  void dispose() {
    _gamepadDetectionTimer?.cancel();
    _gamepadDetectionTimer = null;
    _glowResetTimer?.cancel();
    _glowResetTimer = null;
    preference.dispose();
    effectiveMode.dispose();
    arrowGlow.dispose();
  }
}
