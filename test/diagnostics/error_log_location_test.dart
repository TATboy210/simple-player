/// Behavioral tests for the immutable default diagnostic log location.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_log_location.dart';

void main() {
  group('ErrorLogLocation', () {
    test('creates and resolves support/logs/error.log idempotently', () async {
      // Arrange
      final support = await Directory.systemTemp.createTemp('error log 空间 ');
      addTearDown(() => support.delete(recursive: true));

      // Act
      final first = await ErrorLogLocation.resolve(
        applicationSupportDirectory: () async => support,
      );
      final second = await ErrorLogLocation.resolve(
        applicationSupportDirectory: () async => support,
      );

      // Assert
      final firstResolved = first as ErrorLogLocationResolved;
      final secondResolved = second as ErrorLogLocationResolved;
      expect(
        firstResolved.file.path,
        endsWith(
          '${Platform.pathSeparator}logs${Platform.pathSeparator}error.log',
        ),
      );
      expect(firstResolved.file.parent.existsSync(), isTrue);
      expect(secondResolved.file.path, firstResolved.file.path);
    });

    test('keeps Unicode and spaces while fixing the log filename', () async {
      // Arrange
      final root = await Directory.systemTemp.createTemp('支持目录 with spaces ');
      final support = Directory('${root.path}${Platform.pathSeparator}日志 文件');
      await support.create();
      addTearDown(() => root.delete(recursive: true));

      // Act
      final result = await ErrorLogLocation.resolve(
        applicationSupportDirectory: () async => support,
      );

      // Assert
      final resolved = result as ErrorLogLocationResolved;
      expect(resolved.file.path, contains('日志 文件'));
      expect(
        resolved.file.path,
        endsWith(
          '${Platform.pathSeparator}logs${Platform.pathSeparator}error.log',
        ),
      );
    });

    test('returns unavailable when the support provider throws', () async {
      // Act
      final result = await ErrorLogLocation.resolve(
        applicationSupportDirectory: () async =>
            throw const FileSystemException('support unavailable'),
      );

      // Assert
      expect(result, isA<ErrorLogLocationUnavailable>());
    });

    test('returns unavailable when the support path is a file', () async {
      // Arrange
      final root = await Directory.systemTemp.createTemp('error-log-file-root');
      final supportFile = File(
        '${root.path}${Platform.pathSeparator}support-file',
      );
      await supportFile.writeAsString('not a directory');
      addTearDown(() => root.delete(recursive: true));

      // Act
      final result = await ErrorLogLocation.resolve(
        applicationSupportDirectory: () async => Directory(supportFile.path),
      );

      // Assert
      expect(result, isA<ErrorLogLocationUnavailable>());
    });

    test('does not use process or executable fallback locations', () {
      // Arrange
      final source = File('lib/kernel/diagnostics/error_log_location.dart')
          .readAsStringSync();

      // Assert
      expect(source, isNot(contains('Directory.current')));
      expect(source, isNot(contains('resolvedExecutable')));
    });
  });
}
