/// 稳定、可复制的诊断包文本 formatter。
///
/// Pure formatter shared by durable file evidence and future copy actions.
library;

import 'diagnostic_redactor.dart';
import 'error_location.dart';
import 'error_report.dart';

/// 将已接纳报告格式化为固定分段的纯文本诊断包。
///
/// Formats an accepted report into a stable segmented plain-text diagnostic
/// pack. Raw stack evidence is deliberately appended last and never escaped.
///
/// [redactPaths] 仅供剪贴板导出（F11 用户裁决 2026-10-09）：true 时三个开发
/// 证据路径字段（Current Media Full Path / Failed Open Path / Log Path）过
/// [DiagnosticRedactor.redactPathValue] 只留 basename；默认 false 保持落盘
/// 日志逐字符不变 —— LOG-05 契约修订为「卡内复制 == 脱敏变体」。网络 URL
/// 不是本地路径，红处同样原样保留。
String formatDiagnosticPack(
  ErrorReport report, {
  String? logPath,
  bool redactPaths = false,
}) {
  final buffer = StringBuffer()
    ..writeln('== Report ==')
    ..writeln('Event ID: ${_singleLine(report.eventId)}')
    ..writeln('Source: ${_singleLine(report.source.name)}')
    ..writeln('Severity: ${_singleLine(report.severity.name)}')
    ..writeln('Error Type: ${_singleLine(report.errorType)}')
    ..writeln(
      'Player Error Code: ${_singleLine(report.playerErrorCode ?? 'none')}',
    )
    ..writeln('Message: ${_singleLine(report.message)}')
    ..writeln()
    ..writeln('== Timing ==')
    ..writeln(
      'First Occurred: ${_singleLine(report.firstOccurredAt.toUtc().toIso8601String())}',
    )
    ..writeln(
      'Last Occurred: ${_singleLine(report.lastOccurredAt.toUtc().toIso8601String())}',
    )
    ..writeln()
    ..writeln('== Media ==')
    ..writeln('Path: ${_singleLine(report.mediaPath ?? 'none')}')
    // Developer evidence is explicitly separate from the ordinary safe path.
    // F11: 仅这三个开发证据字段参与 redactPaths 脱敏。
    ..writeln(
      'Current Media Full Path: ${_pathField(report.fullMediaPath, redactPaths)}',
    )
    ..writeln(
      'Failed Open Path: ${_pathField(report.failedOpenPath, redactPaths)}',
    )
    ..writeln()
    ..writeln('== Location ==');

  _writeLocation(buffer, report.location);
  buffer
    ..writeln()
    ..writeln('== Repetition ==')
    ..writeln('Occurrence Count: ${report.occurrenceCount}')
    ..writeln()
    ..writeln('== Log Path ==')
    ..writeln(
      'Path: ${logPath == null ? 'unavailable' : _pathField(logPath, redactPaths)}',
    )
    ..writeln()
    ..writeln('== Raw Stack ==')
    ..write(report.rawStackTrace);
  return buffer.toString();
}

/// 单个路径字段格式化 —— redactPaths 时过 [DiagnosticRedactor.redactPathValue]
/// 留 basename（本地路径/file URI），再统一单行转义；null 降级 'none'。
String _pathField(String? value, bool redactPaths) {
  if (value == null) return 'none';
  return _singleLine(
    redactPaths ? DiagnosticRedactor.redactPathValue(value) : value,
  );
}

/// Writes the explicit degraded location text until trusted extraction arrives.
void _writeLocation(StringBuffer buffer, ErrorLocation? location) {
  if (location == null) {
    buffer.writeln('Primary: No project frame; see raw stack for details.');
    return;
  }

  buffer.writeln('Primary: ${_frameText(location.primaryFrame)}');
  for (final frame in location.secondaryFrames) {
    buffer.writeln('Secondary: ${_frameText(frame)}');
  }
  if (location.sourceLines.isNotEmpty) {
    buffer.writeln('Source Lines:');
    for (final line in location.sourceLines) {
      buffer.writeln(_singleLine(line));
    }
  }
}

/// Formats one immutable frame without allowing control text into field lines.
String _frameText(ErrorLocationFrame frame) =>
    '${_singleLine(frame.file)}:${frame.line} ${_singleLine(frame.member)}';

/// Confines untrusted field values to their own line so they cannot forge packs.
String _singleLine(String value) =>
    value.replaceAll('\r', r'\r').replaceAll('\n', r'\n');
