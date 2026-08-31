/// DiagnosticLogTarget 重定向协调器的行为测试（SET-02 重定向协议）。
///
/// Behavioral tests for the retarget coordinator with a real delegate and
/// real temporary files: validate-first / save-on-success, the dispose→activate
/// ordering, gap buffering through the bounded pending FIFO, the no-dispose
/// guarantee on resolve failure, idempotency, and the one-shot fallback notice.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_log_file_sink.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_log_location.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_report.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_reporting_dependencies.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/diagnostic_log_target.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/error_feedback_settings.dart';

void main() {
  group('DiagnosticLogTarget 重定向协调器', () {
    late Directory root;
    late Directory oldDir;
    late File oldFile;
    late DelegatingDiagnosticLogEffect delegate;
    late DiagnosticLogTarget target;

    /// 以默认临时 provider 重绑协调器（每个用例独立 exe/AS 目录）。
    void rebind(
      DelegatingDiagnosticLogEffect effect, {
      ApplicationSupportDirectoryProvider? applicationSupportDirectory,
      ExecutableDirectoryProvider? executableDirectory,
    }) {
      DiagnosticLogTarget.I.resetForTesting(
        effect: effect,
        applicationSupportDirectory:
            applicationSupportDirectory ??
            () async => Directory(
              '${root.path}${Platform.pathSeparator}as',
            ),
        executableDirectory:
            executableDirectory ??
            () => Directory('${root.path}${Platform.pathSeparator}exe'),
      );
    }

    setUp(() async {
      root = await Directory.systemTemp.createTemp('log-target-');
      addTearDown(() => root.delete(recursive: true));
      oldDir = Directory('${root.path}${Platform.pathSeparator}old');
      await oldDir.create();
      oldFile = File(
        '${oldDir.path}${Platform.pathSeparator}'
        '${ErrorLogLocation.logFileName}',
      );
      delegate = DelegatingDiagnosticLogEffect();
      target = DiagnosticLogTarget.I;
      // settings seam 指向用例临时文件，避免触碰真实设置。
      ErrorFeedbackSettings.I.resetForTesting(
        settingsFile: () => File(
          '${root.path}${Platform.pathSeparator}settings.json',
        ),
      );
      rebind(delegate);
      addTearDown(() {
        // 复位单例内存态并重绑默认 seam（循既有 resetForTesting 惯例）。
        ErrorFeedbackSettings.I.resetForTesting();
      });
    });

    test('valid retarget keeps order across old and new files', () async {
      // Arrange — 经协调器 activateResolved 激活旧落点并写入两条。
      target.activateResolved(file: oldFile);
      delegate.record(
        _report(message: 'first-pre-swap'),
        ReportAcceptance.newReport,
      );
      delegate.record(
        _report(message: 'second-pre-swap'),
        ReportAcceptance.newReport,
      );
      await _waitForFileContains(oldFile, 'second-pre-swap');

      // Act — 新目录真实可写（validate 现场创建+探测）。
      final newDir = Directory('${root.path}${Platform.pathSeparator}new');
      final result = await target.apply(newDir.path);
      final newFile = File(
        '${newDir.path}${Platform.pathSeparator}'
        '${ErrorLogLocation.logFileName}',
      );
      delegate.record(
        _report(eventId: 'event-post', message: 'post-swap'),
        ReportAcceptance.newReport,
      );
      await _waitForFileContains(newFile, 'post-swap');

      // Assert — 旧文件恰含前两条、新文件含 apply 之后的记录、双路径同步。
      expect(result, isA<ConfiguredDirectoryValid>());
      final oldContents = await oldFile.readAsString();
      expect(oldContents, contains('first-pre-swap'));
      expect(oldContents, contains('second-pre-swap'));
      expect(
        oldContents.indexOf('first-pre-swap'),
        lessThan(oldContents.indexOf('second-pre-swap')),
      );
      expect((await newFile.readAsString()), contains('post-swap'));
      expect(target.effectiveLogPath.value, newFile.path);
      expect(delegate.logPath.value, newFile.path);
      // D-03：校验通过即保存。
      expect(ErrorFeedbackSettings.I.state.value.logDirectory, newDir.path);
    });

    test('record arriving in the swap gap flushes into the new file', () async {
      // Arrange — 旧 sink 写入被 gate 卡住，制造可观察的 dispose 间隙。
      final gate = Completer<void>();
      var writerEntries = 0;
      final slowOldSink = ErrorLogFileSink(
        file: oldFile,
        writer: (pack) async {
          writerEntries += 1;
          await gate.future;
        },
      );
      delegate.activate(sink: slowOldSink, resolvedPath: oldFile.path);
      delegate.record(
        _report(message: 'gap-pre-one'),
        ReportAcceptance.newReport,
      );
      delegate.record(
        _report(message: 'gap-pre-two'),
        ReportAcceptance.newReport,
      );
      await _waitUntil(() async => writerEntries >= 1);

      final newDir = Directory('${root.path}${Platform.pathSeparator}new');
      final newFile = File(
        '${newDir.path}${Platform.pathSeparator}'
        '${ErrorLogLocation.logFileName}',
      );
      final swap = target.apply(newDir.path);

      // Act — dispose 的同步副作用（logPath=null）出现后注入间隙记录。
      await _waitUntil(() async => delegate.logPath.value == null);
      delegate.record(
        _report(eventId: 'event-gap', message: 'gap-mid-swap'),
        ReportAcceptance.newReport,
      );
      gate.complete();
      await swap;
      await _waitForFileContains(newFile, 'gap-mid-swap');
      await _waitForFileContains(oldFile, 'gap-pre-two');

      // Assert — 旧链两条完整落在旧文件，间隙记录经 pending FIFO 补发到新文件。
      final oldContents = await oldFile.readAsString();
      expect(oldContents, contains('gap-pre-one'));
      expect(
        oldContents.indexOf('gap-pre-one'),
        lessThan(oldContents.indexOf('gap-pre-two')),
      );
      expect(target.effectiveLogPath.value, newFile.path);
      expect(delegate.logPath.value, newFile.path);
    });

    test('invalid path: no save, no swap, no notice; old sink keeps serving',
        () async {
      // Arrange
      target.activateResolved(file: oldFile);
      delegate.record(
        _report(message: 'before-invalid'),
        ReportAcceptance.newReport,
      );
      await _waitForFileContains(oldFile, 'before-invalid');
      final pathHistory = <String?>[];
      delegate.logPath.addListener(
        () => pathHistory.add(delegate.logPath.value),
      );
      // 被同名文件占据的路径（实测 PathExistsException 形态）。
      final blocker = File('${root.path}${Platform.pathSeparator}occupied');
      await blocker.writeAsString('not a directory');

      // Act
      final result = await target.apply(
        '${blocker.path}${Platform.pathSeparator}sub',
      );

      // Assert — 三不：不保存 / 不换位 / 不通知。
      final invalid = result as ConfiguredDirectoryInvalid;
      expect(invalid.reason, ConfiguredDirectoryFailure.notWritable);
      expect(ErrorFeedbackSettings.I.state.value.logDirectory, '');
      expect(target.effectiveLogPath.value, oldFile.path);
      expect(delegate.logPath.value, oldFile.path);
      expect(pathHistory, isEmpty);
      expect(target.pendingFallbackNotice.value, isNull);
      // 旧 sink 仍可正常落盘。
      delegate.record(
        _report(eventId: 'event-invalid', message: 'still-old'),
        ReportAcceptance.newReport,
      );
      await _waitForFileContains(oldFile, 'still-old');
    });

    test('empty string falls back to the default chain and redirects',
        () async {
      // Arrange — 旧落点先激活并写入一条，确认旧链在服务。
      target.activateResolved(file: oldFile);
      delegate.record(
        _report(message: 'seed'),
        ReportAcceptance.newReport,
      );
      await _waitForFileContains(oldFile, 'seed');

      // Act — '' = 走默认链（setUp 注入的 exe 层真实可写）。
      final result = await target.apply('');

      // Assert — 保存 ''、重定向到链结果（exe 根 logs/error.log）。
      expect(result, isA<ConfiguredDirectoryValid>());
      expect(ErrorFeedbackSettings.I.state.value.logDirectory, '');
      final chainFile = File(
        '${root.path}${Platform.pathSeparator}exe'
        '${Platform.pathSeparator}logs'
        '${Platform.pathSeparator}${ErrorLogLocation.logFileName}',
      );
      expect(target.effectiveLogPath.value, chainFile.path);
      expect(delegate.logPath.value, chainFile.path);
    });

    test('unresolved default chain keeps the old sink alive (no dispose)',
        () async {
      // Arrange — 激活旧落点后重绑失败形态：exe 层被文件占据 + AS provider 抛出。
      target.activateResolved(file: oldFile);
      delegate.record(
        _report(message: 'before-unresolved'),
        ReportAcceptance.newReport,
      );
      await _waitForFileContains(oldFile, 'before-unresolved');
      final pathHistory = <String?>[];
      delegate.logPath.addListener(
        () => pathHistory.add(delegate.logPath.value),
      );
      final blocker = File('${root.path}${Platform.pathSeparator}blocker');
      await blocker.writeAsString('not a directory');
      rebind(
        delegate,
        applicationSupportDirectory: () async =>
            throw const FileSystemException('as unavailable'),
        executableDirectory: () => Directory(blocker.path),
      );

      // Act
      final result = await target.apply('');

      // Assert — resolve 失败：Invalid 且旧 sink 未被 dispose、继续可落盘。
      final invalid = result as ConfiguredDirectoryInvalid;
      expect(invalid.reason, ConfiguredDirectoryFailure.notWritable);
      expect(pathHistory, isEmpty);
      expect(delegate.logPath.value, oldFile.path);
      delegate.record(
        _report(eventId: 'event-unresolved', message: 'still-serving'),
        ReportAcceptance.newReport,
      );
      await _waitForFileContains(oldFile, 'still-serving');
    });

    test('same-directory apply is idempotent without dispose or activate',
        () async {
      // Arrange — 当前生效目录即 oldDir。
      target.activateResolved(file: oldFile);
      delegate.record(
        _report(message: 'idempotent-seed'),
        ReportAcceptance.newReport,
      );
      await _waitForFileContains(oldFile, 'idempotent-seed');
      final pathHistory = <String?>[];
      delegate.logPath.addListener(
        () => pathHistory.add(delegate.logPath.value),
      );

      // Act — 对已生效的同一目录再次 apply。
      final result = await target.apply(oldDir.path);

      // Assert — 幂等：有效路径不变、无 dispose/activate 痕迹、不保存。
      expect(result, isA<ConfiguredDirectoryValid>());
      expect(target.effectiveLogPath.value, oldFile.path);
      expect(delegate.logPath.value, oldFile.path);
      expect(pathHistory, isEmpty);
      expect(ErrorFeedbackSettings.I.state.value.logDirectory, '');
    });

    test('activateResolved activates the delegate and raises a one-shot notice',
        () async {
      // Act — 启动激活语义：携带 configuredFailure 激活。
      final failure = const FileSystemException('configured boom');
      target.activateResolved(file: oldFile, configuredFailure: failure);

      // Assert — delegate 与协调器路径同步，通知置值一次。
      expect(delegate.logPath.value, oldFile.path);
      expect(target.effectiveLogPath.value, oldFile.path);
      expect(target.pendingFallbackNotice.value, same(failure));

      // 消费后清空。
      target.consumeFallbackNotice();
      expect(target.pendingFallbackNotice.value, isNull);

      // 重绑新 delegate 后再次激活且无 configuredFailure → 不再置值。
      final nextDelegate = DelegatingDiagnosticLogEffect();
      final nextDir = Directory('${root.path}${Platform.pathSeparator}next');
      await nextDir.create();
      rebind(nextDelegate);
      target.activateResolved(file: nextFileOf(nextDir));
      expect(nextDelegate.logPath.value, nextFileOf(nextDir).path);
      expect(target.pendingFallbackNotice.value, isNull);
    });

    test('a pending notice is not overwritten by a later failure', () async {
      // Arrange — 第一次回退通知尚未消费。
      final first = const FileSystemException('first boom');
      final second = const FileSystemException('second boom');
      target.activateResolved(file: oldFile, configuredFailure: first);

      // Act — 换位激活携带第二个 failure（通知仍在挂起）。
      final nextDelegate = DelegatingDiagnosticLogEffect();
      final nextDir = Directory('${root.path}${Platform.pathSeparator}next');
      await nextDir.create();
      rebind(nextDelegate);
      target.activateResolved(file: nextFileOf(nextDir), configuredFailure: second);

      // Assert — 仅 null→值 转换：保持第一个通知。
      expect(target.pendingFallbackNotice.value, same(first));
    });
  });
}

/// 组合一个候选目录下的诊断日志文件路径（与协调器落点形态一致）。
File nextFileOf(Directory directory) => File(
      '${directory.path}${Platform.pathSeparator}'
      '${ErrorLogLocation.logFileName}',
    );

/// 有界等待：条件满足即返回，超时 fail（防测试悬挂）。
Future<void> _waitUntil(Future<bool> Function() condition) async {
  const tick = Duration(milliseconds: 5);
  const budget = Duration(seconds: 10);
  for (var waited = Duration.zero; waited < budget; waited += tick) {
    if (await condition()) {
      return;
    }
    await Future<void>.delayed(tick);
  }
  fail('condition not met within the wait budget');
}

/// 等待文件存在且包含指定内容（fire-and-forget 写链的测试等待点）。
Future<void> _waitForFileContains(File file, String needle) async {
  await _waitUntil(() async {
    if (!file.existsSync()) {
      return false;
    }
    return (await file.readAsString()).contains(needle);
  });
}

var _sequence = 0;

/// 构造可直接进入 delegate.record 的错误级报告（循 sink 测试 fixture 形态）。
ErrorReport _report({String? eventId, required String message}) {
  final occurredAt = DateTime.utc(2026, 8, 31, 12);
  return ErrorReport(
    eventId: eventId ?? 'event-${_sequence++}',
    source: ErrorSource.platformDispatcher,
    severity: ErrorSeverity.error,
    firstOccurredAt: occurredAt,
    lastOccurredAt: occurredAt,
    errorType: 'StateError',
    playerErrorCode: null,
    message: message,
    rawStackTrace: 'raw stack',
    mediaPath: null,
    occurrenceCount: 1,
  );
}
