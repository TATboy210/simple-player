import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/keyboard_handler.dart';

/// 回调计数器 — 追踪 KeyboardHandler 各回调触发次数
class _CallbackTracker {
  int playPause = 0;
  int seekBackward = 0;
  int seekForward = 0;
  int volumeUp = 0;
  int volumeDown = 0;
  int toggleFullscreen = 0;
  int toggleMute = 0;
  int openFile = 0;
  int toggleSubtitle = 0;
  int exitFullscreen = 0;
  int showHelp = 0;
  int subtitleDelayForward = 0;
  int subtitleDelayBackward = 0;
  int mediaPlayPause = 0;
}

/// 构建测试用 KeyboardHandler wrapper
///
/// Focus 节点通过 tester.binding.focusManager 获取，
/// autofocus=true 确保按键事件能被接收。
Widget _buildSubject(
  _CallbackTracker t, {
  Map<String, String> bindings = const {},
}) => MaterialApp(
  home: Scaffold(
    body: KeyboardHandler(
      customBindings: bindings,
      onPlayPause: () => t.playPause++,
      onSeekBackward: () => t.seekBackward++,
      onSeekForward: () => t.seekForward++,
      onVolumeUp: () => t.volumeUp++,
      onVolumeDown: () => t.volumeDown++,
      onToggleFullscreen: () => t.toggleFullscreen++,
      onToggleMute: () => t.toggleMute++,
      onOpenFile: () => t.openFile++,
      onToggleSubtitle: () => t.toggleSubtitle++,
      onExitFullscreen: () => t.exitFullscreen++,
      onShowHelp: () => t.showHelp++,
      onSubtitleDelayForward: () => t.subtitleDelayForward++,
      onSubtitleDelayBackward: () => t.subtitleDelayBackward++,
      onMediaPlayPause: () => t.mediaPlayPause++,
      child: const SizedBox.expand(),
    ),
  ),
);

void main() {
  late _CallbackTracker tracker;

  setUp(() {
    tracker = _CallbackTracker();
  });

  group('KeyboardHandler key dispatch', () {
    testWidgets('space key triggers play/pause', (tester) async {
      await tester.pumpWidget(_buildSubject(tracker));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      expect(tracker.playPause, 1);
    });

    testWidgets('left arrow seeks backward', (tester) async {
      await tester.pumpWidget(_buildSubject(tracker));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      expect(tracker.seekBackward, 1);
      expect(tracker.seekForward, 0);
    });

    testWidgets('right arrow seeks forward', (tester) async {
      await tester.pumpWidget(_buildSubject(tracker));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      expect(tracker.seekForward, 1);
      expect(tracker.seekBackward, 0);
    });

    testWidgets('up arrow increases volume', (tester) async {
      await tester.pumpWidget(_buildSubject(tracker));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
      expect(tracker.volumeUp, 1);
      expect(tracker.volumeDown, 0);
    });

    testWidgets('down arrow decreases volume', (tester) async {
      await tester.pumpWidget(_buildSubject(tracker));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
      expect(tracker.volumeDown, 1);
      expect(tracker.volumeUp, 0);
    });

    testWidgets('F key triggers fullscreen toggle', (tester) async {
      await tester.pumpWidget(_buildSubject(tracker));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF);
      expect(tracker.toggleFullscreen, 1);
    });

    testWidgets('M key toggles mute', (tester) async {
      await tester.pumpWidget(_buildSubject(tracker));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyM);
      expect(tracker.toggleMute, 1);
    });

    testWidgets('N/P keys remain unhandled in single-file mode', (
      tester,
    ) async {
      await tester.pumpWidget(_buildSubject(tracker));

      // 单文件播放器不拥有队列导航，事件必须继续向焦点树上层传播。
      final nextHandled = await tester.sendKeyDownEvent(
        LogicalKeyboardKey.keyN,
      );
      final previousHandled = await tester.sendKeyDownEvent(
        LogicalKeyboardKey.keyP,
      );

      expect(nextHandled, isFalse);
      expect(previousHandled, isFalse);
    });

    testWidgets('O key opens file picker', (tester) async {
      await tester.pumpWidget(_buildSubject(tracker));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyO);
      expect(tracker.openFile, 1);
    });

    testWidgets('S key toggles subtitle', (tester) async {
      await tester.pumpWidget(_buildSubject(tracker));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyS);
      expect(tracker.toggleSubtitle, 1);
    });

    testWidgets('ESC key exits fullscreen', (tester) async {
      await tester.pumpWidget(_buildSubject(tracker));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
      expect(tracker.exitFullscreen, 1);
    });

    testWidgets('media play/pause triggers its callback', (tester) async {
      await tester.pumpWidget(_buildSubject(tracker));

      final handled = await tester.sendKeyDownEvent(
        LogicalKeyboardKey.mediaPlayPause,
      );

      expect(handled, isTrue);
      expect(tracker.mediaPlayPause, 1);
    });

    testWidgets('media track keys remain unhandled in single-file mode', (
      tester,
    ) async {
      await tester.pumpWidget(_buildSubject(tracker));

      // 系统媒体上一首/下一首同样属于队列语义，不能被单文件播放器截获。
      final nextHandled = await tester.sendKeyDownEvent(
        LogicalKeyboardKey.mediaTrackNext,
      );
      final previousHandled = await tester.sendKeyDownEvent(
        LogicalKeyboardKey.mediaTrackPrevious,
      );

      expect(nextHandled, isFalse);
      expect(previousHandled, isFalse);
    });
  });

  group('KeyboardHandler shortcut definitions', () {
    test('single-file mode omits queue navigation shortcuts', () {
      final l10n = lookupAppLocalizations(const Locale('zh'));

      final definitions = shortcutDefinitions(l10n);
      final keyLabels = definitions.map(((String, String) item) => item.$1);
      final descriptions = definitions.map(((String, String) item) => item.$2);

      expect(keyLabels, isNot(contains('N')));
      expect(keyLabels, isNot(contains('P')));
      expect(descriptions, isNot(contains(l10n.shortcutNext)));
      expect(descriptions, isNot(contains(l10n.shortcutPrevious)));
      expect(l10n.shortcutMediaKeys, isNot(contains(l10n.shortcutNext)));
      expect(l10n.shortcutMediaKeys, isNot(contains(l10n.shortcutPrevious)));
    });
  });

  group('KeyboardHandler edge cases', () {
    testWidgets('unmatched key returns ignored', (tester) async {
      await tester.pumpWidget(_buildSubject(tracker));
      // KeyX has no binding — 应该不触发任何回调
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyX);
      expect(tracker.playPause, 0);
      expect(tracker.toggleFullscreen, 0);
      expect(tracker.toggleMute, 0);
    });

    testWidgets('KeyUpEvent is ignored (only KeyDown handled)', (tester) async {
      await tester.pumpWidget(_buildSubject(tracker));
      // 只发送 KeyUp — 应该不触发回调
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      expect(tracker.playPause, 0);
    });

    testWidgets('bracket keys trigger subtitle delay', (tester) async {
      await tester.pumpWidget(_buildSubject(tracker));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.bracketRight);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.bracketLeft);
      expect(tracker.subtitleDelayForward, 1);
      expect(tracker.subtitleDelayBackward, 1);
    });

    // ── F1 help key ──

    testWidgets('F1 key triggers showHelp callback', (tester) async {
      await tester.pumpWidget(_buildSubject(tracker));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.f1);
      expect(tracker.showHelp, 1);
    });

    // ── Null callback safety ──

    testWidgets('null callbacks do not crash on key press', (tester) async {
      // 所有回调为 null — 按键不应抛异常
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: KeyboardHandler(child: SizedBox.expand())),
        ),
      );
      // 发送多个不同按键 — 全部应安全忽略
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.f1);
      // 无异常 = 通过
    });

    // ── CustomBindings ──

    testWidgets('customBindings overrides default key mapping', (tester) async {
      // 将 playPause 绑定到 KeyA 而非 Space
      final bindings = {'playPause': LogicalKeyboardKey.keyA.keyId.toString()};
      await tester.pumpWidget(_buildSubject(tracker, bindings: bindings));

      // KeyA 应触发 playPause（自定义绑定）
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
      expect(tracker.playPause, 1);

      // Space 不再触发 playPause（被自定义绑定覆盖）
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      expect(tracker.playPause, 1); // 仍然1，未增加
    });

    testWidgets('customBindings partial — unmatched actions use default keys', (
      tester,
    ) async {
      // 只覆盖 playPause，其他动作保留默认按键
      final bindings = {'playPause': LogicalKeyboardKey.keyA.keyId.toString()};
      await tester.pumpWidget(_buildSubject(tracker, bindings: bindings));

      // seekForward 仍绑定默认的 ArrowRight
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      expect(tracker.seekForward, 1);
    });

    // ── ? character via slash key ──

    testWidgets('? character via slash key triggers showHelp', (tester) async {
      await tester.pumpWidget(_buildSubject(tracker));
      // line 166: (key == LogicalKeyboardKey.slash && event.character == '?')
      // sendKeyDownEvent 默认 character=null，需要手动构造带 character 的事件
      await tester.sendKeyEvent(LogicalKeyboardKey.slash, character: '?');
      expect(tracker.showHelp, 1);
    });
  });
}
