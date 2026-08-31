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

    group('启动配置层校验契约（WR-03：startup tier shares the UI contract）', () {
      late Directory root;
      late Directory exeRoot;
      late Directory support;

      setUp(() async {
        root = await Directory.systemTemp.createTemp('log-startup-tier-');
        addTearDown(() => root.delete(recursive: true));
        exeRoot = Directory('${root.path}${Platform.pathSeparator}exe');
        support = Directory('${root.path}${Platform.pathSeparator}as');
      });

      test('whitespace-only configured value silently skips to the default '
          'chain', () async {
        // Act — 纯空白配置值与 '' 同义：静默走默认链（D-01 空配置语义）。
        final result = await ErrorLogLocation.resolve(
          applicationSupportDirectory: () async => support,
          executableDirectory: () => exeRoot,
          configuredDirectory: '   ',
        );

        // Assert — 落点在 exe 层；无任何以空白命名的目录被创建（旧缺陷会
        // 在进程 cwd 下 create 出空白目录并当作层 1 胜出）。
        final resolved = result as ErrorLogLocationResolved;
        expect(resolved.file.path, startsWith(exeRoot.path));
        expect(resolved.configuredFailure, isNull);
      });

      test('relative configured value falls back carrying the typed reason',
          () async {
        // Act
        final result = await ErrorLogLocation.resolve(
          applicationSupportDirectory: () async => support,
          executableDirectory: () => exeRoot,
          configuredDirectory: 'relative-logs',
        );

        // Assert — 相对路径被单层校验拒绝：回退默认链且携带封闭原因
        //（D-04 回退通知对畸形配置同样触发）。
        final resolved = result as ErrorLogLocationResolved;
        expect(resolved.configuredFailure, ConfiguredDirectoryFailure.notAbsolute);
        expect(resolved.file.path, startsWith(exeRoot.path));
      });

      test('forward-slash UNC configured value falls back carrying the '
          'typed reason', () async {
        // Act — WR-03+WR-04 组合：启动层拒绝 //server/share 形态。
        final result = await ErrorLogLocation.resolve(
          applicationSupportDirectory: () async => support,
          executableDirectory: () => exeRoot,
          configuredDirectory: '//server/share',
        );

        // Assert
        final resolved = result as ErrorLogLocationResolved;
        expect(
          resolved.configuredFailure,
          ConfiguredDirectoryFailure.uncPathUnsupported,
        );
        expect(resolved.file.path, startsWith(exeRoot.path));
      });

      test('whitespace-padded valid directory is accepted via trim', () async {
        // Arrange
        final configured = Directory('${root.path}${Platform.pathSeparator}cfg');
        await configured.create();

        // Act — 前后空白在单层校验内被 trim，配置层照常胜出。
        final result = await ErrorLogLocation.resolve(
          applicationSupportDirectory: () async => support,
          executableDirectory: () => exeRoot,
          configuredDirectory: '  ${configured.path}  ',
        );

        // Assert — 胜出层为 trim 后的目录；无回退原因。
        final resolved = result as ErrorLogLocationResolved;
        expect(resolved.configuredFailure, isNull);
        expect(resolved.file.path, startsWith(configured.path));
      });
    });

    group('validateConfiguredDirectory 单层校验（SET-02 采用面）', () {
      late Directory root;

      setUp(() async {
        root = await Directory.systemTemp.createTemp('log-dir-validate-');
        addTearDown(() => root.delete(recursive: true));
      });

      test('existing directory validates with the directory handle', () async {
        // Arrange
        final dir = Directory('${root.path}${Platform.pathSeparator}existing');
        await dir.create();

        // Act
        final result = await ErrorLogLocation.validateConfiguredDirectory(
          dir.path,
        );

        // Assert
        final valid = result as ConfiguredDirectoryValid;
        expect(valid.directory.path, dir.path);
      });

      test('creatable deep path validates after recursive create', () async {
        // Arrange — 不存在但可创建的深路径（与链层同语义：create recursive 后探测）。
        final deep = Directory(
          '${root.path}${Platform.pathSeparator}a${Platform.pathSeparator}b',
        );

        // Act
        final result = await ErrorLogLocation.validateConfiguredDirectory(
          deep.path,
        );

        // Assert
        expect(result, isA<ConfiguredDirectoryValid>());
        expect(deep.existsSync(), isTrue);
      });

      test('empty and whitespace-only inputs are notAbsolute', () async {
        // Act + Assert — 空串/纯空白都归入 notAbsolute（封闭原因集）。
        for (final input in <String>['', '   ']) {
          final result = await ErrorLogLocation.validateConfiguredDirectory(
            input,
          );
          final invalid = result as ConfiguredDirectoryInvalid;
          expect(invalid.reason, ConfiguredDirectoryFailure.notAbsolute);
          expect(invalid.error, isNull);
        }
      });

      test('relative path is notAbsolute', () async {
        // Act
        final result = await ErrorLogLocation.validateConfiguredDirectory(
          'relative${Platform.pathSeparator}dir',
        );

        // Assert
        expect(
          (result as ConfiguredDirectoryInvalid).reason,
          ConfiguredDirectoryFailure.notAbsolute,
        );
      });

      test('null byte and control characters are invalidCharacters', () async {
        // Arrange — 绝对路径骨架内注入控制字符（相对路径会先被 notAbsolute 拦下）。
        final withNullByte =
            '${root.path}${Platform.pathSeparator}'
            'bad${String.fromCharCode(0)}name';
        final withControl =
            '${root.path}${Platform.pathSeparator}'
            'bad${String.fromCharCode(1)}name';

        // Act + Assert
        for (final input in <String>[withNullByte, withControl]) {
          final result = await ErrorLogLocation.validateConfiguredDirectory(
            input,
          );
          expect(
            (result as ConfiguredDirectoryInvalid).reason,
            ConfiguredDirectoryFailure.invalidCharacters,
          );
        }
      });

      test('UNC path is rejected as uncPathUnsupported (A3)', () async {
        // Act — A3 采纳：v1 拒绝 UNC 并文档化。
        final result = await ErrorLogLocation.validateConfiguredDirectory(
          '\\\\server${Platform.pathSeparator}share',
        );

        // Assert
        expect(
          (result as ConfiguredDirectoryInvalid).reason,
          ConfiguredDirectoryFailure.uncPathUnsupported,
        );
      });

      test('forward-slash UNC form is rejected identically (WR-04)', () async {
        // Act — 正斜杠 UNC 形态（//server/share）与反斜杠形态同判（WR-04）。
        final result = await ErrorLogLocation.validateConfiguredDirectory(
          '//server/share',
        );

        // Assert
        expect(
          (result as ConfiguredDirectoryInvalid).reason,
          ConfiguredDirectoryFailure.uncPathUnsupported,
        );
      });

      test('over-long path is pathTooLong at the named constant bound',
          () async {
        // Arrange — 超过 maxConfiguredPathLength（1024）的绝对路径。
        final overLong =
            '${root.path}${Platform.pathSeparator}${'x' * 1030}';

        // Act
        final result = await ErrorLogLocation.validateConfiguredDirectory(
          overLong,
        );

        // Assert
        expect(ErrorLogLocation.maxConfiguredPathLength, 1024);
        expect(
          (result as ConfiguredDirectoryInvalid).reason,
          ConfiguredDirectoryFailure.pathTooLong,
        );
      });

      test('file-occupied segment fails as notWritable with original error',
          () async {
        // Arrange — 实测形态：Directory.create 撞上同名文件 →
        // PathExistsException（errno 183），原始异常随行。
        final occupied = File('${root.path}${Platform.pathSeparator}occupied');
        await occupied.writeAsString('not a directory');
        final target = Directory(
          '${occupied.path}${Platform.pathSeparator}sub',
        );

        // Act
        final result = await ErrorLogLocation.validateConfiguredDirectory(
          target.path,
        );

        // Assert
        final invalid = result as ConfiguredDirectoryInvalid;
        expect(invalid.reason, ConfiguredDirectoryFailure.notWritable);
        expect(invalid.error, isA<FileSystemException>());
      });

      test('injected probe failure is notWritable without real I/O', () async {
        // Arrange — 真实存在的目录 + 恒 false 探测（探测 seam 承载
        // file-as-dir 下写探测的 PathNotFoundException errno 3 形态）。
        final dir = Directory('${root.path}${Platform.pathSeparator}real');
        await dir.create();

        // Act
        final result = await ErrorLogLocation.validateConfiguredDirectory(
          dir.path,
          writable: (_) async => false,
        );

        // Assert
        expect(
          (result as ConfiguredDirectoryInvalid).reason,
          ConfiguredDirectoryFailure.notWritable,
        );
      });

      test('injected probe success validates through the seam', () async {
        // Arrange — seam 恒 true：探测 I/O 由 seam 表达，校验只判 seam 结论。
        final dir = Directory('${root.path}${Platform.pathSeparator}real');
        await dir.create();
        var probed = 0;

        // Act
        final result = await ErrorLogLocation.validateConfiguredDirectory(
          dir.path,
          writable: (_) async {
            probed += 1;
            return true;
          },
        );

        // Assert
        expect(result, isA<ConfiguredDirectoryValid>());
        expect(probed, 1);
      });
    });
  });
}

/// Wraps an already created directory into the async provider seam shape.
Future<Directory> Function() withCreatedDirectory(Directory directory) {
  return () async => directory;
}
