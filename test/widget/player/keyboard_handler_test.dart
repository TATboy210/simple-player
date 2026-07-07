import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
  int previous = 0;
  int next = 0;
  int openFile = 0;
  int toggleSubtitle = 0;
  int exitFullscreen = 0;
  int showHelp = 0;
  int subtitleDelayForward = 0;
  int subtitleDelayBackward = 0;
  int mediaPlayPause = 0;
  int mediaNext = 0;
  int mediaPrevious = 0;
}

/// 构建测试用 KeyboardHandler wrapper
///
/// Focus 节点通过 tester.binding.focusManager 获取，
/// autofocus=true 确保按键事件能被接收。
Widget _buildSubject(_CallbackTracker t, {Map<String, String> bindings = const {}}) =>
    MaterialApp(
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
          onPrevious: () => t.previous++,
          onNext: () => t.next++,
          onOpenFile: () => t.openFile++,
          onToggleSubtitle: () => t.toggleSubtitle++,
          onExitFullscreen: () => t.exitFullscreen++,
          onShowHelp: () => t.showHelp++,
          onSubtitleDelayForward: () => t.subtitleDelayForward++,
          onSubtitleDelayBackward: () => t.subtitleDelayBackward++,
          onMediaPlayPause: () => t.mediaPlayPause++,
          onMediaNext: () => t.mediaNext++,
          onMediaPrevious: () => t.mediaPrevious++,
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

    testWidgets('F key toggles fullscreen', (tester) async {
      await tester.pumpWidget(_buildSubject(tracker));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF);
      expect(tracker.toggleFullscreen, 1);
    });

    testWidgets('M key toggles mute', (tester) async {
      await tester.pumpWidget(_buildSubject(tracker));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyM);
      expect(tracker.toggleMute, 1);
    });

    testWidgets('N key goes to next track', (tester) async {
      await tester.pumpWidget(_buildSubject(tracker));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyN);
      expect(tracker.next, 1);
      expect(tracker.previous, 0);
    });

    testWidgets('P key goes to previous track', (tester) async {
      await tester.pumpWidget(_buildSubject(tracker));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyP);
      expect(tracker.previous, 1);
      expect(tracker.next, 0);
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

    testWidgets('media keys trigger callbacks', (tester) async {
      await tester.pumpWidget(_buildSubject(tracker));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.mediaPlayPause);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.mediaTrackNext);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.mediaTrackPrevious);
      expect(tracker.mediaPlayPause, 1);
      expect(tracker.mediaNext, 1);
      expect(tracker.mediaPrevious, 1);
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
      expect(tracker.next, 0);
      expect(tracker.previous, 0);
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
        MaterialApp(
          home: Scaffold(
            body: KeyboardHandler(
              child: const SizedBox.expand(),
            ),
          ),
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
      final bindings = {
        'playPause': LogicalKeyboardKey.keyA.keyId.toString(),
      };
      await tester.pumpWidget(_buildSubject(tracker, bindings: bindings));

      // KeyA 应触发 playPause（自定义绑定）
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
      expect(tracker.playPause, 1);

      // Space 不再触发 playPause（被自定义绑定覆盖）
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      expect(tracker.playPause, 1); // 仍然1，未增加
    });

    testWidgets('customBindings partial — unmatched actions use default keys',
        (tester) async {
      // 只覆盖 playPause，其他动作保留默认按键
      final bindings = {
        'playPause': LogicalKeyboardKey.keyA.keyId.toString(),
      };
      await tester.pumpWidget(_buildSubject(tracker, bindings: bindings));

      // seekForward 仍绑定默认的 ArrowRight
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      expect(tracker.seekForward, 1);
    });

    // ── F12 debug key ──

    testWidgets('F12 key does not crash (perf stats export)', (tester) async {
      await tester.pumpWidget(_buildSubject(tracker));
      // F12 调用 PerfMonitor.instance.exportStats() — 验证不抛异常
      await tester.sendKeyDownEvent(LogicalKeyboardKey.f12);
      // 无异常 = 通过（F12 不触发任何用户回调）
      expect(tracker.playPause, 0);
    });
  });
}
