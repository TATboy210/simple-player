import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/services/playback_controller.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_panel_controller.dart';
import 'package:simple_player_flutter/ui/player/player_screen.dart';

import '../../helpers/fake_engine.dart';
import '../../helpers/fake_video_controls.dart';
import '../../helpers/fake_window_service.dart';

const _resizeSemanticsAnchor =
    'player content remains accessible while resizing';
const _playerControlsSemanticsAnchor = 'Playback Progress';

bool _hasSemanticsLabel(WidgetTester tester, String label) {
  final accessibleNodes = tester.semantics.simulatedAccessibilityTraversal();
  return accessibleNodes.any(
    (SemanticsNode node) => node.getSemanticsData().label == label,
  );
}

void _expectCorePlayerSemantics(WidgetTester tester) {
  expect(
    tester.getSemantics(find.bySemanticsLabel(_playerControlsSemanticsAnchor)),
    matchesSemantics(
      label: _playerControlsSemanticsAnchor,
      value: '0%',
      isSlider: true,
      hasTapAction: true,
      hasScrollLeftAction: true,
      hasScrollRightAction: true,
    ),
  );
  expect(
    tester.getSemantics(find.bySemanticsLabel('Play')),
    matchesSemantics(
      isButton: true,
      hasEnabledState: true,
      isEnabled: true,
      hasToggledState: true,
      isToggled: false,
      hasTapAction: true,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // PlaybackController.dispose 会异步持久化；使用内存偏好并保持日志器可用，
    // 让 teardown 中的延迟错误仍被正常记录，而不是因测试组合根缺失再抛异常。
    SharedPreferences.setMockInitialValues(<String, Object>{});
    KernelLoggerImpl.init();
  });

  testWidgets(
    'keeps player semantics and video surface attached throughout resize sessions',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      final engine = FakeEngine();
      final controller = PlaybackController(engine: engine);
      final settingsPanelController = SettingsPanelController(controller);
      final windowService = FakeWindowService();
      final videoControls = FakeVideoControlsPort();
      final videoSurfaceKey = GlobalKey();

      addTearDown(() async {
        // 先让 PlayerScreen 脱树，使其移除 resize listener 和内部延迟 Timer。
        await tester.pumpWidget(const SizedBox.shrink());
        settingsPanelController.dispose();
        controller.dispose();
        windowService.dispose();
        videoControls.dispose();
        engine.dispose();
      });

      try {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PlayerScreen(
              engine: engine,
              mediaKitController: null,
              controller: controller,
              windowService: windowService,
              settingsPanelController: settingsPanelController,
              videoSurfaceBuilder: (_) => SizedBox.expand(key: videoSurfaceKey),
              testVideoControls: videoControls,
              emptyState: Semantics(
                container: true,
                label: _resizeSemanticsAnchor,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(_hasSemanticsLabel(tester, _resizeSemanticsAnchor), isTrue);
        _expectCorePlayerSemantics(tester);
        final initialSurfaceElement = videoSurfaceKey.currentContext;
        expect(initialSurfaceElement, isNotNull);

        // resize 只应调整渲染策略；视频 surface 和核心控件语义不能重挂载。
        for (var session = 0; session < 3; session++) {
          windowService.isResizing.value = true;
          await tester.pump();
          expect(_hasSemanticsLabel(tester, _resizeSemanticsAnchor), isTrue);
          _expectCorePlayerSemantics(tester);
          expect(videoSurfaceKey.currentContext, same(initialSurfaceElement));

          windowService.isResizing.value = false;
          await tester.pump();
          expect(_hasSemanticsLabel(tester, _resizeSemanticsAnchor), isTrue);
          _expectCorePlayerSemantics(tester);
          expect(videoSurfaceKey.currentContext, same(initialSurfaceElement));
        }
      } finally {
        // testWidgets 会在普通 teardown 前检查语义句柄，因此必须在主体返回前释放。
        semanticsHandle.dispose();
      }
    },
  );

  testWidgets(
    'keeps settings state, player semantics, and video surface attached across resize',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      final engine = FakeEngine();
      final controller = PlaybackController(engine: engine);
      final settingsPanelController = SettingsPanelController(controller);
      final windowService = FakeWindowService();
      final videoControls = FakeVideoControlsPort();
      final videoSurfaceKey = GlobalKey();

      addTearDown(() async {
        // 先脱树，再释放监听器依赖，避免延迟回调访问已释放的 notifier。
        await tester.pumpWidget(const SizedBox.shrink());
        settingsPanelController.dispose();
        controller.dispose();
        windowService.dispose();
        videoControls.dispose();
        engine.dispose();
      });

      try {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PlayerScreen(
              engine: engine,
              mediaKitController: null,
              controller: controller,
              windowService: windowService,
              settingsPanelController: settingsPanelController,
              videoSurfaceBuilder: (_) => SizedBox.expand(key: videoSurfaceKey),
              testVideoControls: videoControls,
              emptyState: Semantics(
                container: true,
                label: _resizeSemanticsAnchor,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
        await tester.pump();

        final initialSurfaceElement = videoSurfaceKey.currentContext;
        expect(initialSurfaceElement, isNotNull);
        expect(settingsPanelController.state.isOpen.value, isFalse);
        _expectCorePlayerSemantics(tester);

        // 当前设置入口由控制器状态表达；测试不依赖已移除的 shell widget。
        settingsPanelController.open();
        await tester.pump();
        expect(settingsPanelController.state.isOpen.value, isTrue);

        // 打开设置状态期间，resize 只能降级渲染细节，不能替换视频 surface 或语义。
        windowService.isResizing.value = true;
        await tester.pump();
        expect(settingsPanelController.state.isOpen.value, isTrue);
        _expectCorePlayerSemantics(tester);
        expect(videoSurfaceKey.currentContext, same(initialSurfaceElement));

        windowService.isResizing.value = false;
        await tester.pump();
        expect(settingsPanelController.state.isOpen.value, isTrue);
        _expectCorePlayerSemantics(tester);
        expect(videoSurfaceKey.currentContext, same(initialSurfaceElement));

        settingsPanelController.close();
        await tester.pump();
        expect(settingsPanelController.state.isOpen.value, isFalse);
        _expectCorePlayerSemantics(tester);
        expect(videoSurfaceKey.currentContext, same(initialSurfaceElement));
      } finally {
        // flutter_test 在普通 teardown 前检查语义句柄，因此必须在主体返回前释放。
        semanticsHandle.dispose();
      }
    },
  );
}
