/// ErrorFeedbackSettings 便携 JSON 存储的行为测试（SET-03 / D-01 / tracer 纵切）。
///
/// Behavioral tests for the portable settings store: silent fallback on
/// corrupted input, and the tracer end-to-end slice proving a real
/// settings.json drives the three-tier log location chain into sink evidence.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/clock.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_log_file_sink.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_log_location.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_reporter.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_reporting_dependencies.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/error_feedback_settings.dart';

void main() {
  group('ErrorFeedbackSettings store', () {
    late Directory root;
    late File settingsFile;

    setUp(() async {
      // Arrange — 每个用例独立的真实临时目录（既有惯例）。
      root = await Directory.systemTemp.createTemp('ef-settings-store-');
      addTearDown(() => root.delete(recursive: true));
      settingsFile = File(
        '${root.path}${Platform.pathSeparator}settings.json',
      );
    });

    tearDown(() {
      // 测试隔离：复位单例内存态并重绑默认 seam（循 resetForTesting 惯例）。
      ErrorFeedbackSettings.I.resetForTesting();
    });

    group('tracer 端到端纵切', () {
      test('真实 settings.json 的 logDirectory 经三层链成为 sink 落盘位置', () async {
        // Arrange — 配置层/exe 层/AS 层全部指向真实临时目录（不触真实 exe 与 cwd）。
        final configured = Directory(
          '${root.path}${Platform.pathSeparator}configured-logs',
        );
        await configured.create();
        final exeRoot = Directory(
          '${root.path}${Platform.pathSeparator}exe-root',
        );
        await exeRoot.create();
        final support = Directory(
          '${root.path}${Platform.pathSeparator}support',
        );
        await support.create();
        await settingsFile.writeAsString(
          '{"version":1,"errorCardEnabled":true,'
          '"logDirectory":${jsonEncode(configured.path)}}',
        );
        ErrorFeedbackSettings.I.resetForTesting(
          settingsFile: () => settingsFile,
        );

        // Act — load 先于 resolve（同一条 unawaited 激活路径语义）。
        await ErrorFeedbackSettings.I.load();
        final result = await ErrorLogLocation.resolve(
          applicationSupportDirectory: () async => support,
          executableDirectory: () => exeRoot,
          configuredDirectory: ErrorFeedbackSettings.I.state.value.logDirectory,
        );

        // Assert — 配置层优先于 exe/AS 层胜出，无回退原因。
        final resolved = result as ErrorLogLocationResolved;
        expect(resolved.configuredFailure, isNull);
        expect(resolved.file.path, startsWith(configured.path));

        // Act — sink 激活 + 真实报告落盘（store→链→sink→磁盘全链贯通）。
        final sink = ErrorLogFileSink(file: resolved.file);
        final reporter = _reporter(effects: [sink.record]);
        reporter.reportPlatformSafely(
          StateError('tracer 链路证据'),
          StackTrace.fromString('tracer raw stack'),
        );
        await sink.drain();

        // Assert — 诊断包内容落在配置目录的文件中。
        final pack = await resolved.file.readAsString();
        expect(pack, contains('== Report =='));
        expect(pack, contains('tracer 链路证据'));
      });
    });

    group('损坏输入静默回退默认值（D-01）', () {
      test('文件不存在 → 默认值且不抛出', () async {
        // Arrange — seam 指向从未创建的路径。
        ErrorFeedbackSettings.I.resetForTesting(
          settingsFile: () => settingsFile,
        );

        // Act
        await ErrorFeedbackSettings.I.load();

        // Assert
        expect(
          ErrorFeedbackSettings.I.state.value,
          const ErrorFeedbackSettingsData(),
        );
      });

      test('空串内容（FormatException）→ 默认值且不抛出', () async {
        // Arrange
        await settingsFile.writeAsString('');
        ErrorFeedbackSettings.I.resetForTesting(
          settingsFile: () => settingsFile,
        );

        // Act
        await ErrorFeedbackSettings.I.load();

        // Assert
        expect(
          ErrorFeedbackSettings.I.state.value,
          const ErrorFeedbackSettingsData(),
        );
      });

      test('尾随垃圾（FormatException）→ 默认值且不抛出', () async {
        // Arrange
        await settingsFile.writeAsString('{"version":1} 垃圾尾巴');
        ErrorFeedbackSettings.I.resetForTesting(
          settingsFile: () => settingsFile,
        );

        // Act
        await ErrorFeedbackSettings.I.load();

        // Assert
        expect(
          ErrorFeedbackSettings.I.state.value,
          const ErrorFeedbackSettingsData(),
        );
      });

      test('[1,2] List 形状（is! Map 守卫承重）→ 默认值且不抛出', () async {
        // Arrange
        await settingsFile.writeAsString('[1,2]');
        ErrorFeedbackSettings.I.resetForTesting(
          settingsFile: () => settingsFile,
        );

        // Act
        await ErrorFeedbackSettings.I.load();

        // Assert
        expect(
          ErrorFeedbackSettings.I.state.value,
          const ErrorFeedbackSettingsData(),
        );
      });

      test('errorCardEnabled 为字符串 → 逐字段回退默认值且不抛出', () async {
        // Arrange
        await settingsFile.writeAsString('{"errorCardEnabled":"yes"}');
        ErrorFeedbackSettings.I.resetForTesting(
          settingsFile: () => settingsFile,
        );

        // Act
        await ErrorFeedbackSettings.I.load();

        // Assert — errorCardEnabled=true、logDirectory=''（SET-01 默认开）。
        expect(
          ErrorFeedbackSettings.I.state.value,
          const ErrorFeedbackSettingsData(),
        );
      });
    });

    group('存储层生产加固（SET-03：原子写 + 保存失败吞没 + 默认位置）', () {
      test('round-trip：新实例从同一文件读回写入值（重启模拟）', () async {
        // Arrange — 第一个实例写入并等待持久化完成。
        final writer = ErrorFeedbackSettings.forTesting(
          settingsFile: () => settingsFile,
        );
        writer.setCardEnabled(false);
        writer.setLogDirectory(root.path);
        await writer.pendingPersist;

        // Act — 「重启」：第二个实例从同一文件加载。
        final reader = ErrorFeedbackSettings.forTesting(
          settingsFile: () => settingsFile,
        );
        await reader.load();

        // Assert — SET-03 重启持久化语义。
        expect(reader.state.value.errorCardEnabled, isFalse);
        expect(reader.state.value.logDirectory, root.path);
      });

      test('原子写：保存后目标存在可解析且无 tmp 残留', () async {
        // Arrange
        final store = ErrorFeedbackSettings.forTesting(
          settingsFile: () => settingsFile,
        );

        // Act
        store.setLogDirectory(root.path);
        await store.pendingPersist;

        // Assert — 目标文件存在且内容可解析；任何形态的 tmp 都不残留
        //（WR-05 后 tmp 名唯一，断言扩为全目录无 .tmp 痕迹）。
        expect(settingsFile.existsSync(), isTrue);
        final decoded = jsonDecode(settingsFile.readAsStringSync());
        expect(decoded['version'], 1);
        expect(decoded['logDirectory'], root.path);
        expect(decoded['errorCardEnabled'], isTrue);
        final residue = root
            .listSync()
            .where((entry) => entry.path.contains('.tmp'))
            .toList();
        expect(residue, isEmpty);
      });

      test('rapid successive persists serialize; final state is the last write',
          () async {
        // Arrange — 交叉开关与目录两路写入，模拟高频设置变更。
        final store = ErrorFeedbackSettings.forTesting(
          settingsFile: () => settingsFile,
        );
        final dirA = '${root.path}${Platform.pathSeparator}a';
        final dirB = '${root.path}${Platform.pathSeparator}b';

        // Act — 三笔背靠背发起（不等待前一笔完成）。
        store.setLogDirectory(dirA);
        store.setCardEnabled(false);
        store.setLogDirectory(dirB);
        await store.pendingPersist;

        // Assert — 串行链保证最终状态 = 最后一笔（WR-05）；无 tmp 残留。
        final decoded =
            jsonDecode(await settingsFile.readAsString())
                as Map<String, Object?>;
        expect(decoded['logDirectory'], dirB);
        expect(decoded['errorCardEnabled'], isFalse);
        final residue = root
            .listSync()
            .where((entry) => entry.path.contains('.tmp'))
            .toList();
        expect(residue, isEmpty);
      });

      test('保存失败静默：state 保持更新且不抛出、不回滚内存态', () async {
        // Arrange — 文件路径的中间段被同名文件占据（深路径无法创建），
        // writeAsString/rename/兜底各级全部失败的真实形态。
        final occupied = File('${root.path}${Platform.pathSeparator}occupied');
        await occupied.writeAsString('not a directory');
        final doomed = File(
          '${occupied.path}${Platform.pathSeparator}deep'
          '${Platform.pathSeparator}settings.json',
        );
        final store = ErrorFeedbackSettings.forTesting(
          settingsFile: () => doomed,
        );

        // Act — 保存失败被吞没，不向调用方抛出。
        store.setLogDirectory(root.path);
        await store.pendingPersist;

        // Assert — D-01：内存态保持用户刚设置的值。
        expect(store.state.value.logDirectory, root.path);
        expect(doomed.existsSync(), isFalse);
      });

      test('debug 默认 provider 指向项目目录旁 settings.json', () {
        // Act
        final file = ErrorFeedbackSettings.defaultSettingsFile();

        // Assert — debug 模式默认存 cwd 旁（release 差异由 kDebugMode 三目
        // 与 doc comment 承载，编译期 const 无法在 debug 测试中切换）。
        expect(file.path, startsWith(Directory.current.path));
        expect(file.path, endsWith('settings.json'));
      });

      group('两层回退（WR-06：exe 旁不可写 → Application Support）', () {
        test('probe-fail primary falls back to Application Support and '
            'round-trips', () async {
          // Arrange — 层 1 父目录被同名文件占据（create+探测必败的真实形态），
          // AS 层指向真实临时目录并预置一份持久值。
          final occupied = File('${root.path}${Platform.pathSeparator}occupied');
          await occupied.writeAsString('not a directory');
          final doomedPrimary = File(
            '${occupied.path}${Platform.pathSeparator}settings.json',
          );
          final support = Directory(
            '${root.path}${Platform.pathSeparator}support',
          );
          await support.create();
          final asFile = File(
            '${support.path}${Platform.pathSeparator}settings.json',
          );
          await asFile.writeAsString('{"version":1,"errorCardEnabled":false}');
          ErrorFeedbackSettings.I.resetForTesting(
            settingsFile: () => doomedPrimary,
          );

          // Act
          await ErrorFeedbackSettings.I.load(
            applicationSupportDirectory: () async => support,
          );

          // Assert — 回退层读取生效：false 来自 AS 文件而非默认值。
          expect(ErrorFeedbackSettings.I.state.value.errorCardEnabled, isFalse);

          // 写入同样落在回退层（会话内记住层级，不逐写探测）。
          ErrorFeedbackSettings.I.setCardEnabled(true);
          await ErrorFeedbackSettings.I.pendingPersist;
          final decoded = jsonDecode(await asFile.readAsString());
          expect(decoded['errorCardEnabled'], isTrue);
          expect(doomedPrimary.existsSync(), isFalse);
        });

        test('both tiers unwritable: defaults in memory, no crash, silent '
            'persist', () async {
          // Arrange — 层 1 父目录被文件占据 + AS provider 抛出。
          final occupied = File('${root.path}${Platform.pathSeparator}occupied');
          await occupied.writeAsString('not a directory');
          final doomedPrimary = File(
            '${occupied.path}${Platform.pathSeparator}settings.json',
          );
          ErrorFeedbackSettings.I.resetForTesting(
            settingsFile: () => doomedPrimary,
          );

          // Act — load 不抛出，状态保持默认。
          await ErrorFeedbackSettings.I.load(
            applicationSupportDirectory: () async =>
                throw const FileSystemException('support unavailable'),
          );

          // Assert — D-01：内存默认值；persist 静默失败且不产生任何文件。
          expect(
            ErrorFeedbackSettings.I.state.value,
            const ErrorFeedbackSettingsData(),
          );
          ErrorFeedbackSettings.I.setCardEnabled(false);
          await ErrorFeedbackSettings.I.pendingPersist;
          expect(doomedPrimary.existsSync(), isFalse);
        });
      });
    });
  });
}

/// Constructs a deterministic reporter with a production-shaped effect seam.
ErrorReporterImpl _reporter({required List<ErrorReportEffect> effects}) {
  var sequence = 0;
  return ErrorReporterImpl.forTesting(
    clock: FakeClock(DateTime.utc(2026, 8, 30, 12)),
    eventIdGenerator: () => 'event-${++sequence}',
    currentMediaPath: () => 'current.mp4',
    effects: effects,
  );
}
