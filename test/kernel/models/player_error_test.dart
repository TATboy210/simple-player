import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/models/player_error.dart';

void main() {
  group('PlayerErrorCode', () {
    test('enum has all expected values', () {
      expect(PlayerErrorCode.values.length, 11);
      expect(PlayerErrorCode.values, contains(PlayerErrorCode.pathEmpty));
      expect(PlayerErrorCode.values, contains(PlayerErrorCode.fileNotFound));
      expect(PlayerErrorCode.values, contains(PlayerErrorCode.pathTraversal));
      expect(
        PlayerErrorCode.values,
        contains(PlayerErrorCode.unsupportedFormat),
      );
      expect(PlayerErrorCode.values, contains(PlayerErrorCode.openTimeout));
      expect(PlayerErrorCode.values, contains(PlayerErrorCode.decodeFailed));
      expect(PlayerErrorCode.values, contains(PlayerErrorCode.textureFailed));
      expect(PlayerErrorCode.values, contains(PlayerErrorCode.networkTimeout));
      expect(
        PlayerErrorCode.values,
        contains(PlayerErrorCode.codecUnsupported),
      );
      expect(PlayerErrorCode.values, contains(PlayerErrorCode.fileCorruption));
      expect(PlayerErrorCode.values, contains(PlayerErrorCode.unknown));
    });
  });

  group('PlayerError', () {
    test('toString includes code and message', () {
      const error = PlayerError(PlayerErrorCode.fileNotFound, '文件不存在');
      expect(error.toString(), 'PlayerError(fileNotFound): 文件不存在');
    });

    test('equality based on code and message', () {
      const a = PlayerError(PlayerErrorCode.openTimeout, '超时');
      const b = PlayerError(PlayerErrorCode.openTimeout, '超时');
      const c = PlayerError(PlayerErrorCode.decodeFailed, '超时');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('hashCode consistent with equality', () {
      const a = PlayerError(PlayerErrorCode.openTimeout, '超时');
      const b = PlayerError(PlayerErrorCode.openTimeout, '超时');
      expect(a.hashCode, equals(b.hashCode));
    });

    test('cause is optional', () {
      const withoutCause = PlayerError(PlayerErrorCode.unknown, 'err');
      expect(withoutCause.cause, isNull);

      final withCause = PlayerError(
        PlayerErrorCode.decodeFailed,
        'err',
        Exception('bad'),
      );
      expect(withCause.cause, isA<Exception>());
    });
  });
}
