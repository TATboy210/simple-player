import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/player/keyboard_handler.dart';
import 'package:simple_player_flutter/ui/player/workspace_menu_session.dart';
import 'package:simple_player_flutter/ui/shared/owned_anchored_menu.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/playlist/playlist_panel.dart';
import 'package:simple_player_flutter/kernel/models/playlist_item.dart';
import 'package:simple_player_flutter/kernel/models/playlist_sort.dart';
import 'package:simple_player_flutter/kernel/models/play_mode.dart';
import 'package:simple_player_flutter/ui/shared/glass_container.dart';

void main() {
  for (final activation in [
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.space,
  ]) {
    testWidgets('actual sort trigger $activation opens and selects only once', (
      tester,
    ) async {
      final menus = WorkspaceMenuSession();
      final entries = ValueNotifier(const <PlaylistItem>[]);
      final current = ValueNotifier(-1);
      final last = ValueNotifier<String?>(null);
      final mode = ValueNotifier(PlayMode.loopAll);
      for (final source in [menus, entries, current, last, mode]) {
        addTearDown(source.dispose);
      }
      var selected = 0;
      var playback = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: WorkspaceMenuScope(
            session: menus,
            onEscape: () {},
            child: Scaffold(
              body: KeyboardHandler(
                menuSession: menus,
                onPlayPause: () => playback++,
                child: SizedBox(
                  height: 350,
                  child: PlaylistPanel(
                    entries: entries,
                    currentIndex: current,
                    lastPlayedPath: last,
                    visible: true,
                    onClose: () {},
                    onPlayEntry: (_) {},
                    onResumeEntry: (_) {},
                    onRemoveEntry: (_) {},
                    playMode: mode,
                    onCyclePlayMode: () {},
                    sortKey: PlaylistSortKey.addedOrder,
                    sortAscending: true,
                    onSortSelected: (_) => selected++,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final button = tester.widget<GlassButton>(
        find.widgetWithIcon(GlassButton, Icons.sort),
      );
      button.focusNode?.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(activation);
      await tester.pumpAndSettle();
      expect(menus.isOwnedMenuTopmost, isTrue);
      expect(selected, 0, reason: 'opening key never selects the first row');
      expect(playback, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
        menus.isOwnedMenuTopmost,
        isTrue,
        reason: 'windowed ESC keeps menu',
      );
      await tester.sendKeyEvent(activation);
      await tester.pumpAndSettle();
      expect(selected, 1);
      expect(playback, 0);
      expect(button.focusNode?.hasPrimaryFocus, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final focusLocation in ['external', 'root', 'null', 'menu']) {
    testWidgets('owned route suppresses all player keys at $focusLocation', (
      tester,
    ) async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();
      final menu = harness.open(tester);
      await tester.pumpAndSettle();
      final focusedBoundary = tester.widget<Focus>(
        find
            .descendant(
              of: find.byType(KeyboardHandler),
              matching: find.byType(Focus),
            )
            .first,
      );
      focusedBoundary.onKeyEvent?.call(
        focusedBoundary.focusNode ?? FocusManager.instance.rootScope,
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyQ,
          logicalKey: LogicalKeyboardKey.keyQ,
          timeStamp: Duration.zero,
        ),
      );
      expect(
        harness.playerCalls,
        0,
        reason: 'real focused boundary also refuses owned events',
      );
      if (focusLocation == 'external' || focusLocation == 'null') {
        harness.external.requestFocus();
        await tester.pump();
      }
      if (focusLocation == 'root' || focusLocation == 'null') {
        FocusManager.instance.primaryFocus?.unfocus();
        FocusManager.instance.rootScope.requestFocus();
      }
      // Detaching the primary node produces the genuine transient null state,
      // before a frame/microtask chooses the root scope again.
      if (focusLocation == 'null') {
        final transient = FocusNode(debugLabel: 'detached-primary');
        addTearDown(transient.dispose);
        final attachment = transient.attach(
          tester.element(find.text('trigger')),
        );
        attachment.reparent(parent: FocusManager.instance.rootScope);
        transient.requestFocus();
        FocusManager.instance.applyFocusChangesIfNeeded();
        expect(FocusManager.instance.primaryFocus, same(transient));
        attachment.detach();
        expect(FocusManager.instance.primaryFocus, isNull);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
        expect(harness.playerCalls, 0, reason: 'true null fallback is guarded');
      } else {
        await tester.pump();
      }
      for (final key in _playerKeys) {
        await tester.sendKeyEvent(key);
      }
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      // '?' is the fixed help alternative, independent of custom mappings.
      await tester.sendKeyEvent(LogicalKeyboardKey.slash, character: '?');
      expect(harness.playerCalls, 0);
      expect(harness.menuEsc, 1);
      expect(menu.route.isCurrent, isTrue);
      menu.cancel();
      await tester.pumpAndSettle();
      harness.external.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
      expect(
        harness.playerCalls,
        1,
        reason: 'custom binding resumes after close',
      );
    });
  }

  for (final activation in [
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.space,
  ]) {
    testWidgets('actual menu $activation selects once without playback', (
      tester,
    ) async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();
      final menu = harness.open(tester);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(activation);
      await tester.pumpAndSettle();
      expect((await menu.result)?.value, 'last');
      expect(harness.playerCalls, 0);
      expect(harness.menus.isOwnedMenuTopmost, isFalse);
    });
  }

  for (final registerFirst in [false, true]) {
    for (final replacement in [false, true]) {
      testWidgets(
        'same event cancel/replace=$replacement early=$registerFirst',
        (tester) async {
          final harness = _Harness();
          addTearDown(harness.dispose);
          OwnedMenuHandle<String>? menu;
          bool mutate(KeyEvent event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.keyQ) {
              harness.menus.latchEvent(
                event,
              ); // Must precede ownership mutation.
              menu?.cancel();
              if (replacement) menu = harness.open(tester);
            }
            return true; // HardwareKeyboard still invokes the real fallback.
          }

          if (registerFirst) HardwareKeyboard.instance.addHandler(mutate);
          await tester.pumpWidget(harness.build());
          await tester.pumpAndSettle();
          menu = harness.open(tester);
          await tester.pumpAndSettle();
          harness.external.requestFocus();
          await tester.pump();
          if (!registerFirst) HardwareKeyboard.instance.addHandler(mutate);
          await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
          HardwareKeyboard.instance.removeHandler(mutate);
          expect(harness.playerCalls, 0);
          menu?.cancel();
          await tester.pumpAndSettle();
        },
      );
    }
  }

  testWidgets(
    'opening event latches before route push and all later handlers',
    (tester) async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      OwnedMenuHandle<String>? menu;
      bool opener(KeyEvent event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyQ) {
          harness.menus.latchEvent(event);
          menu = harness.open(tester);
        }
        return true;
      }

      HardwareKeyboard.instance.addHandler(opener);
      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();
      harness.external.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
      HardwareKeyboard.instance.removeHandler(opener);
      expect(harness.playerCalls, 0);
      await tester.pumpAndSettle();
      expect(menu?.route.isCurrent, isTrue);
      menu?.cancel();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('foreign dialog above real menu keeps native keys and ESC', (
    tester,
  ) async {
    final harness = _Harness();
    final dialogFocus = FocusNode(debugLabel: 'foreign-dialog');
    addTearDown(harness.dispose);
    addTearDown(dialogFocus.dispose);
    var native = 0;
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    final menu = harness.open(tester);
    await tester.pumpAndSettle();
    unawaited(
      showDialog<void>(
        context: tester.element(find.text('trigger')),
        builder: (_) => AlertDialog(
          content: Focus(
            autofocus: true,
            focusNode: dialogFocus,
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey != LogicalKeyboardKey.escape) {
                native++;
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: const Text('foreign'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final key in [
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.f1,
    ]) {
      await tester.sendKeyEvent(key);
    }
    expect(native, 4);
    expect(harness.playerCalls, 0);
    expect(harness.menuEsc, 0);
    // Even dead-keyboard fallback must not act beneath a foreign top route.
    harness.external.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
    expect(harness.playerCalls, 0);
    dialogFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('foreign'), findsNothing);
    expect(menu.route.isCurrent, isTrue);
    menu.cancel();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'held arrow repeats walk enabled rows; activation repeats never reselect',
    (tester) async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();
      final menu = harness.open(tester);
      await tester.pumpAndSettle();
      // 激活键 KeyRepeat 防连发:结果 Future 在重复期间绝不完成。
      var resultCompleted = false;
      unawaited(menu.result.then((_) => resultCompleted = true));
      // 行级 Focus 只带 focusNode/onFocusChange;但 MaterialApp/Navigator
      // 层作用域在更外侧也装有 onKeyEvent,故不能用 singleWhere。菜单体
      // Focus 是行 Focus 之上最近一个带 handler 的祖先——真实按键冒泡时
      // 也恰是它先于外层作用域收到事件,故取 firstWhere。
      final menuBodyFocus = tester
          .widgetList<Focus>(
            find.ancestor(of: find.text('First'), matching: find.byType(Focus)),
          )
          .firstWhere((focus) => focus.onKeyEvent != null);
      // 沿本文件既有直调模式合成 KeyRepeatEvent,并断言每次返回均为
      // handled —— 重复事件一律吞在菜单门禁,不泄漏给播放器 KeyboardHandler。
      void sendRepeat(
        LogicalKeyboardKey logical,
        PhysicalKeyboardKey physical,
      ) {
        final result = menuBodyFocus.onKeyEvent?.call(
          FocusManager.instance.primaryFocus ?? FocusManager.instance.rootScope,
          KeyRepeatEvent(
            physicalKey: physical,
            logicalKey: logical,
            timeStamp: Duration.zero,
          ),
        );
        expect(
          result,
          KeyEventResult.handled,
          reason: '$logical repeat must stay swallowed inside the menu',
        );
      }

      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'owned-menu-First',
      );
      // 长按 ↓:First → Last(跳过 Disabled)→ First(环绕)。
      sendRepeat(LogicalKeyboardKey.arrowDown, PhysicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'owned-menu-Last',
        reason: 'repeat moves down and skips the disabled row',
      );
      sendRepeat(LogicalKeyboardKey.arrowDown, PhysicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'owned-menu-First',
        reason: 'repeat wraps from last back to first',
      );
      // 长按 ↑:First → Last(逆向环绕,同样跳过 Disabled)。
      sendRepeat(LogicalKeyboardKey.arrowUp, PhysicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'owned-menu-Last',
        reason: 'reverse repeat wraps from first to last',
      );
      sendRepeat(LogicalKeyboardKey.arrowUp, PhysicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'owned-menu-First',
        reason: 'reverse repeat also skips the disabled row',
      );
      // 真实 KeyDown 移到 Last,作为激活键防连发断言的落点。
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'owned-menu-Last');
      // 按住激活键:Enter/Space/numpadEnter 的 KeyRepeat 全部在门禁吞掉,
      // 菜单保持打开、结果 Future 不完成,select() 只能被 KeyDown 触达。
      sendRepeat(LogicalKeyboardKey.enter, PhysicalKeyboardKey.enter);
      sendRepeat(LogicalKeyboardKey.space, PhysicalKeyboardKey.space);
      sendRepeat(
        LogicalKeyboardKey.numpadEnter,
        PhysicalKeyboardKey.numpadEnter,
      );
      await tester.pump();
      expect(menu.route.isCurrent, isTrue);
      expect(resultCompleted, isFalse, reason: 'repeat never selects');
      // 激活由真实 KeyDown 单发触发:一次 Enter 即以 'last' 关闭菜单。
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect((await menu.result)?.value, 'last');
      expect(harness.playerCalls, 0);
    },
  );
}

const _playerKeys = [
  LogicalKeyboardKey.keyQ,
  LogicalKeyboardKey.arrowLeft,
  LogicalKeyboardKey.arrowRight,
  LogicalKeyboardKey.arrowUp,
  LogicalKeyboardKey.arrowDown,
  LogicalKeyboardKey.keyM,
  LogicalKeyboardKey.keyO,
  LogicalKeyboardKey.keyS,
  LogicalKeyboardKey.keyL,
  LogicalKeyboardKey.keyN,
  LogicalKeyboardKey.keyP,
  LogicalKeyboardKey.keyF,
  LogicalKeyboardKey.f1,
  LogicalKeyboardKey.bracketLeft,
  LogicalKeyboardKey.bracketRight,
  LogicalKeyboardKey.mediaPlayPause,
  LogicalKeyboardKey.escape,
];

/// 真实 KeyboardHandler + owned PopupRoute；计数的是生产回调边界。
class _Harness {
  final menus = WorkspaceMenuSession();
  final external = FocusNode(debugLabel: 'external-player-focus');
  int playerCalls = 0;
  int menuEsc = 0;

  void _act() => playerCalls++;

  Widget build() => MaterialApp(
    builder: (_, child) => Focus(focusNode: external, child: child!),
    home: Scaffold(
      body: KeyboardHandler(
        menuSession: menus,
        customBindings: {'playPause': LogicalKeyboardKey.keyQ.keyId.toString()},
        onPlayPause: _act,
        onSeekBackward: _act,
        onSeekForward: _act,
        onVolumeUp: _act,
        onVolumeDown: _act,
        onToggleMute: _act,
        onOpenFile: _act,
        onToggleSubtitle: _act,
        onTogglePlaylist: _act,
        onPlayPrevious: _act,
        onPlayNext: _act,
        onToggleFullscreen: _act,
        onShowHelp: _act,
        onSubtitleDelayForward: _act,
        onSubtitleDelayBackward: _act,
        onMediaPlayPause: _act,
        onExitFullscreen: _act,
        child: const Text('trigger'),
      ),
    ),
  );

  OwnedMenuHandle<String> open(WidgetTester tester) => OwnedAnchoredMenu.open(
    tester.element(find.text('trigger')),
    owner: this,
    session: menus,
    onEscape: () => menuEsc++,
    entries: const [
      OwnedMenuEntry(value: 'first', label: 'First'),
      OwnedMenuEntry(value: 'disabled', label: 'Disabled', isEnabled: false),
      OwnedMenuEntry(value: 'last', label: 'Last'),
    ],
  );

  void dispose() {
    menus.dispose();
    external.dispose();
  }
}
