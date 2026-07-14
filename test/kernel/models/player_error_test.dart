import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/models/player_error.dart';

void main() {
  group('PlayerError sealed class', () {
    test('FileError carries code and message', () {
      const error = FileError(FileErrorCode.fileNotFound, '文件不存在');
      expect(error.code, FileErrorCode.fileNotFound);
      expect(error.message, '文件不存在');
      expect(error.toString(), 'FileError(fileNotFound): 文件不存在');
    });

    test('CodecError carries code and message', () {
      const error = CodecError(CodecErrorCode.unsupportedFormat, '无法解码');
      expect(error.code, CodecErrorCode.unsupportedFormat);
      expect(error.message, '无法解码');
    });

    test('PlaybackError carries code and message', () {
      const error = PlaybackError(PlaybackErrorCode.playFailed, '播放失败');
      expect(error.code, PlaybackErrorCode.playFailed);
      expect(error.message, '播放失败');
    });

    test('NetworkError carries code and message', () {
      const error = NetworkError(NetworkErrorCode.timeout, '网络超时');
      expect(error.code, NetworkErrorCode.timeout);
      expect(error.message, '网络超时');
    });

    test('UnknownError carries message', () {
      const error = UnknownError('未知错误');
      expect(error.message, '未知错误');
    });

    test('cause is optional', () {
      const withoutCause = FileError(FileErrorCode.pathEmpty, 'err');
      expect(withoutCause.cause, isNull);

      final withCause = FileError(FileErrorCode.pathEmpty, 'err', Exception('bad'));
      expect(withCause.cause, isA<Exception>());
    });

    test('exhaustive pattern matching works', () {
      const errors = <PlayerError>[
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
}
