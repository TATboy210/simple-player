/// 运行环境报告 — 跨机器排障用的纯文本快照 (`logs/environment.txt`).
///
/// Records which runtime path this machine actually took — OS, render
/// backend and its fallback reason, hardware decoder in use — as a flat
/// `key: value` text file next to `error.log`. Release builds route
/// [KernelLogger] to a NullSink, so without this file a user report like
/// "stutters on my laptop" carries no evidence of software rendering or
/// a failed hwdec. Unix tenet 5: human-readable flat text.
///
/// 生命周期: 引擎随时 [record] (先于落点解析也安全, 只存内存); 组合根解析
/// 出日志目录后 [attach], 此后每次 record 整文件重写 (条目极少, 一次几百
/// 字节, 发生在启动与首个文件加载, 不在热路径).
library;

import 'dart:io';

import 'kernel_logger.dart';

/// 进程级单例 — 一个进程只有一份运行环境.
final class RuntimeEnvironmentReport {
  RuntimeEnvironmentReport._();

  static final RuntimeEnvironmentReport I = RuntimeEnvironmentReport._();

  /// 文件名 — 与 error.log 同目录.
  static const fileName = 'environment.txt';

  /// 插入序保留 (LinkedHashMap) — 文件按记录先后排列, 便于人读.
  final Map<String, String> _entries = <String, String>{};
  File? _file;

  /// 当前条目只读视图 (测试与诊断导出用).
  Map<String, String> get entries => Map.unmodifiable(_entries);

  /// 记录/覆盖一项; 值内换行折叠为空格保持一行一项.
  /// side effect: 已 attach 时同步重写文件.
  void record(String key, String value) {
    _entries[key] = value.replaceAll(RegExp(r'[\r\n]+'), ' ');
    _flush();
  }

  /// 绑定输出目录 (error.log 所在目录) 并立即写出已缓存条目.
  void attach(Directory directory) {
    _file = File('${directory.path}${Platform.pathSeparator}$fileName');
    _flush();
  }

  /// 测试复位 — 清空条目并解绑文件.
  void resetForTesting() {
    _entries.clear();
    _file = null;
  }

  void _flush() {
    final file = _file;
    if (file == null) return;
    final text = StringBuffer();
    _entries.forEach((k, v) => text.writeln('$k: $v'));
    try {
      file.writeAsStringSync(text.toString(), flush: true);
    } on FileSystemException catch (error) {
      // 诊断旁路: 写失败不影响播放, 只降级为控制台记录.
      KernelLogger.I.w('environment.txt 写入失败: ${error.message}');
    }
  }
}
