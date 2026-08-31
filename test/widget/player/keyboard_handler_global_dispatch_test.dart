import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/player/keyboard_handler.dart';

/// G-03-3 全局回退分发回归 —— dead-keyboard 修复 + 守卫判定矩阵。
///
/// 复现配方来自 .planning/debug/g03-3-f1-help-dialog-no-op.md note 字段：
/// home 注入 KeyboardHandler（onShowHelp → showDialog），外层 Focus 持焦
/// 模拟焦点滞留。守卫矩阵逐行证明回退不吞键（Slider/面板/对话框/文本框）。
///
/// 本文件刻意不 init KernelLoggerImpl —— 同时证明回退埋点的 isInitialized
/// 探针（WR-02 先例）在未初始化环境下不抛 StateError。
void main() {
  late _CallbackTracker tracker;

  setUp(() {
    tracker = _CallbackTracker();
  });

  // 基础 harness：home 注入 KeyboardHandler（autofocus 焦点子树），
  // onShowHelp 真弹对话框 —— 弹窗可见性即真实分发证据。
  Widget buildHarness(_CallbackTracker t) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (helpContext) {
            return KeyboardHandler(
              onShowHelp: () {
                t.showHelp += 1;
                showDialog<void>(
                  context: helpContext,
                  builder: (_) => const AlertDialog(title: Text('help')),
                );
              },
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
  }

  group('dead-keyboard rescue (G-03-3)', () {
    testWidgets(
      'F1 + Space + ESC reach handler when primary focus strands on an external Focus above the navigator',
      (tester) async {
        // Arrange：外层 Focus 挂在 MaterialApp.builder 层 —— 其 context 无
        // 任何 ModalRoute 祖先，是 UAT 死键盘态的代码级复现。
        final outerNode = FocusNode(debugLabel: 'stranded-outer');
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, navigator) => Focus(
              focusNode: outerNode,
              child: navigator ?? const SizedBox.shrink(),
            ),
            home: buildHarness(tracker),
          ),
        );
        await tester.pump();
        outerNode.requestFocus();
        await tester.pump();
        expect(
          FocusManager.instance.primaryFocus,
          same(outerNode),
          reason: '前置：主焦点滞留在 handler 焦点子树之外',
        );

        // Act + Assert：三个代表性快捷键全部经回退路径可达。
        await tester.sendKeyDownEvent(LogicalKeyboardKey.f1);
        await tester.pump();
        expect(tracker.showHelp, 1, reason: 'F1 必须弹出帮助（UAT「按f1没用」）');
        expect(find.byType(AlertDialog), findsOneWidget);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
        expect(tracker.playPause, 1, reason: 'Space 同样经回退路径可达');

        await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
        expect(tracker.exitFullscreen, 1, reason: 'ESC 同样经回退路径可达');
      },
    );

    testWidgets(
      'F1 reaches handler after unfocus(scope) strands primaryFocus on the route scope node',
      (tester) async {
        // Arrange：正常挂载后把焦点释放到 scope —— primaryFocus 变为路由的
        // FocusScopeNode（框架 scope 无按键处理器，焦点分发从它上行必死，
        // 是 UAT 全屏循环后焦点回落边界的代码级复现形态）。
        await tester.pumpWidget(buildHarness(tracker));
        await tester.pump();
        FocusManager.instance.primaryFocus!.unfocus(
          disposition: UnfocusDisposition.scope,
        );
        await tester.pump();
        expect(
          FocusManager.instance.primaryFocus,
          isA<FocusScopeNode>(),
          reason: '前置：主焦点滞留在框架 scope 节点上（dead-keyboard 态）',
        );

        // Act + Assert：F1 仍弹出帮助。
        await tester.sendKeyDownEvent(LogicalKeyboardKey.f1);
        await tester.pump();
        expect(tracker.showHelp, 1);
        expect(find.byType(AlertDialog), findsOneWidget);
      },
    );
  });

  group('fallback guard matrix (must not steal keys)', () {
    testWidgets('Slider keeps arrow-key adjustment while focused', (
      tester,
    ) async {
      // Arrange：Slider 传自建 focusNode 并持焦（volume_controls.dart Slider
      // 的 Material 实现走 FocusableActionDetector 快捷键调节）。
      final sliderNode = FocusNode(debugLabel: 'volume-slider');
      var sliderChanges = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KeyboardHandler(
              child: Column(
                children: [
                  Slider(
                    focusNode: sliderNode,
                    value: 0.5,
                    onChanged: (_) => sliderChanges += 1,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      sliderNode.requestFocus();
      await tester.pump();

      // Act：← 键。
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);

      // Assert：Slider 消费方向键，回退不抢（seekBackward 保持 0）。
      expect(sliderChanges, 1, reason: 'Slider 自行调节音量');
      expect(tracker.seekBackward, 0, reason: '回退不得吞掉 Slider 方向键');
    });

    testWidgets('playlist-panel style Focus keeps ESC while focused', (
      tester,
    ) async {
      // Arrange：面板焦点节点 —— 自有 Focus + ESC 关闭语义
      // （playlist_panel.dart:184 先例的焦点行为复刻）。
      final panelNode = FocusNode(debugLabel: 'playlist-panel');
      var panelEscCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KeyboardHandler(
              child: Focus(
                focusNode: panelNode,
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.escape) {
                    panelEscCount += 1;
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      panelNode.requestFocus();
      await tester.pump();

      // Act：ESC。
      await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);

      // Assert：面板消费 ESC，onExitFullscreen 计数保持 0。
      expect(panelEscCount, 1, reason: '面板自行消费 ESC 关闭语义');
      expect(tracker.exitFullscreen, 0, reason: '回退不得吞掉面板 ESC');
    });

    testWidgets(
      'dialog keys stay inside the dialog; pressing F1 again does not stack a second dialog',
      (tester) async {
        // Arrange：帮助对话框打开，焦点在对话框内的消费节点上。
        final dialogNode = FocusNode(debugLabel: 'dialog-content');
        var dialogArrowCount = 0;
        await tester.pumpWidget(buildHarness(tracker));
        await tester.pump();
        unawaited(
          showDialog<void>(
            context: tester.element(find.byType(KeyboardHandler)),
            builder: (_) => AlertDialog(
              content: Focus(
                focusNode: dialogNode,
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    dialogArrowCount += 1;
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: const SizedBox(width: 10, height: 10),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        dialogNode.requestFocus();
        await tester.pump();

        // Act：对话框内按 F1，再按 ↑。
        await tester.sendKeyDownEvent(LogicalKeyboardKey.f1);
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);

        // Assert：不堆叠第二个对话框；↑ 留在对话框内，volumeUp 不触发。
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(tracker.showHelp, 0, reason: 'F1 在对话框内不再弹第二个帮助');
        expect(dialogArrowCount, 1, reason: '对话框内焦点节点自行消费 ↑');
        expect(tracker.volumeUp, 0, reason: '回退不得劫持对话框按键');
      },
    );

    testWidgets(
      'fallback does not consume keys for a root-overlay TextField (text-editing guard)',
      (tester) async {
        // Arrange：根 Overlay 内注入无 route 祖先的 TextField（EditableText
        // 守卫分支的直接演练场）。headless 测试不经 IME，物理按键不会真实
        // 写入文本 —— 断言落在「回退不消费、播放控制不触发」上。
        final controller = TextEditingController();
        final textFieldNode = FocusNode(debugLabel: 'overlay-text-field');
        await tester.pumpWidget(buildHarness(tracker));
        await tester.pump();
        tester
            .state<OverlayState>(find.byType(Overlay))
            .insert(
              OverlayEntry(
                builder: (_) => Material(
                  child: TextField(
                    controller: controller,
                    focusNode: textFieldNode,
                  ),
                ),
              ),
            );
        await tester.pump();
        textFieldNode.requestFocus();
        await tester.pump();
        await tester.pump();
        expect(
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<EditableText>(),
          isNotNull,
          reason: '前置：主焦点位于 EditableText 焦点链内',
        );

        // Act：Space。
        final handled = await tester.sendKeyDownEvent(
          LogicalKeyboardKey.space,
        );

        // Assert：回退不消费（事件穿透给文本输入链），playPause 不触发。
        expect(handled, isFalse, reason: 'Space 不被回退吞掉');
        expect(tracker.playPause, 0, reason: '文本框内 Space 不得触发播放/暂停');
      },
    );
  });

  group('fallback lifecycle', () {
    testWidgets('fallback handler stops firing after the widget unmounts', (
      tester,
    ) async {
      // Arrange：挂载 → 卸载。
      await tester.pumpWidget(buildHarness(tracker));
      await tester.pump();
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: const SizedBox.expand())),
      );
      await tester.pump();

      // Act + Assert：卸载后按 F1 —— 注册/注销严格配对，无陈旧回调、无异常。
      await tester.sendKeyDownEvent(LogicalKeyboardKey.f1);
      await tester.pump();
      expect(tracker.showHelp, 0);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}

/// 回调计数器 —— 追踪 KeyboardHandler 各回调触发次数（循
/// keyboard_handler_test.dart 的 _CallbackTracker 模式）。
class _CallbackTracker {
  int playPause = 0;
  int seekBackward = 0;
  int volumeUp = 0;
  int exitFullscreen = 0;
  int showHelp = 0;
}
