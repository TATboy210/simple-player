/// FvpEngine 三步错误模式测试 (ERR-03)
///
/// 验证 ErrorContext 在 PlayerError 各子类构造时正确携带，
/// 以及 ErrorContext.toMap() 序列化完整性。
///
/// 注: FvpEngine 需要 mdk.Player (FFI)，无法在 headless 环境实例化。
/// 三步模式的结构正确性通过此文件中的 ErrorContext 构造测试 + flutter analyze 验证。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';

void main() {
  group('ErrorContext construction (three-step pattern foundation)', () {
    test('PlaybackError with ErrorContext carries all fields', () {
      final cause = Exception('test cause');
      final ctx = ErrorContext(
        action: 'play',
        module: 'FvpEngine',
      );
      final error = PlaybackError(
        PlaybackErrorCode.playFailed,
        '播放失败: test',
        cause,
        ctx,
      );

      expect(error.context, isNotNull);
      expect(error.context?.action, 'play');
      expect(error.context?.module, 'FvpEngine');
      expect(error.context?.timestamp, isA<DateTime>());
      expect(error.cause, cause);
      expect(error.message, '播放失败: test');
    });

    test('FileError with ErrorContext carries path and generation', () {
      final ctx = ErrorContext(
        action: 'open',
        generation: 42,
        path: 'C:/test/video.mp4',
        module: 'FvpEngine',
      );
      final error = FileError(
        FileErrorCode.pathEmpty,
        '文件路径为空',
        null,
        ctx,
      );

      expect(error.context?.action, 'open');
      expect(error.context?.generation, 42);
      expect(error.context?.path, 'C:/test/video.mp4');
      expect(error.context?.module, 'FvpEngine');
    });

    test('NetworkError with ErrorContext for open() catch point', () {
      final ctx = ErrorContext(
        action: 'open',
        generation: 7,
        path: 'https://example.com/stream.mp4',
        module: 'FvpEngine',
      );
      final error = NetworkError(
        NetworkErrorCode.timeout,
        '无法打开: stream.mp4',
        Exception('timeout'),
        ctx,
      );

      expect(error.context?.action, 'open');
      expect(error.context?.generation, 7);
      expect(error.context?.path, 'https://example.com/stream.mp4');
      expect(error.isFatal, false); // timeout is recoverable
    });

    test('PlaybackError.seekFailed with ErrorContext for seekTo catch point', () {
      final ctx = ErrorContext(action: 'seek', module: 'FvpEngine');
      final error = PlaybackError(
        PlaybackErrorCode.seekFailed,
        '跳转失败: test',
        Exception('seek error'),
        ctx,
      );

      expect(error.context?.action, 'seek');
      expect(error.context?.module, 'FvpEngine');
      expect(error.isFatal, false); // seekFailed is recoverable
      expect(error.l10nKey, 'error.playback.seekFailed');
    });

    test('PlaybackError without ErrorContext is backward compatible', () {
      // 旧代码不传 context 仍可正常工作
      final error = PlaybackError(
        PlaybackErrorCode.playFailed,
        '播放失败',
        Exception('test'),
      );

      expect(error.context, isNull);
      expect(error.message, '播放失败');
      expect(error.isFatal, false);
    });

    test('ErrorContext.toMap() serializes all non-null fields', () {
      final ctx = ErrorContext(
        action: 'open',
        generation: 3,
        path: 'C:/video.mp4',
        module: 'FvpEngine',
      );
      final map = ctx.toMap();

      expect(map['action'], 'open');
      expect(map['generation'], 3);
      // 路径脱敏：toMap() 只保留文件名，不泄露完整路径
      expect(map['path'], 'video.mp4');
      expect(map['module'], 'FvpEngine');
      expect(map['timestamp'], isA<String>());
      // callbackStackTrace is null → not in map
      expect(map.containsKey('callbackStackTrace'), false);
    });

    test('ErrorContext.toMap() includes callbackStackTrace when set', () {
      final st = StackTrace.current;
      final ctx = ErrorContext(
        action: 'mdk.onStateChanged',
        module: 'FvpCallbackHandler',
        callbackStackTrace: st,
      );
      final map = ctx.toMap();

      expect(map['callbackStackTrace'], isA<String>());
      expect(map['callbackStackTrace'], st.toString());
    });

    test('ErrorContext timestamp defaults to DateTime.now()', () {
      final before = DateTime.now();
      final ctx = ErrorContext(action: 'test');
      final after = DateTime.now();

      expect(ctx.timestamp.isAfter(before) || ctx.timestamp.isAtSameMomentAs(before), true);
      expect(ctx.timestamp.isBefore(after) || ctx.timestamp.isAtSameMomentAs(after), true);
    });

    test('ErrorContext timestamp can be injected for testing', () {
      final fixed = DateTime(2026, 7, 20, 12, 0, 0);
      final ctx = ErrorContext(action: 'test', timestamp: fixed);

      expect(ctx.timestamp, fixed);
    });
  });

  group('PlayerError isFatal / l10nKey with ErrorContext', () {
    test('FileError.pathEmpty is recoverable', () {
      final error = FileError(
        FileErrorCode.pathEmpty,
        '空路径',
        null,
        ErrorContext(action: 'open', module: 'FvpEngine'),
      );
      expect(error.isFatal, false);
      expect(error.l10nKey, 'error.file.pathEmpty');
    });

    test('PlaybackError.textureFailed is fatal', () {
      final error = PlaybackError(
        PlaybackErrorCode.textureFailed,
        '纹理失败',
        null,
        ErrorContext(action: 'texture', module: 'MediaOpener'),
      );
      expect(error.isFatal, true);
      expect(error.l10nKey, 'error.playback.textureFailed');
    });

    test('NetworkError.timeout is recoverable', () {
      final error = NetworkError(
        NetworkErrorCode.timeout,
        '超时',
        null,
        ErrorContext(action: 'prepare', module: 'MediaOpener'),
      );
      expect(error.isFatal, false);
      expect(error.l10nKey, 'error.network.timeout');
    });
  });
}
