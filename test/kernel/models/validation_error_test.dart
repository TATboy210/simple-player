/// Unit tests for [ValidationError] and [ValidationErrorType].
///
/// Covers: enum values, constructor, toString, equality, hashCode.
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/models/validation_error.dart';

void main() {
  group('ValidationErrorType', () {
    test('has all expected values', () {
      expect(ValidationErrorType.values, hasLength(5));
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
    });

    test('name returns correct string', () {
      expect(ValidationErrorType.empty.name, 'empty');
      expect(ValidationErrorType.pathTraversal.name, 'pathTraversal');
      expect(ValidationErrorType.unsupportedFormat.name, 'unsupportedFormat');
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
