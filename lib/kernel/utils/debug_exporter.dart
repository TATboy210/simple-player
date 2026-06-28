import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'debug_probe.dart';
import 'log.dart';
import 'memory_monitor.dart';

/// 统一调试数据导出 — 一键收集所有诊断信息。
///
/// 用法：
/// ```dart
/// final json = DebugExporter.exportAll();
/// await DebugExporter.saveToFile();
/// ```
class DebugExporter {
  DebugExporter._();

  /// 收集所有调试数据为 JSON 字符串。
  static String exportAll() {
    return jsonEncode({
      'memory': _memorySnapshot(),
      'probes': _probeSummary(),
      'exportedAt': DateTime.now().toIso8601String(),
      'mode': kDebugMode ? 'debug' : 'release',
    });
  }

  /// 导出并保存到文件。
  ///
  /// 文件路径：`%APPDATA%/SimplePlayer/debug/debug_<timestamp>.json`
  /// 返回保存的文件路径。
  static Future<String?> saveToFile() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final dir = Directory('${appDir.path}/debug');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(RegExp(r'[:.]'), '-')
          .replaceAll('T', '_');
      final file = File('${dir.path}/debug_$timestamp.json');
      await file.writeAsString(exportAll(), flush: true);
      log.i('[DebugExporter] saved to ${file.path}');
      return file.path;
    } on Exception catch (e) {
      log.e('[DebugExporter] saveToFile failed: $e');
      return null;
    }
  }

  static Map<String, Object>? _memorySnapshot() {
    final snap = MemoryMonitor.snapshot();
    return snap?.toJson();
  }

  static Map<String, Map<String, Object>> _probeSummary() {
    return DebugProbeRegistry.summary();
  }
}
