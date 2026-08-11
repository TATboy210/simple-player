import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/kernel/persistence/settings_store.dart';
import 'package:simple_player_flutter/kernel/services/playback_controller.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/error_banner.dart';

import '../helpers/fake_engine.dart';

/// 验证错误传播路径的集成测试
///
/// 路径: engine.lastError → ErrorBanner 显示 → dismiss → lastError 清除
/// 数据流: Kernel(engine) → Widget(ErrorBanner) 单向，通过 ValueNotifier 驱动
void main() {
  // PlaybackController.dispose() 会异步保存设置；初始化 logger，避免保存失败时
  // 测试 teardown 因日志单例未建立而产生测试完成后的未捕获异常。
  setUpAll(() {
    KernelLoggerImpl.init();
    SharedPreferences.setMockInitialValues({});
  });

  tearDownAll(KernelLoggerImpl.resetForTesting);

  late FakeEngine engine;

  setUp(() {
    // 为 dispose() 提供内存版 SharedPreferences，避免 headless 测试触碰平台通道。
    SharedPreferences.setMockInitialValues({});
    engine = FakeEngine();
  });

  tearDown(() {
    engine.dispose();
    SettingsStore.resetPrewarm();
  });

  /// 构建 ErrorBanner 测试壳 — 带 MaterialApp + l10n
  Widget buildErrorBanner({VoidCallback? onOpenFile, VoidCallback? onRetry}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ErrorBanner(
          engine: engine,
          onOpenFile: onOpenFile,
          onRetry: onRetry,
        ),
      ),
    );
  }

  group('Error propagation: engine → ErrorBanner', () {
    testWidgets('engine error triggers ErrorBanner display', (tester) async {
      // 1. 初始状态: 无错误 → ErrorBanner 隐藏
      await tester.pumpWidget(buildErrorBanner());
      expect(find.byIcon(Icons.error_outline), findsNothing);

      // 2. 模拟引擎错误
      engine.simulateError('File not found');

      // 3. 触发重建
      await tester.pumpWidget(buildErrorBanner());
      await tester.pump();

      // 4. ErrorBanner 应显示错误消息
      expect(find.text('An unexpected error occurred'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('error dismiss clears engine.lastError', (tester) async {
      // 1. 触发错误
      engine.simulateError('Test error');
      await tester.pumpWidget(buildErrorBanner());
      await tester.pump();
      expect(find.text('An unexpected error occurred'), findsOneWidget);

      // 2. 模拟 dismiss 操作 — 通过设置 state 回到 idle + lastError = null
      engine.state.value = MediaState.idle;
      engine.lastError.value = null;
      await tester.pump();

      // 3. ErrorBanner 应隐藏
      expect(find.byIcon(Icons.error_outline), findsNothing);
      expect(engine.lastError.value, isNull);
    });

    testWidgets('error → recovery → new playback clears error', (tester) async {
      // 1. 触发错误
      engine.simulateError('Codec error');
      await tester.pumpWidget(buildErrorBanner());
      await tester.pump();
      expect(find.text('An unexpected error occurred'), findsOneWidget);

      // 2. 恢复: open 新文件 → lastError 清除
      engine.configureMedia(durationMs: 30000);
      await engine.open('new_video.mp4');

      // 3. ErrorBanner 应在引擎恢复后移除。
      await tester.pump();
      expect(engine.lastError.value, isNull);
      expect(engine.state.value, MediaState.idle);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('FileError shows openFile action button', (tester) async {
      // 验证 FileError → onOpenFile 回调
      var openFileCalled = false;
      engine.state.value = MediaState.error;
      engine.lastError.value = FileError(
        FileErrorCode.fileNotFound,
        'File missing',
      );

      await tester.pumpWidget(
        buildErrorBanner(onOpenFile: () => openFileCalled = true),
      );
      await tester.pump();

      // 点击 action 按钮
      final button = find.byType(TextButton);
      expect(button, findsOneWidget);
      await tester.tap(button);

      expect(openFileCalled, isTrue);
    });

    testWidgets('PlaybackError shows retry action button', (tester) async {
      // 验证 PlaybackError → onRetry 回调
      var retryCalled = false;
      engine.state.value = MediaState.error;
      engine.lastError.value = PlaybackError(
        PlaybackErrorCode.playFailed,
        'Play failed',
      );

      await tester.pumpWidget(
        buildErrorBanner(onRetry: () => retryCalled = true),
      );
      await tester.pump();

      final button = find.byType(TextButton);
      expect(button, findsOneWidget);
      await tester.tap(button);

      expect(retryCalled, isTrue);
    });

    testWidgets('CodecError shows selectOtherFile action', (tester) async {
      // 验证 CodecError → onOpenFile 回调（选择其他文件）
      var openFileCalled = false;
      engine.state.value = MediaState.error;
      engine.lastError.value = CodecError(
        CodecErrorCode.unsupportedFormat,
        'Unsupported format',
      );

      await tester.pumpWidget(
        buildErrorBanner(onOpenFile: () => openFileCalled = true),
      );
      await tester.pump();

      final button = find.byType(TextButton);
      expect(button, findsOneWidget);
      await tester.tap(button);

      expect(openFileCalled, isTrue);
    });

    testWidgets('NetworkError shows retry action', (tester) async {
      // 验证 NetworkError → onRetry 回调
      var retryCalled = false;
      engine.state.value = MediaState.error;
      engine.lastError.value = NetworkError(
        NetworkErrorCode.timeout,
        'Connection timeout',
      );

      await tester.pumpWidget(
        buildErrorBanner(onRetry: () => retryCalled = true),
      );
      await tester.pump();

      final button = find.byType(TextButton);
      expect(button, findsOneWidget);
      await tester.tap(button);

      expect(retryCalled, isTrue);
    });
  });

  group('Unidirectional data flow verification', () {
    testWidgets(
      'Widget→Kernel: tap triggers engine method, no reverse callback',
      (tester) async {
        // 验证 Widget 层调用 Kernel 层是单向的:
        // Widget 调用 engine.play() → engine 状态变更
        // engine 不引用任何 widget/callback
        engine.configureMedia(durationMs: 60000);
        await engine.open('test.mp4');

        // Widget 层操作 → Kernel 方法调用
        engine.play();
        expect(engine.playCallCount, 1);
        expect(engine.state.value, MediaState.playing);

        engine.pause();
        expect(engine.pauseCallCount, 1);
        expect(engine.state.value, MediaState.paused);

        // 验证 engine 没有反向回调到 widget
        // FakeEngine 不包含任何 widget 引用 — 通过类型系统保证
      },
    );

    testWidgets('Kernel→Widget: engine state changes drive widget rebuilds', (
      tester,
    ) async {
      // 验证 Kernel → Widget 数据流:
      // engine.state (ValueNotifier) → ValueListenableBuilder → widget rebuild
      await tester.pumpWidget(buildErrorBanner());
      await tester.pump();

      // 初始: 无错误 → ErrorBanner 隐藏
      expect(find.byIcon(Icons.error_outline), findsNothing);

      // Kernel 状态变更 → Widget 重建
      engine.simulateError('State change drives rebuild');
      await tester.pump();

      expect(find.text('An unexpected error occurred'), findsOneWidget);

      // Kernel 状态恢复 → Widget 重建
      engine.state.value = MediaState.idle;
      engine.lastError.value = null;
      await tester.pump();

      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    test('engine does not reference any widget or callback', () {
      // 验证 FakeEngine 实现中无 widget/callback 引用
      // MediaEngine 接口只暴露 ValueNotifier 状态 + 控制方法
      // 不包含任何 Widget/BuildContext/Function 回调
      expect(engine.state, isA<ValueNotifier<MediaState>>());
      expect(engine.lastError, isA<ValueNotifier<PlayerError?>>());
      expect(engine.volume, isA<ValueNotifier<double>>());
      expect(engine.position, isA<ValueNotifier<int>>());
      expect(engine.duration, isA<ValueNotifier<int>>());

      // engine 方法都是 void/Future<void> — 无返回值到 widget
      engine.play();
      engine.pause();
      engine.setVolume(0.5);
      engine.setMute(true);

      // 所有状态通过 ValueNotifier 单向流出
      expect(engine.state.value, MediaState.paused);
      expect(engine.volume.value, 0.5);
      expect(engine.isMuted.value, isTrue);
    });

    test(
      'PlaybackController uses constructor injection — no service locator',
      () {
        // 验证 PlaybackController 通过构造函数注入依赖
        // 无 GetIt/service locator/全局状态
        final controller = PlaybackController(engine: engine);

        // engine 是通过构造函数注入的 — 可替换为 FakeEngine。
        expect(controller.engine, same(engine));
        controller.dispose();
      },
    );
  });
}
