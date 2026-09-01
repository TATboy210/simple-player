/// DiagnosticLogTarget 启动激活的行为测试（G-04-1 收窄后：仅启动激活）。
///
/// Behavioral test for the narrowed coordinator with a real delegate and a
/// real temporary file: attach → single-parameter activateResolved activates
/// the delegate at the injected file. The runtime retarget protocol and the
/// one-shot fallback notice were removed with the log-path configuration
/// feature (G-04-1); zero residue is locked by the Task 2/3 grep gates.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_log_location.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_reporting_dependencies.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/diagnostic_log_target.dart';

void main() {
  group('DiagnosticLogTarget 启动激活（唯一激活面）', () {
    late Directory root;
    late Directory oldDir;
    late File oldFile;
    late DelegatingDiagnosticLogEffect delegate;
    late DiagnosticLogTarget target;

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
      // 复位协调器单例并重绑 effect 缝（provider 形参已随重定向面移除）。
      DiagnosticLogTarget.I.resetForTesting(effect: delegate);
      addTearDown(() => DiagnosticLogTarget.I.resetForTesting());
    });

    test('attach → single-parameter activateResolved activates the delegate '
        'at the injected file', () {
      // Arrange — 组合根契约形态：attach 携带两个目录 provider（签名不变，
      // 重复 attach 先绑定者胜；setUp 已重绑同一 delegate，此处幂等忽略）。
      DiagnosticLogTarget.I.attach(
        effect: delegate,
        applicationSupportDirectory: () async =>
            Directory('${root.path}${Platform.pathSeparator}as'),
        executableDirectory: () =>
            Directory('${root.path}${Platform.pathSeparator}exe'),
      );

      // Act — 启动激活：单参数 activateResolved（无 configuredFailure 形参，
      // sink 构造与 delegate.activate 只存在于协调器内）。
      target.activateResolved(file: oldFile);

      // Assert — delegate 已激活且落点与注入文件一致；有效读数 notifier 与
      // 通知桥已随 G-04-1 移除，无任何通知副作用（零残留由 Task 2/3 grep 门
      // 锁定，此处不引用已删除符号）。
      expect(delegate.logPath.value, oldFile.path);
    });
  });
}
