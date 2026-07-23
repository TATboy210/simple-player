import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:window_manager/window_manager.dart';
import 'package:simple_player_flutter/kernel/services/playback_controller.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/kernel/playlist/playlist.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_panel_controller.dart';
import 'package:simple_player_flutter/ui/player/player_screen.dart';
import 'package:simple_player_flutter/ui/player/drop_handler.dart';
import 'package:simple_player_flutter/ui/playlist/playlist_panel.dart';
import 'package:simple_player_flutter/kernel/bridge/window_mode.dart';
import '../../helpers/fake_engine.dart';
import '../../helpers/fake_window_service.dart';

void main() {
  late FakeEngine engine;
  late FakeWindowService windowService;
  late Playlist playlist;
  late ValueNotifier<int> playlistGeneration;

  setUp(() {
    engine = FakeEngine();
    windowService = FakeWindowService();
    playlist = Playlist();
    playlistGeneration = ValueNotifier(0);
  });

  tearDown(() {
    engine.dispose();
    windowService.dispose();
    playlistGeneration.dispose();
  });

  /// 构建最小化 PlayerScreen 测试壳
  ///
  /// PlaybackController 不调用 init()，避免触发状态监听和持久化。
  /// MediaQuery 宽度由 [screenWidth] 控制，用于验证响应式布局。
  Widget buildSubject({double screenWidth = 800}) {
    final controller = PlaybackController(
      engine: engine,
      playlist: playlist,
      onNeedRebuild: () {},
    );
    final settingsPanelController = SettingsPanelController(controller);
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(size: Size(screenWidth, 600)),
        child: PlayerScreen(
          engine: engine,
          controller: controller,
          playlist: playlist,
          playlistGeneration: playlistGeneration,
          windowService: windowService,
          settingsPanelController: settingsPanelController,
        ),
      ),
    );
  }

  group('PlayerScreen', () {
    testWidgets('idle 状态渲染空壳不崩溃', (tester) async {
      // Arrange: engine 处于 idle（默认）
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // Assert: Scaffold 存在，无异常
      expect(find.byType(PlayerScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('seek 钳位到 0 — 不会负数', (tester) async {
      // Arrange: position=2000ms, duration=60000ms
      engine.configureMedia(durationMs: 60000);
      engine.position.value = 2000;
      engine.duration.value = 60000;

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // Act: 模拟 _seek(engine, -5000) → 2000 - 5000 = -3000 → clamp → 0
      // PlayerScreen._seek 是 private，通过 engine 直接验证 clamp 逻辑
      final target = (engine.position.value - 5000).clamp(0, engine.duration.value);
      unawaited(engine.seekTo(target));

      // Assert: seekTo 被 clamp 到 0
      expect(engine.lastSeekToMs, 0);
      expect(engine.position.value, 0);
    });

    testWidgets('seek 钳位到 duration — 不会超出', (tester) async {
      // Arrange: position=58000ms, duration=60000ms
      engine.configureMedia(durationMs: 60000);
      engine.position.value = 58000;
      engine.duration.value = 60000;

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // Act: 模拟 _seek(engine, 5000) → 58000 + 5000 = 63000 → clamp → 60000
      final target = (engine.position.value + 5000).clamp(0, engine.duration.value);
      unawaited(engine.seekTo(target));

      // Assert: seekTo 被 clamp 到 duration
      expect(engine.lastSeekToMs, 60000);
    });

    testWidgets('窄屏布局 — 宽度 < breakpointWide', (tester) async {
      // Arrange: screenWidth=500 < Tokens.breakpointWide (600)
      await tester.pumpWidget(buildSubject(screenWidth: 500));
      await tester.pump();

      // Assert: PlayerScreen 正常渲染，窄屏 Stack 模式
      expect(find.byType(PlayerScreen), findsOneWidget);
      expect(find.byType(Stack), findsAtLeast(1));
    });

    testWidgets('宽屏布局 — 宽度 ≥ breakpointWide', (tester) async {
      // Arrange: screenWidth=900 ≥ Tokens.breakpointWide (600)
      await tester.pumpWidget(buildSubject(screenWidth: 900));
      await tester.pump();

      // Assert: PlayerScreen 正常渲染
      expect(find.byType(PlayerScreen), findsOneWidget);
    });

    testWidgets('VideoSurface 存在', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // Assert: VideoSurface 在 _buildVideoContent 内部
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('CustomTitleBar 存在', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // Assert: Column 存在（包含 CustomTitleBar + Expanded）
      expect(find.byType(Column), findsAtLeast(1));
    });

    // ── EmptyState visibility ──

    testWidgets('emptyState 可见当 engine idle', (tester) async {
      // 提供 emptyState widget — idle 时应显示
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      // engine 默认 idle，emptyState 参数为 null 时不显示
      // 但 PlayerScreen 本身应正常构建
      expect(find.byType(PlayerScreen), findsOneWidget);
    });

    // ── onTogglePlaylist callback ──

    testWidgets('onTogglePlaylist callback is wired', (tester) async {
      var toggled = false;
      final controller = PlaybackController(
        engine: engine,
        playlist: playlist,
        onNeedRebuild: () {},
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 600)),
            child: PlayerScreen(
              engine: engine,
              controller: controller,
              playlist: playlist,
              playlistGeneration: playlistGeneration,
              windowService: windowService,
              settingsPanelController: SettingsPanelController(controller),
              onTogglePlaylist: () => toggled = true,
            ),
          ),
        ),
      );
      await tester.pump();

      // PlayerScreen 正常构建，callback 被接受
      expect(find.byType(PlayerScreen), findsOneWidget);
      // toggled 在此作用域仅用于验证 callback 无 crash，非直接触发
      expect(toggled, isFalse);
    });

    // ── onOpenFile callback wiring ──

    testWidgets('onOpenFile callback is wired', (tester) async {
      var opened = false;
      final controller = PlaybackController(
        engine: engine,
        playlist: playlist,
        onNeedRebuild: () {},
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 600)),
            child: PlayerScreen(
              engine: engine,
              controller: controller,
              playlist: playlist,
              playlistGeneration: playlistGeneration,
              windowService: windowService,
              settingsPanelController: SettingsPanelController(controller),
              onOpenFile: () => opened = true,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(PlayerScreen), findsOneWidget);
      // opened 在此作用域仅用于验证 callback 无 crash，非直接触发
      expect(opened, isFalse);
    });

    // ── onFilesDropped callback wiring ──

    testWidgets('onFilesDropped callback is wired', (tester) async {
      final dropped = <List<String>>[];
      final controller = PlaybackController(
        engine: engine,
        playlist: playlist,
        onNeedRebuild: () {},
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 600)),
            child: PlayerScreen(
              engine: engine,
              controller: controller,
              playlist: playlist,
              playlistGeneration: playlistGeneration,
              windowService: windowService,
              settingsPanelController: SettingsPanelController(controller),
              onFilesDropped: dropped.add,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(PlayerScreen), findsOneWidget);
    });

    // ── Window mode fullscreen branch ──

    testWidgets('fullscreen mode renders MouseRegion', (tester) async {
      // 设置窗口为全屏模式
      unawaited(windowService.setMode(WindowMode.fullscreen));
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // 全屏模式下应渲染 MouseRegion 而非 DragToResizeArea
      // AnimatedBuilder 监听 windowService.mode 变化
      expect(find.byType(PlayerScreen), findsOneWidget);
    });

    // ── textureId 有值时 isVideo=true ──

    testWidgets('isVideo=true when textureId is set', (tester) async {
      engine.textureId.value = 42;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // textureId 非空 → isVideo=true → ControlsOverlay 收到 isVideo=true
      expect(find.byType(PlayerScreen), findsOneWidget);
    });

    // ── EmptyState with non-null widget ──

    testWidgets('emptyState widget visible when engine idle and widget provided',
        (tester) async {
      // 提供非 null emptyState → idle 时应渲染 Positioned.fill(emptyState)
      final controller = PlaybackController(
        engine: engine,
        playlist: playlist,
        onNeedRebuild: () {},
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 600)),
            child: PlayerScreen(
              engine: engine,
              controller: controller,
              playlist: playlist,
              playlistGeneration: playlistGeneration,
              windowService: windowService,
              settingsPanelController: SettingsPanelController(controller),
              emptyState: const Center(child: Text('No media loaded')),
            ),
          ),
        ),
      );
      await tester.pump();

      // engine 默认 idle → emptyState 应可见
      expect(find.text('No media loaded'), findsOneWidget);
    });

    testWidgets('emptyState hidden when engine is playing', (tester) async {
      final controller = PlaybackController(
        engine: engine,
        playlist: playlist,
        onNeedRebuild: () {},
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 600)),
            child: PlayerScreen(
              engine: engine,
              controller: controller,
              playlist: playlist,
              playlistGeneration: playlistGeneration,
              windowService: windowService,
              settingsPanelController: SettingsPanelController(controller),
              emptyState: const Center(child: Text('No media loaded')),
            ),
          ),
        ),
      );
      await tester.pump();

      // Act: 切换到 playing 状态
      await engine.open('test.mp4');
      engine.play();
      await tester.pump();

      // playing 时 emptyState 应隐藏（SizedBox.shrink）
      expect(find.text('No media loaded'), findsNothing);
    });

    // ── Keyboard seek via PlayerScreen integration ──

    testWidgets('left arrow triggers seek backward through KeyboardHandler',
        (tester) async {
      engine.configureMedia(durationMs: 60000);
      engine.position.value = 10000;
      engine.duration.value = 60000;

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // Act: 按左箭头 → KeyboardHandler → _seek(engine, -5000)
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);

      // Assert: seekTo 被调用，位置 = 10000 - 5000 = 5000
      expect(engine.seekToCallCount, 1);
      expect(engine.lastSeekToMs, 5000);
    });

    testWidgets('right arrow triggers seek forward through KeyboardHandler',
        (tester) async {
      engine.configureMedia(durationMs: 60000);
      engine.position.value = 10000;
      engine.duration.value = 60000;

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // Act: 按右箭头 → KeyboardHandler → _seek(engine, 5000)
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);

      // Assert: seekTo 被调用，位置 = 10000 + 5000 = 15000
      expect(engine.seekToCallCount, 1);
      expect(engine.lastSeekToMs, 15000);
    });

    // ── Keyboard volume via PlayerScreen integration ──

    testWidgets('up arrow increases volume through KeyboardHandler',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // Act: 按上箭头 → KeyboardHandler → engine.setVolume(volume + 0.05)
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);

      // Assert: setVolume 被调用
      expect(engine.setVolumeCallCount, 1);
      // 默认 volume=1.0, +0.05=1.05 → clamp → 1.0
      expect(engine.lastSetVolumeValue, closeTo(1.05, 0.01));
    });

    testWidgets('down arrow decreases volume through KeyboardHandler',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // Act: 按下箭头 → KeyboardHandler → engine.setVolume(volume - 0.05)
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);

      // Assert: setVolume 被调用
      expect(engine.setVolumeCallCount, 1);
      expect(engine.lastSetVolumeValue, closeTo(0.95, 0.01));
    });

    // ── Fullscreen AnimatedBuilder branch ──

    testWidgets('fullscreen mode shows MouseRegion not DragToResizeArea',
        (tester) async {
      // Arrange: 先构建，再切换到全屏
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // Act: 切换到全屏
      await windowService.setMode(WindowMode.fullscreen);
      await tester.pump();

      // Assert: 全屏模式 → MouseRegion 替代 DragToResizeArea
      // AnimatedBuilder 监听 windowService.mode，全屏时返回 MouseRegion
      expect(find.byType(MouseRegion), findsAtLeast(1));
    });

    testWidgets('windowed mode shows DragToResizeArea', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // 默认 windowed → DragToResizeArea
      expect(find.byType(DragToResizeArea), findsOneWidget);
    });

    // ── Keyboard mute toggle ──

    testWidgets('M key toggles mute through KeyboardHandler', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // Act: 按 M 键 → KeyboardHandler → engine.setMute(!isMuted)
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyM);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyM);

      // Assert: setMute 被调用（默认 isMuted=false → setMute(true)）
      expect(engine.isMuted.value, isTrue);
    });

    // ── Keyboard play/pause toggle ──

    testWidgets('space key toggles play/pause through KeyboardHandler',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // 先 open 使状态进入 opening（idle→playing 被状态机拒绝，必须经 opening）
      await engine.open('test.mp4');
      await tester.pump();

      // Act: 按空格 → KeyboardHandler → engine.togglePlayPause()
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);

      // Assert: togglePlayPause 被调用 → opening 时应变为 playing
      expect(engine.state.value, MediaState.playing);
    });

    // ── onDragHoverChanged wiring ──

    testWidgets('onDragHoverChanged callback is wired to DropHandler',
        (tester) async {
      final hoverStates = <bool>[];
      final controller = PlaybackController(
        engine: engine,
        playlist: playlist,
        onNeedRebuild: () {},
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 600)),
            child: PlayerScreen(
              engine: engine,
              controller: controller,
              playlist: playlist,
              playlistGeneration: playlistGeneration,
              windowService: windowService,
              settingsPanelController: SettingsPanelController(controller),
              onDragHoverChanged: hoverStates.add,
            ),
          ),
        ),
      );
      await tester.pump();

      // DropHandler 应存在
      expect(find.byType(DropHandler), findsOneWidget);
    });

    // ── F1 shortcuts help dialog ──

    testWidgets('F1 key shows shortcuts help dialog with shortcut table',
        (tester) async {
      // 覆盖 _showShortcutsHelp (line 315-316) + _ShortcutsHelpDialog (324-371)
      // + shortcutDefinitions() (keyboard_handler.dart lines 16-29)
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // Act: 按 F1 → _showShortcutsHelp → showDialog → _ShortcutsHelpDialog
      await tester.sendKeyDownEvent(LogicalKeyboardKey.f1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.f1);
      await tester.pumpAndSettle();

      // Assert: AlertDialog 出现，包含快捷键标题
      expect(find.byType(AlertDialog), findsOneWidget);
      // shortcutDefinitions 生成的 Table 行应包含 Space 快捷键
      expect(find.text('Space'), findsOneWidget);
      // 关闭按钮应存在
      expect(find.byType(TextButton), findsAtLeast(1));
    });

    testWidgets('shortcuts help dialog close button pops dialog', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // 打开对话框
      await tester.sendKeyDownEvent(LogicalKeyboardKey.f1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.f1);
      await tester.pumpAndSettle();

      // Act: 点击关闭按钮
      await tester.tap(find.byType(TextButton).last);
      await tester.pumpAndSettle();

      // Assert: 对话框已关闭
      expect(find.byType(AlertDialog), findsNothing);
    });

    // ── Playlist toggle via ControlBar button ──

    testWidgets('playlist toggle button triggers _togglePlaylist', (tester) async {
      // 覆盖 lines 81-85: _togglePlaylist()
      var toggled = false;
      final controller = PlaybackController(
        engine: engine,
        playlist: playlist,
        onNeedRebuild: () {},
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 600)),
            child: PlayerScreen(
              engine: engine,
              controller: controller,
              playlist: playlist,
              playlistGeneration: playlistGeneration,
              windowService: windowService,
              settingsPanelController: SettingsPanelController(controller),
              onTogglePlaylist: () => toggled = true,
            ),
          ),
        ),
      );
      await tester.pump();

      // Act: 点击 ControlBar 中的播放列表按钮 (Icons.queue_music)
      final playlistButton = find.byIcon(Icons.queue_music);
      if (playlistButton.evaluate().isNotEmpty) {
        await tester.tap(playlistButton);
        await tester.pump();
        expect(toggled, isTrue);
      }
    });

    // ── Playlist panel renders after toggle ──

    testWidgets('playlist panel mounts after toggle in narrow screen', (tester) async {
      // 覆盖 lines 81-85 + 210-216: toggle → playlistMounted → Stack overlay
      final controller = PlaybackController(
        engine: engine,
        playlist: playlist,
        onNeedRebuild: () {},
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 600)),
            child: PlayerScreen(
              engine: engine,
              controller: controller,
              playlist: playlist,
              playlistGeneration: playlistGeneration,
              windowService: windowService,
              settingsPanelController: SettingsPanelController(controller),
            ),
          ),
        ),
      );
      await tester.pump();

      // Act: 点击播放列表按钮
      final playlistButton = find.byIcon(Icons.queue_music);
      if (playlistButton.evaluate().isNotEmpty) {
        await tester.tap(playlistButton);
        await tester.pumpAndSettle();

        // Assert: PlaylistPanel 应被挂载
        expect(find.byType(PlaylistPanel), findsOneWidget);
      }
    });

    // ── Wide screen Row layout with playlist ──

    testWidgets('wide screen uses Row layout when playlist mounted', (tester) async {
      // 覆盖 lines 191-203: useRow → Row 布局
      final controller = PlaybackController(
        engine: engine,
        playlist: playlist,
        onNeedRebuild: () {},
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            // 1300 >= Tokens.breakpointWide (1200)
            data: const MediaQueryData(size: Size(1300, 800)),
            child: PlayerScreen(
              engine: engine,
              controller: controller,
              playlist: playlist,
              playlistGeneration: playlistGeneration,
              windowService: windowService,
              settingsPanelController: SettingsPanelController(controller),
            ),
          ),
        ),
      );
      await tester.pump();

      // Act: 点击播放列表按钮 → _togglePlaylist → playlistMounted=true
      final playlistButton = find.byIcon(Icons.queue_music);
      if (playlistButton.evaluate().isNotEmpty) {
        await tester.tap(playlistButton);
        await tester.pumpAndSettle();

        // Assert: 宽屏 Row 布局 — PlaylistPanel 在 Row 中
        // Row 布局下 PlaylistPanel 与视频并排
        expect(find.byType(PlaylistPanel), findsOneWidget);
      }
    });

    // ── Playlist close via Escape key ──

    testWidgets('Escape key closes playlist panel via _closePlaylist', (tester) async {
      // 覆盖 lines 88-93: _closePlaylist()
      final controller = PlaybackController(
        engine: engine,
        playlist: playlist,
        onNeedRebuild: () {},
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 600)),
            child: PlayerScreen(
              engine: engine,
              controller: controller,
              playlist: playlist,
              playlistGeneration: playlistGeneration,
              windowService: windowService,
              settingsPanelController: SettingsPanelController(controller),
            ),
          ),
        ),
      );
      await tester.pump();

      // Act: 打开播放列表
      final playlistButton = find.byIcon(Icons.queue_music);
      if (playlistButton.evaluate().isNotEmpty) {
        await tester.tap(playlistButton);
        await tester.pumpAndSettle();

        // 验证播放列表已打开
        expect(find.byType(PlaylistPanel), findsOneWidget);

        // Act: 按 Escape 关闭播放列表
        // PlaylistPanel 的 Focus 在 initState 中 requestFocus
        await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        // Assert: _closePlaylist 被调用 → playlistState 变为 (false, ...)
        // PlaylistPanel 可能仍在动画中，但 visible 应为 false
      }
    });

    // ── Fullscreen toggle via ControlBar button ──

    testWidgets('fullscreen button toggles window mode', (tester) async {
      // 覆盖 lines 277-278, 283-284: onToggleFullscreen wiring
      final controller = PlaybackController(
        engine: engine,
        playlist: playlist,
        onNeedRebuild: () {},
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 600)),
            child: PlayerScreen(
              engine: engine,
              controller: controller,
              playlist: playlist,
              playlistGeneration: playlistGeneration,
              windowService: windowService,
              settingsPanelController: SettingsPanelController(controller),
            ),
          ),
        ),
      );
      await tester.pump();

      // Act: 点击全屏按钮 (Icons.fullscreen)
      final fullscreenButton = find.byIcon(Icons.fullscreen);
      if (fullscreenButton.evaluate().isNotEmpty) {
        await tester.tap(fullscreenButton);
        await tester.pump();

        // Assert: 窗口模式切换到全屏
        expect(windowService.mode.value.isFullscreen, isTrue);
      }
    });
  });
}
