import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/runtime_environment_report.dart';

void main() {
  late Directory dir;
  final report = RuntimeEnvironmentReport.I;

  setUp(() {
    report.resetForTesting();
    dir = Directory.systemTemp.createTempSync('env_report_');
  });

  tearDown(() {
    report.resetForTesting();
    dir.deleteSync(recursive: true);
  });

  File envFile() => File('${dir.path}/${RuntimeEnvironmentReport.fileName}');

  test('entries recorded before attach are flushed on attach', () {
    report.record('render.backend', 'software');
    expect(envFile().existsSync(), isFalse, reason: '未 attach 只存内存');

    report.attach(dir);

    expect(envFile().readAsStringSync(), 'render.backend: software\n');
  });

  test('later records rewrite the file, overwriting same key in place', () {
    report.attach(dir);
    report
      ..record('a', '1')
      ..record('decode.hwdec', 'd3d11va')
      ..record('a', '2');

    expect(envFile().readAsStringSync(), 'a: 2\ndecode.hwdec: d3d11va\n');
  });

  test('newlines in values are folded to keep one entry per line', () {
    report.attach(dir);
    report.record('render.reason', 'vkCreateInstance failed\r\nno ICD');

    expect(
      envFile().readAsStringSync(),
      'render.reason: vkCreateInstance failed no ICD\n',
    );
  });
}
