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

    // ERR-04: ErrorBanner uses l10nKey → AppLocalizations for display text.
    // simulateError() creates UnknownError → l10nKey 'error.unknown' →
    // English ARB value: 'An unexpected error occurred'
    testWidgets('displays localized error message when in error state', (
      tester,
    ) async {
      engine.simulateError('raw message ignored by l10nKey');
      await tester.pumpWidget(buildSubject());

      // l10nKey 'error.unknown' → ARB English value
      expect(find.text('An unexpected error occurred'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    // ERR-04: FileError → l10nKey 'error.file.fileNotFound' → ARB 'File not found'
    testWidgets('shows action button for file error', (tester) async {
      var opened = false;
      engine.state.value = MediaState.error;
      engine.lastError.value = FileError(
        FileErrorCode.fileNotFound,
        'raw message ignored',
      );
      await tester.pumpWidget(buildSubject(onOpenFile: () => opened = true));

      // Localized message visible
      expect(find.text('File not found'), findsOneWidget);
      final button = find.byType(TextButton);
      expect(button, findsOneWidget);
      await tester.tap(button);
      expect(opened, isTrue);
    });

    // ERR-04: PlaybackError → l10nKey 'error.playback.playFailed' → ARB 'Playback failed'
    testWidgets('shows retry button for playback error', (tester) async {
      var retried = false;
      engine.state.value = MediaState.error;
      engine.lastError.value = PlaybackError(
        PlaybackErrorCode.playFailed,
        'raw message ignored',
      );
      await tester.pumpWidget(buildSubject(onRetry: () => retried = true));

      // Localized message visible
      expect(find.text('Playback failed'), findsOneWidget);
      final button = find.byType(TextButton);
      expect(button, findsOneWidget);
      await tester.tap(button);
      expect(retried, isTrue);
    });

    testWidgets('hides button when no callback provided', (tester) async {
      engine.state.value = MediaState.error;
      engine.lastError.value = UnknownError('raw message');
      await tester.pumpWidget(buildSubject());

      expect(find.byType(TextButton), findsNothing);
    });

    // ERR-04: CodecError → l10nKey 'error.codec.unsupportedFormat' → ARB 'Unsupported media format'
    testWidgets('shows codec error with selectOtherFile action', (
      tester,
    ) async {
      var opened = false;
      engine.state.value = MediaState.error;
      engine.lastError.value = CodecError(
        CodecErrorCode.unsupportedFormat,
        'raw message ignored',
      );
      await tester.pumpWidget(buildSubject(onOpenFile: () => opened = true));

      // Localized message visible
      expect(find.text('Unsupported media format'), findsOneWidget);
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
    testWidgets('routes textureFailed to onOpenFile with selectOtherFile label', (
      tester,
    ) async {
      var opened = false;
      var retried = false;
      engine.state.value = MediaState.error;
      engine.lastError.value = PlaybackError(
        PlaybackErrorCode.textureFailed,
        'raw message ignored',
      );
      await tester.pumpWidget(
        buildSubject(
          onOpenFile: () => opened = true,
          onRetry: () => retried = true,
        ),
      );

      // ERR-04: l10nKey 'error.playback.textureFailed' → ARB 'Video rendering failed'
      expect(find.text('Video rendering failed'), findsOneWidget);
      final button = find.byType(TextButton);
      expect(button, findsOneWidget);

      // Assert ②：按钮文案是"Select Other File"，不是"Retry"
      expect(find.text('Select Other File'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);

      // Act：点击按钮 → Assert ①：路由到 onOpenFile，绝不触发 onRetry
      await tester.tap(button);
      expect(opened, isTrue);
      expect(retried, isFalse);
    });

    // ERR-04: 每个错误子类型都显示正确的本地化消息
    group('l10nKey translation — each error type', () {
      testWidgets('FileError.pathEmpty shows localized message', (
        tester,
      ) async {
        engine.state.value = MediaState.error;
        engine.lastError.value = FileError(FileErrorCode.pathEmpty, 'raw');
        await tester.pumpWidget(buildSubject());
        expect(find.text('File path is empty'), findsOneWidget);
      });

      testWidgets('FileError.pathTraversal shows localized message', (
        tester,
      ) async {
        engine.state.value = MediaState.error;
        engine.lastError.value = FileError(FileErrorCode.pathTraversal, 'raw');
        await tester.pumpWidget(buildSubject());
        expect(find.text('Invalid file path'), findsOneWidget);
      });

      testWidgets('CodecError.decodeFailed shows localized message', (
        tester,
      ) async {
        engine.state.value = MediaState.error;
        engine.lastError.value = CodecError(CodecErrorCode.decodeFailed, 'raw');
        await tester.pumpWidget(buildSubject());
        expect(find.text('Failed to decode media'), findsOneWidget);
      });

      testWidgets('CodecError.codecUnsupported shows localized message', (
        tester,
      ) async {
        engine.state.value = MediaState.error;
        engine.lastError.value = CodecError(
          CodecErrorCode.codecUnsupported,
          'raw',
        );
        await tester.pumpWidget(buildSubject());
        expect(find.text('Codec not supported'), findsOneWidget);
      });

      testWidgets('PlaybackError.seekFailed shows localized message', (
        tester,
      ) async {
        engine.state.value = MediaState.error;
        engine.lastError.value = PlaybackError(
          PlaybackErrorCode.seekFailed,
          'raw',
        );
        await tester.pumpWidget(buildSubject());
        expect(find.text('Seek failed'), findsOneWidget);
      });

      testWidgets('PlaybackError.openTimeout shows localized message', (
        tester,
      ) async {
        engine.state.value = MediaState.error;
        engine.lastError.value = PlaybackError(
          PlaybackErrorCode.openTimeout,
          'raw',
        );
        await tester.pumpWidget(buildSubject());
        expect(find.text('Open timed out'), findsOneWidget);
      });

      testWidgets('NetworkError.timeout shows localized message', (
        tester,
      ) async {
        engine.state.value = MediaState.error;
        engine.lastError.value = NetworkError(NetworkErrorCode.timeout, 'raw');
        await tester.pumpWidget(buildSubject());
        expect(find.text('Network timeout'), findsOneWidget);
      });

      testWidgets('NetworkError.connectionLost shows localized message', (
        tester,
      ) async {
        engine.state.value = MediaState.error;
        engine.lastError.value = NetworkError(
          NetworkErrorCode.connectionLost,
          'raw',
        );
        await tester.pumpWidget(buildSubject());
        expect(find.text('Connection lost'), findsOneWidget);
      });

      testWidgets('UnknownError shows localized message', (tester) async {
        engine.state.value = MediaState.error;
        engine.lastError.value = UnknownError('raw');
        await tester.pumpWidget(buildSubject());
        expect(find.text('An unexpected error occurred'), findsOneWidget);
      });
    });
  });
}
