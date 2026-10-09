/// Unit tests for [ValidationError] and [ValidationErrorType].
///
/// Covers: enum values, constructor, toString, equality, hashCode.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/models/validation_error.dart';

void main() {
  group('ValidationErrorType', () {
    // N2: 追加 controlCharacters 后共 6 值 — 注册表 append-only,
    // 现有五值零改名零删除零重排, 只断言 contains 不锁顺序。
    test('has all expected values', () {
      expect(ValidationErrorType.values, hasLength(6));
      expect(ValidationErrorType.values, contains(ValidationErrorType.empty));
      expect(
        ValidationErrorType.values,
        contains(ValidationErrorType.pathTraversal),
      );
      expect(
        ValidationErrorType.values,
        contains(ValidationErrorType.unsupportedFormat),
      );
      expect(
        ValidationErrorType.values,
        contains(ValidationErrorType.invalidUrl),
      );
      expect(
        ValidationErrorType.values,
        contains(ValidationErrorType.invalidPath),
      );
      expect(
        ValidationErrorType.values,
        contains(ValidationErrorType.controlCharacters),
      );
    });

    test('name returns correct string', () {
      expect(ValidationErrorType.empty.name, 'empty');
      expect(ValidationErrorType.pathTraversal.name, 'pathTraversal');
      expect(ValidationErrorType.unsupportedFormat.name, 'unsupportedFormat');
      expect(ValidationErrorType.controlCharacters.name, 'controlCharacters');
    });

    test('toString includes controlCharacters type name and message (N2)', () {
      const error = ValidationError(
        ValidationErrorType.controlCharacters,
        'Contains 0x01',
      );
      expect(
        error.toString(),
        'ValidationError(controlCharacters): Contains 0x01',
      );
    });
  });

  group('ValidationError', () {
    test('stores type and message', () {
      const error = ValidationError(ValidationErrorType.empty, 'Path is empty');
      expect(error.type, ValidationErrorType.empty);
      expect(error.message, 'Path is empty');
    });

    test('toString includes type name and message', () {
      const error = ValidationError(
        ValidationErrorType.pathTraversal,
        'Contains ../',
      );
      expect(error.toString(), 'ValidationError(pathTraversal): Contains ../');
    });

    group('equality', () {
      test('equal when type and message match', () {
        const a = ValidationError(ValidationErrorType.empty, 'msg');
        const b = ValidationError(ValidationErrorType.empty, 'msg');
        expect(a, equals(b));
      });

      test('not equal when type differs', () {
        const a = ValidationError(ValidationErrorType.empty, 'msg');
        const b = ValidationError(ValidationErrorType.invalidPath, 'msg');
        expect(a, isNot(equals(b)));
      });

      test('not equal when message differs', () {
        const a = ValidationError(ValidationErrorType.empty, 'msg1');
        const b = ValidationError(ValidationErrorType.empty, 'msg2');
        expect(a, isNot(equals(b)));
      });

      test('identical instances are equal', () {
        const a = ValidationError(ValidationErrorType.empty, 'msg');
        expect(a, equals(a));
      });

      test('not equal to non-ValidationError', () {
        const a = ValidationError(ValidationErrorType.empty, 'msg');
        // ignore: unrelated_type_equality_checks
        expect(a == 'not an error', isFalse);
      });
    });

    group('hashCode', () {
      test('consistent for equal instances', () {
        const a = ValidationError(ValidationErrorType.empty, 'msg');
        const b = ValidationError(ValidationErrorType.empty, 'msg');
        expect(a.hashCode, b.hashCode);
      });

      test('different for different types', () {
        const a = ValidationError(ValidationErrorType.empty, 'msg');
        const b = ValidationError(ValidationErrorType.invalidPath, 'msg');
        expect(a.hashCode == b.hashCode, isFalse);
      });
    });
  });
}
