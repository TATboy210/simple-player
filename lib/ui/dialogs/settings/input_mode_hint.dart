// input_mode_hint.dart — Phase 32 Plan 02 (NAV-03) 输入模式提示。
//
// 职责：在设置面板标题栏显示当前有效输入模式的按键提示，经
// AnimatedSwitcher 交叉淡入淡出 —— keyboard 显示方向键对，gamepad
// 显示 LB / RB 肩键对 (NAV-03)。

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../kernel/services/input_mode_detector.dart';
import '../../theme/tokens.dart';

/// 输入模式提示 (NAV-03) —— 显示当前有效输入模式的按键提示。
///
/// 经 [ValueListenableBuilder]<[InputMode]> 监听 [InputModeDetector.effectiveMode]
/// （有效模式，非 preference —— D-03：[effectiveMode] 永不为 [InputMode.auto]，
/// 故本 widget 仅分支 keyboard / gamepad，不处理 auto）。
///
/// 切换时 [AnimatedSwitcher] 交叉淡入新标签，时长 [Tokens.hintFadeDuration]。
/// 每个 mode 的 [Text] 以 [ValueKey]<[InputMode]>(mode) 标识 —— 无此 key 则
/// AnimatedSwitcher 视新旧 child 为同类型不触发过渡（Pitfall —— keyed child
/// swap 是切换触发的前提）。
class InputModeHint extends StatelessWidget {
  const InputModeHint({
    super.key,
    required this.effectiveMode,
  });

  /// 有效输入模式 —— 接 [InputModeDetector.instance.effectiveMode]。
  /// D-03: 永不为 [InputMode.auto]，故下方仅分支 keyboard / gamepad。
  final ValueListenable<InputMode> effectiveMode;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<InputMode>(
      valueListenable: effectiveMode,
      builder: (context, mode, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: Tokens.hintFadeDuration),
          child: Text(
            mode == InputMode.gamepad ? 'LB / RB' : '← / →',
            // ValueKey(mode) —— 无此 key，AnimatedSwitcher 不触发过渡
            // （新旧 Text 同类型被视为同一 child，不交换）。
            key: ValueKey<InputMode>(mode),
            style: const TextStyle(
              color: Tokens.textSecondary,
              fontSize: Tokens.fontCaption,
            ),
          ),
        );
      },
    );
  }
}
