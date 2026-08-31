/// Behavioral tests for the three-tier default diagnostic log location chain.
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
        applicationSupportDirectory: withCreatedDirectory(support),
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

    test('never reads process locations directly - the executable tier is '
        'injected', () {
      // Arrange
      final source = File('lib/kernel/diagnostics/error_log_location.dart')
          .readAsStringSync();

      // Assert — kernel 纯度不变：不读进程位置字面量；exe 层只经注入 provider
      // 到达（04-CONTEXT.md D-02 取代 Phase 2 的「无进程回退」政策）。
      expect(source, isNot(contains('Directory.current')));
      expect(source, isNot(contains('resolvedExecutable')));
    });

    group('三层回退链（D-02：配置 → exe 根 → Application Support）', () {
      late Directory root;

      setUp(() async {
        root = await Directory.systemTemp.createTemp('error-log-chain-');
        addTearDown(() => root.delete(recursive: true));
      });

      test('configured tier wins over exe-root and Application Support tiers',
          () async {
        // Arrange
        final configured = Directory('${root.path}${Platform.pathSeparator}cfg');
        await configured.create();
        final exeRoot = Directory('${root.path}${Platform.pathSeparator}exe');
        final support = Directory('${root.path}${Platform.pathSeparator}as');

        // Act
        final result = await ErrorLogLocation.resolve(
          applicationSupportDirectory: () async => support,
          executableDirectory: () => exeRoot,
          configuredDirectory: configured.path,
        );

        // Assert — file 直接位于配置目录下，其余层未被触碰。
        final resolved = result as ErrorLogLocationResolved;
        expect(
          resolved.file.path,
          startsWith(configured.path),
        );
        expect(resolved.configuredFailure, isNull);
        expect(
          Directory(
            '${exeRoot.path}${Platform.pathSeparator}'
            'logs',
          ).existsSync(),
          isFalse,
        );
        expect(
          Directory(
            '${support.path}${Platform.pathSeparator}logs',
          ).existsSync(),
          isFalse,
        );
      });

      test('empty configured directory skips to the injected exe-root tier',
          () async {
        // Arrange
        final exeRoot = Directory('${root.path}${Platform.pathSeparator}exe');
        final support = Directory('${root.path}${Platform.pathSeparator}as');

        // Act — configuredDirectory 空串 = 跳过配置层走默认链（D-01 语义）。
        final result = await ErrorLogLocation.resolve(
          applicationSupportDirectory: () async => support,
          executableDirectory: () => exeRoot,
          configuredDirectory: '',
        );

        // Assert — D-02：exe 根优先于 AS。
        final resolved = result as ErrorLogLocationResolved;
        expect(resolved.file.path, startsWith(exeRoot.path));
        expect(
          resolved.file.path,
          endsWith(
            '${Platform.pathSeparator}logs${Platform.pathSeparator}error.log',
          ),
        );
        expect(
          Directory(
            '${support.path}${Platform.pathSeparator}logs',
          ).existsSync(),
          isFalse,
        );
      });

      test('unwritable exe tier falls back to the Application Support tier',
          () async {
        // Arrange — 注入路径选择探测：exe 层不可写，AS 层可写。
        final exeRoot = Directory(
          '${root.path}${Platform.pathSeparator}exe-root',
        );
        final support = Directory('${root.path}${Platform.pathSeparator}as');

        // Act
        final result = await ErrorLogLocation.resolve(
          applicationSupportDirectory: () async => support,
          executableDirectory: () => exeRoot,
          writable: (dir) async => !dir.path.contains('exe-root'),
        );

        // Assert — exe 层探测失败 → 跳层到 AS。
        final resolved = result as ErrorLogLocationResolved;
        expect(resolved.file.path, startsWith(support.path));
      });

      test('file-occupied configured path skips the tier and carries the '
          'failure', () async {
        // Arrange — 实测形态：Directory.create 撞上同名文件 → PathExistsException。
        final occupied = File('${root.path}${Platform.pathSeparator}occupied');
        await occupied.writeAsString('not a directory');
        final exeRoot = Directory('${root.path}${Platform.pathSeparator}exe');
        final support = Directory('${root.path}${Platform.pathSeparator}as');

        // Act
        final result = await ErrorLogLocation.resolve(
          applicationSupportDirectory: () async => support,
          executableDirectory: () => exeRoot,
          configuredDirectory: occupied.path,
        );

        // Assert — 结果落在 exe 层且携带配置层回退原因。
        final resolved = result as ErrorLogLocationResolved;
        expect(resolved.configuredFailure, isNotNull);
        expect(resolved.file.path, startsWith(exeRoot.path));
      });

      test('valid configured win keeps configuredFailure null', () async {
        // Arrange
        final configured = Directory('${root.path}${Platform.pathSeparator}cfg');
        await configured.create();
        final exeRoot = Directory('${root.path}${Platform.pathSeparator}exe');
        final support = Directory('${root.path}${Platform.pathSeparator}as');

        // Act
        final result = await ErrorLogLocation.resolve(
          applicationSupportDirectory: () async => support,
          executableDirectory: () => exeRoot,
          configuredDirectory: configured.path,
        );

        // Assert
        final resolved = result as ErrorLogLocationResolved;
        expect(resolved.configuredFailure, isNull);
      });

      test('all tiers failing degrades to unavailable without throwing',
          () async {
        // Arrange — 探测恒 false + AS provider 抛出（既有降级态，不抛出）。
        final configured = Directory('${root.path}${Platform.pathSeparator}cfg');
        await configured.create();
        final exeRoot = Directory('${root.path}${Platform.pathSeparator}exe');

        // Act
        final result = await ErrorLogLocation.resolve(
          applicationSupportDirectory: () async =>
              throw const FileSystemException('support unavailable'),
          executableDirectory: () => exeRoot,
          configuredDirectory: configured.path,
          writable: (_) async => false,
        );

        // Assert
        expect(result, isA<ErrorLogLocationUnavailable>());
      });

      test('probe-failing every real tier degrades to unavailable', () async {
        // Arrange — AS provider 返回真实目录但探测恒 false（探测型全败路径）。
        final configured = Directory('${root.path}${Platform.pathSeparator}cfg');
        await configured.create();
        final exeRoot = Directory('${root.path}${Platform.pathSeparator}exe');
        final support = Directory('${root.path}${Platform.pathSeparator}as');

        // Act
        final result = await ErrorLogLocation.resolve(
          applicationSupportDirectory: () async => support,
          executableDirectory: () => exeRoot,
          configuredDirectory: configured.path,
          writable: (_) async => false,
        );

        // Assert
        expect(result, isA<ErrorLogLocationUnavailable>());
      });
    });
  });
}

/// Wraps an already created directory into the async provider seam shape.
Future<Directory> Function() withCreatedDirectory(Directory directory) {
  return () async => directory;
}
