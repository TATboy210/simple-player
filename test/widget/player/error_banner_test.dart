import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/error_banner.dart';
import '../../helpers/fake_engine.dart';

void main() {
  group('ErrorBanner', () {
    late FakeEngine engine;

    setUp(() {
      engine = FakeEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    Widget buildSubject({VoidCallback? onOpenFile, VoidCallback? onRetry}) {
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

    testWidgets('shows nothing when state is not error', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('shows nothing when lastError is null', (tester) async {
      engine.state.value = MediaState.error;
      await tester.pumpWidget(buildSubject());
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('displays error message when in error state', (tester) async {
      engine.simulateError('File not found');
      await tester.pumpWidget(buildSubject());

      expect(find.text('File not found'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('shows action button for file error', (tester) async {
      var opened = false;
      engine.state.value = MediaState.error;
      engine.lastError.value = FileError(
        FileErrorCode.fileNotFound,
        'Cannot open',
      );
      await tester.pumpWidget(buildSubject(onOpenFile: () => opened = true));

      final button = find.byType(TextButton);
      expect(button, findsOneWidget);
      await tester.tap(button);
      expect(opened, isTrue);
    });

    testWidgets('shows retry button for playback error', (tester) async {
      var retried = false;
      engine.state.value = MediaState.error;
      engine.lastError.value = PlaybackError(
        PlaybackErrorCode.playFailed,
        'Playback failed',
      );
      await tester.pumpWidget(buildSubject(onRetry: () => retried = true));

      final button = find.byType(TextButton);
      expect(button, findsOneWidget);
      await tester.tap(button);
      expect(retried, isTrue);
    });

    testWidgets('hides button when no callback provided', (tester) async {
      engine.state.value = MediaState.error;
      engine.lastError.value = UnknownError('Unknown error');
      await tester.pumpWidget(buildSubject());

      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('shows codec error with selectOtherFile action', (
      tester,
    ) async {
      var opened = false;
      engine.state.value = MediaState.error;
      engine.lastError.value = CodecError(
        CodecErrorCode.unsupportedFormat,
        'Unsupported codec',
      );
      await tester.pumpWidget(buildSubject(onOpenFile: () => opened = true));

      expect(find.text('Unsupported codec'), findsOneWidget);
      final button = find.byType(TextButton);
      expect(button, findsOneWidget);
      await tester.tap(button);
      expect(opened, isTrue);
    });

    // textureFailed 走"选择其他文件"分支而非"重试"——这是 error_banner.dart
    // 用 when 守卫从 PlaybackError 通用分支拆出的子分支。
    // 实测：4K 视频 open 成功但 D3D11 黑屏，用户误判再点 → 第二次 open 在
    // 首次纹理资源未释放时 5s 超时 → textureFailed。盲目"重试"同一文件会
    // 触发资源竞争再超时，故引导"选择其他文件"跳出死循环。
    // 双重断言：①回调路由到 onOpenFile（非 onRetry）②文案"Select Other File"（非"Retry"）
    testWidgets(
      'routes textureFailed to onOpenFile with selectOtherFile label',
      (tester) async {
        var opened = false;
        var retried = false;
        engine.state.value = MediaState.error;
        engine.lastError.value = PlaybackError(
          PlaybackErrorCode.textureFailed,
          '纹理创建超时',
        );
        await tester.pumpWidget(
          buildSubject(
            onOpenFile: () => opened = true,
            onRetry: () => retried = true,
          ),
        );

        // Arrange 后：错误 message 可见
        expect(find.text('纹理创建超时'), findsOneWidget);
        final button = find.byType(TextButton);
        expect(button, findsOneWidget);

        // Assert ②：按钮文案是"Select Other File"，不是"Retry"
        expect(find.text('Select Other File'), findsOneWidget);
        expect(find.text('Retry'), findsNothing);

        // Act：点击按钮 → Assert ①：路由到 onOpenFile，绝不触发 onRetry
        await tester.tap(button);
        expect(opened, isTrue);
        expect(retried, isFalse);
      },
    );
  });
}
