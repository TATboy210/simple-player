import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/models/player_error.dart';

void main() {
  group('PlayerError sealed class', () {
    test('FileError carries code and message', () {
      final error = FileError(FileErrorCode.fileNotFound, '文件不存在');
      expect(error.code, FileErrorCode.fileNotFound);
      expect(error.message, '文件不存在');
      expect(error.toString(), 'FileError(fileNotFound): 文件不存在');
    });

    test('CodecError carries code and message', () {
      final error = CodecError(CodecErrorCode.unsupportedFormat, '无法解码');
      expect(error.code, CodecErrorCode.unsupportedFormat);
      expect(error.message, '无法解码');
    });

    test('PlaybackError carries code and message', () {
      final error = PlaybackError(PlaybackErrorCode.playFailed, '播放失败');
      expect(error.code, PlaybackErrorCode.playFailed);
      expect(error.message, '播放失败');
    });

    test('NetworkError carries code and message', () {
      final error = NetworkError(NetworkErrorCode.timeout, '网络超时');
      expect(error.code, NetworkErrorCode.timeout);
      expect(error.message, '网络超时');
    });

    test('UnknownError carries message', () {
      final error = UnknownError('未知错误');
      expect(error.message, '未知错误');
    });

    test('cause is optional', () {
      final withoutCause = FileError(FileErrorCode.pathEmpty, 'err');
      expect(withoutCause.cause, isNull);

      final withCause = FileError(
        FileErrorCode.pathEmpty,
        'err',
        Exception('bad'),
      );
      expect(withCause.cause, isA<Exception>());
    });

    test('exhaustive pattern matching works', () {
      final errors = <PlayerError>[
        FileError(FileErrorCode.pathEmpty, 'e'),
        CodecError(CodecErrorCode.decodeFailed, 'e'),
        PlaybackError(PlaybackErrorCode.seekFailed, 'e'),
        NetworkError(NetworkErrorCode.connectionLost, 'e'),
        UnknownError('e'),
      ];

      for (final error in errors) {
        switch (error) {
          case FileError():
            expect(error, isA<FileError>());
          case CodecError():
            expect(error, isA<CodecError>());
          case PlaybackError():
            expect(error, isA<PlaybackError>());
          case NetworkError():
            expect(error, isA<NetworkError>());
          case UnknownError():
            expect(error, isA<UnknownError>());
        }
      }
    });
  });

  group('ErrorContext', () {
    test('default timestamp is DateTime.now() within 1 second', () {
      final before = DateTime.now();
      final ctx = ErrorContext(action: 'open');
      final after = DateTime.now();

      expect(
        ctx.timestamp.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(
        ctx.timestamp.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('explicit timestamp overrides default', () {
      final fixed = DateTime(2026, 1, 15, 10, 30);
      final ctx = ErrorContext(timestamp: fixed);
      expect(ctx.timestamp, fixed);
    });

    test('toMap() serializes non-null fields, omits null fields', () {
      final ctx = ErrorContext(
        action: 'open',
        generation: 5,
        path: '/video/test.mp4',
        timestamp: DateTime(2026, 1, 15, 10, 30),
        module: 'MediaKitEngine',
      );
      final map = ctx.toMap();

      expect(map['action'], 'open');
      expect(map['generation'], 5);
      // 路径脱敏：toMap() 只保留文件名
      expect(map['path'], 'test.mp4');
      expect(map['timestamp'], '2026-01-15T10:30:00.000');
      expect(map['module'], 'MediaKitEngine');
      expect(map.containsKey('callbackStackTrace'), isFalse);
    });

    test('toMap() omits all optional fields when null', () {
      final ctx = ErrorContext();
      final map = ctx.toMap();

      expect(map.containsKey('action'), isFalse);
      expect(map.containsKey('generation'), isFalse);
      expect(map.containsKey('path'), isFalse);
      expect(map.containsKey('module'), isFalse);
      expect(map.containsKey('callbackStackTrace'), isFalse);
      // timestamp is always included
      expect(map.containsKey('timestamp'), isTrue);
    });

    test('toMap() includes callbackStackTrace when non-null', () {
      final stack = StackTrace.fromString('#0 test\n#1 frame');
      final ctx = ErrorContext(callbackStackTrace: stack);
      final map = ctx.toMap();

      expect(map.containsKey('callbackStackTrace'), isTrue);
      expect(map['callbackStackTrace'], isA<String>());
    });
  });

  group('isFatal', () {
    test('FileError: pathEmpty is not fatal (recoverable)', () {
      final error = FileError(FileErrorCode.pathEmpty, 'e');
      expect(error.isFatal, isFalse);
    });

    test('FileError: fileNotFound is not fatal (recoverable)', () {
      final error = FileError(FileErrorCode.fileNotFound, 'e');
      expect(error.isFatal, isFalse);
    });

    test('FileError: pathTraversal is fatal (not recoverable)', () {
      final error = FileError(FileErrorCode.pathTraversal, 'e');
      expect(error.isFatal, isTrue);
    });

    test('CodecError: all codes are not fatal', () {
      for (final code in CodecErrorCode.values) {
        final error = CodecError(code, 'e');
        expect(
          error.isFatal,
          isFalse,
          reason: '${code.name} should be fatal=false',
        );
      }
    });

    test('PlaybackError: textureFailed is fatal', () {
      final error = PlaybackError(PlaybackErrorCode.textureFailed, 'e');
      expect(error.isFatal, isTrue);
    });

    test('PlaybackError: other codes are not fatal', () {
      expect(PlaybackError(PlaybackErrorCode.playFailed, 'e').isFatal, isFalse);
      expect(PlaybackError(PlaybackErrorCode.seekFailed, 'e').isFatal, isFalse);
      expect(
        PlaybackError(PlaybackErrorCode.openTimeout, 'e').isFatal,
        isFalse,
      );
    });

    test('NetworkError: all codes are not fatal', () {
      for (final code in NetworkErrorCode.values) {
        final error = NetworkError(code, 'e');
        expect(
          error.isFatal,
          isFalse,
          reason: '${code.name} should be fatal=false',
        );
      }
    });

    test('UnknownError is never fatal', () {
      final error = UnknownError('e');
      expect(error.isFatal, isFalse);
    });
  });

  group('l10nKey', () {
    test('FileError l10nKey format is error.file.{code}', () {
      expect(
        FileError(FileErrorCode.pathEmpty, 'e').l10nKey,
        'error.file.pathEmpty',
      );
      expect(
        FileError(FileErrorCode.fileNotFound, 'e').l10nKey,
        'error.file.fileNotFound',
      );
      expect(
        FileError(FileErrorCode.pathTraversal, 'e').l10nKey,
        'error.file.pathTraversal',
      );
    });

    test('CodecError l10nKey format is error.codec.{code}', () {
      expect(
        CodecError(CodecErrorCode.unsupportedFormat, 'e').l10nKey,
        'error.codec.unsupportedFormat',
      );
      expect(
        CodecError(CodecErrorCode.decodeFailed, 'e').l10nKey,
        'error.codec.decodeFailed',
      );
      expect(
        CodecError(CodecErrorCode.codecUnsupported, 'e').l10nKey,
        'error.codec.codecUnsupported',
      );
    });

    test('PlaybackError l10nKey format is error.playback.{code}', () {
      expect(
        PlaybackError(PlaybackErrorCode.playFailed, 'e').l10nKey,
        'error.playback.playFailed',
      );
      expect(
        PlaybackError(PlaybackErrorCode.seekFailed, 'e').l10nKey,
        'error.playback.seekFailed',
      );
      expect(
        PlaybackError(PlaybackErrorCode.textureFailed, 'e').l10nKey,
        'error.playback.textureFailed',
      );
      expect(
        PlaybackError(PlaybackErrorCode.openTimeout, 'e').l10nKey,
        'error.playback.openTimeout',
      );
    });

    test('NetworkError l10nKey format is error.network.{code}', () {
      expect(
        NetworkError(NetworkErrorCode.timeout, 'e').l10nKey,
        'error.network.timeout',
      );
      expect(
        NetworkError(NetworkErrorCode.connectionLost, 'e').l10nKey,
        'error.network.connectionLost',
      );
    });

    test('UnknownError l10nKey is error.unknown', () {
      expect(UnknownError('e').l10nKey, 'error.unknown');
    });
  });

  group('ErrorContext backward compatibility', () {
    test('errors without context still work', () {
      final fileError = FileError(FileErrorCode.pathEmpty, 'no context');
      expect(fileError.context, isNull);
      expect(fileError.isFatal, isFalse);

      final codecError = CodecError(CodecErrorCode.decodeFailed, 'no context');
      expect(codecError.context, isNull);

      final playbackError = PlaybackError(
        PlaybackErrorCode.playFailed,
        'no context',
      );
      expect(playbackError.context, isNull);

      final networkError = NetworkError(NetworkErrorCode.timeout, 'no context');
      expect(networkError.context, isNull);

      final unknownError = UnknownError('no context');
      expect(unknownError.context, isNull);
    });

    test('errors with context carry it', () {
      final ctx = ErrorContext(action: 'open', module: 'MediaKitEngine');
      final error = FileError(
        FileErrorCode.fileNotFound,
        'not found',
        null,
        ctx,
      );

      expect(error.context, isNotNull);
      expect(error.context?.action, 'open');
      expect(error.context?.module, 'MediaKitEngine');
    });
  });

  group('recoverable markers on enums', () {
    test('FileErrorCode values have recoverable defined', () {
      expect(FileErrorCode.pathEmpty.recoverable, isTrue);
      expect(FileErrorCode.fileNotFound.recoverable, isTrue);
      expect(FileErrorCode.pathTraversal.recoverable, isFalse);
    });

    test('CodecErrorCode values have recoverable defined', () {
      expect(CodecErrorCode.unsupportedFormat.recoverable, isTrue);
      expect(CodecErrorCode.decodeFailed.recoverable, isTrue);
      expect(CodecErrorCode.codecUnsupported.recoverable, isTrue);
    });

    test('PlaybackErrorCode values have recoverable defined', () {
      expect(PlaybackErrorCode.playFailed.recoverable, isTrue);
      expect(PlaybackErrorCode.seekFailed.recoverable, isTrue);
      expect(PlaybackErrorCode.textureFailed.recoverable, isFalse);
      expect(PlaybackErrorCode.openTimeout.recoverable, isTrue);
    });

    test('NetworkErrorCode values have recoverable defined', () {
      expect(NetworkErrorCode.timeout.recoverable, isTrue);
      expect(NetworkErrorCode.connectionLost.recoverable, isTrue);
    });
  });
}
