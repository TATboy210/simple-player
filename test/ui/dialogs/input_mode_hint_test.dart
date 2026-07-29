// input_mode_hint_test.dart — Phase 32 Plan 02 Task 1 (NAV-03) InputModeHint 测试。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/services/input_mode_detector.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/input_mode_hint.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';

void main() {
  group('InputModeHint', () {
    // 提示 Text finder —— 限定在 InputModeHint 子树内，避免框架层 Text 干扰。
    Finder hintTextFinder() => find.descendant(
          of: find.byType(InputModeHint),
          matching: find.byType(Text),
        );

    testWidgets('keyboard shows arrow text, gamepad shows LB/RB text',
        (tester) async {
      // Arrange — keyboard 起始。
      final mode = ValueNotifier<InputMode>(InputMode.keyboard);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: InputModeHint(effectiveMode: mode)),
        ),
      );

      // Assert — keyboard 显示方向键对。
      expect(tester.widget<Text>(hintTextFinder()).data, '← / →');

      // Act — 切到 gamepad，推进 AnimatedSwitcher 过渡。
      mode.value = InputMode.gamepad;
      await tester.pumpAndSettle();

      // Assert — gamepad 显示 LB / RB 肩键对。
      expect(tester.widget<Text>(hintTextFinder()).data, 'LB / RB');
    });

    testWidgets(
        'mode change triggers AnimatedSwitcher with distinct ValueKey per mode',
        (tester) async {
      // Arrange — keyboard 起始。
      final mode = ValueNotifier<InputMode>(InputMode.keyboard);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: InputModeHint(effectiveMode: mode)),
        ),
      );

      // Assert — 初始 child 的 ValueKey 为 keyboard。
      var key =
          tester.widget<Text>(hintTextFinder()).key as ValueKey<InputMode>;
      expect(key.value, InputMode.keyboard);

      // Act — 切到 gamepad，推进过渡。
      mode.value = InputMode.gamepad;
      await tester.pumpAndSettle();

      // Assert — 新 child 的 ValueKey 为 gamepad，与旧 key 不同
      // （AnimatedSwitcher 靠 ValueKey 区分新旧 child 触发过渡 ——
      // 无 key 则不交换，Pitfall）。
      key =
          tester.widget<Text>(hintTextFinder()).key as ValueKey<InputMode>;
      expect(key.value, InputMode.gamepad);
    });

    testWidgets('AnimatedSwitcher duration equals Tokens.hintFadeDuration',
        (tester) async {
      // Arrange。
      final mode = ValueNotifier<InputMode>(InputMode.keyboard);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: InputModeHint(effectiveMode: mode)),
        ),
      );

      // Assert — AnimatedSwitcher 时长 == hintFadeDuration（NAV-03）。
      final switcher = tester.widget<AnimatedSwitcher>(
        find.descendant(
          of: find.byType(InputModeHint),
          matching: find.byType(AnimatedSwitcher),
        ),
      );
      expect(
        switcher.duration,
        const Duration(milliseconds: Tokens.hintFadeDuration),
      );
    });
  });
}
