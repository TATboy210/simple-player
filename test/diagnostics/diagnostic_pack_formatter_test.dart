/// Security and boundary tests for stable diagnostic-pack formatting.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/diagnostic_pack_formatter.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_location.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_report.dart';

void main() {
  group('formatDiagnosticPack', () {
    test(
      'escapes hostile single-line values without creating extra sections',
      () {
        // Arrange
        const hostile = 'message\r\n== Forged ==\nnext';
        final report = _report(message: hostile);

        // Act
        final pack = formatDiagnosticPack(
          report,
          logPath: 'C:/logs\n== forged',
        );

        // Assert
        expect(pack, contains(r'Message: message\r\n== Forged ==\nnext'));
        expect(pack, contains(r'Path: C:/logs\n== forged'));
        expect(RegExp(r'^== ', multiLine: true).allMatches(pack), hasLength(7));
      },
    );

    test('renders location source and full path evidence without live lookups', () {
      // Arrange
      final report = _report(
        fullMediaPath: 'C:/Videos/current.mp4',
        failedOpenPath: 'D:/Attempts/failed.mp4',
        location: ErrorLocation(
          primaryFrame: const ErrorLocationFrame(
            file: 'package:simple_player_flutter/primary.dart',
            packageScheme: 'package',
            package: projectPackageName,
            packagePath: 'primary.dart',
            line: 11,
            column: 2,
            member: 'Primary.run',
          ),
          secondaryFrames: const [
            ErrorLocationFrame(
              file: 'package:simple_player_flutter/secondary.dart',
              packageScheme: 'package',
              package: projectPackageName,
              packagePath: 'secondary.dart',
              line: 21,
              column: 2,
              member: 'Secondary.run',
            ),
          ],
          sourceLines: const ['10: alpha', '11: target', '12: omega'],
        ),
      );

      // Act
      final pack = formatDiagnosticPack(report);

      // Assert
      expect(pack, contains('Current Media Full Path: C:/Videos/current.mp4'));
      expect(pack, contains('Failed Open Path: D:/Attempts/failed.mp4'));
      expect(
        pack,
        contains(
          'Primary: package:simple_player_flutter/primary.dart:11 Primary.run',
        ),
      );
      expect(
        pack,
        contains(
          'Secondary: package:simple_player_flutter/secondary.dart:21 Secondary.run',
        ),
      );
      expect(pack, contains('10: alpha'));
      expect(pack, contains('11: target'));
      expect(pack, contains('12: omega'));
    });

    test(
      'retains the raw stack character-for-character as terminal evidence',
      () {
        // Arrange
        const rawStack = 'raw\r\n== Stack-controlled text ==\n中文 evidence';
        final report = _report(rawStackTrace: rawStack);

        // Act
        final pack = formatDiagnosticPack(report);

        // Assert
        expect(pack, endsWith(rawStack));
        expect(
          pack.substring(pack.indexOf('== Raw Stack ==\n') + 16),
          rawStack,
        );
      },
    );
  });

  group('formatDiagnosticPack redactPaths (F11 剪贴板脱敏)', () {
    test('redacts the three developer path fields to basenames', () {
      // Arrange
      final report = _report(
        fullMediaPath: 'C:/Users/bob/Videos/current.mp4',
        failedOpenPath: 'D:/Attempts/failed.mp4',
      );

      // Act
      final pack = formatDiagnosticPack(
        report,
        logPath: 'C:/Users/bob/logs/error.log',
        redactPaths: true,
      );

      // Assert：三路径字段只留 basename —— 目录段（含用户名）不进剪贴板。
      expect(pack, contains('Current Media Full Path: current.mp4'));
      expect(pack, contains('Failed Open Path: failed.mp4'));
      expect(pack, contains('Path: error.log'));
      expect(pack, isNot(contains('C:/Users/bob')));
      expect(pack, isNot(contains('D:/Attempts')));
    });

    test('keeps default output byte-identical to the durable log format', () {
      // Arrange
      final report = _report(
        fullMediaPath: 'C:/Videos/current.mp4',
        failedOpenPath: 'D:/Attempts/failed.mp4',
      );
      const logPath = 'C:/logs/error.log';

      // Act
      final defaultPack = formatDiagnosticPack(report, logPath: logPath);
      final explicitFalsePack = formatDiagnosticPack(
        report,
        logPath: logPath,
        redactPaths: false,
      );

      // Assert：默认（不传参）输出逐字符保持既有落盘格式 —— 两个日志文件
      // 写入口（error_log_file_sink / isolated_error_log_sink 不传参）零改动
      // 回归锁；三路径原样保留。
      expect(defaultPack, explicitFalsePack);
      expect(
        defaultPack,
        contains('Current Media Full Path: C:/Videos/current.mp4'),
      );
      expect(defaultPack, contains('Failed Open Path: D:/Attempts/failed.mp4'));
      expect(defaultPack, contains('Path: C:/logs/error.log'));
    });

    test('redacts CJK/space/deep-directory paths to the final component', () {
      // Arrange：中文 + 空格 + 深目录混合形态。
      final report = _report(fullMediaPath: r'D:\影 库\a b\c.mkv');

      // Act
      final pack = formatDiagnosticPack(report, redactPaths: true);

      // Assert
      expect(pack, contains(r'Current Media Full Path: c.mkv'));
      expect(pack, isNot(contains(r'影 库')));
    });

    test('redacts file:// URIs after percent-decoding', () {
      // Arrange
      final report = _report(
        fullMediaPath: 'file:///D:/%E5%BD%B1%20%E5%BA%93/a%20b/c.mkv',
      );

      // Act
      final pack = formatDiagnosticPack(report, redactPaths: true);

      // Assert：file URI 解码后同样只留最终组件。
      expect(pack, contains('Current Media Full Path: c.mkv'));
      expect(pack, isNot(contains('%E5%BD%B1')));
    });

    test('leaves http(s) URLs untouched even when redacting', () {
      // Arrange：网络 URL 不是本地路径 —— 不脱敏。
      const url = 'https://example.com/videos/movie.mkv';
      final report = _report(fullMediaPath: url);

      // Act
      final pack = formatDiagnosticPack(report, redactPaths: true);

      // Assert
      expect(pack, contains('Current Media Full Path: $url'));
    });
  });
}

/// Creates an immutable report with deliberately configurable hostile fields.
ErrorReport _report({
  String message = 'message',
  String rawStackTrace = 'stack',
  String? fullMediaPath,
  String? failedOpenPath,
  ErrorLocation? location,
}) {
  final occurredAt = DateTime.utc(2026, 8, 30, 12);
  return ErrorReport(
    eventId: 'event\n== fake',
    source: ErrorSource.platformDispatcher,
    severity: ErrorSeverity.error,
    firstOccurredAt: occurredAt,
    lastOccurredAt: occurredAt,
    errorType: 'State\rError',
    playerErrorCode: 'code\nvalue',
    message: message,
    rawStackTrace: rawStackTrace,
    mediaPath: 'C:/media\r\n== fake',
    fullMediaPath: fullMediaPath,
    failedOpenPath: failedOpenPath,
    location: location,
    occurrenceCount: 1,
  );
}
