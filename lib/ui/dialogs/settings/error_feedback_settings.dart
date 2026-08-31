/// 错误反馈设置存储 —— 便携 settings.json（D-01）的加载/保存/内存态单点。
///
/// UI-layer store owning the two error-feedback preferences: the error-card
/// toggle (SET-01) and the diagnostic log directory (SET-02). State is exposed
/// as a ValueNotifier (project convention, no new state library). Persistence
/// is a portable `settings.json` beside the executable — debug runs keep it
/// beside the project directory — and every read/write failure silently keeps
/// the defaults (D-01) so startup and UI are never blocked.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// 不可变错误反馈设置数据 —— settings.json 的内存形态（扁平 key + version）。
final class ErrorFeedbackSettingsData {
  /// 创建设置快照；两个字段都携带 SET-01/SET-02 的默认语义。
  const ErrorFeedbackSettingsData({
    this.errorCardEnabled = true,
    this.logDirectory = '',
  });

  /// SET-01 错误卡片开关 —— 默认开；损坏/缺失文件回退到该值。
  final bool errorCardEnabled;

  /// SET-02 日志目录配置 —— '' 表示走默认链（exe 根 → Application Support）。
  final String logDirectory;

  /// 值相等 —— 损坏回退后的默认快照与初始态可比（不可变数据类契约）。
  @override
  bool operator ==(Object other) =>
      other is ErrorFeedbackSettingsData &&
      other.errorCardEnabled == errorCardEnabled &&
      other.logDirectory == logDirectory;

  @override
  int get hashCode => Object.hash(errorCardEnabled, logDirectory);
}

/// 错误反馈设置单例 store —— 组合根与后续设置 UI 的唯一数据源。
///
/// 同步构造零 I/O（先于 runApp 的任何时点都安全）；加载只发生在组合根的
/// unawaited 激活路径内（RESEARCH Pitfall 7：配置路径当次启动即生效，且绝不
/// 阻塞 MediaKit/window/runApp）。读写失败静默回退默认值（D-01）。
final class ErrorFeedbackSettings {
  ErrorFeedbackSettings._({File Function()? settingsFile})
    : _settingsFile = settingsFile ?? defaultSettingsFile;

  /// 全局单例 —— 循 ErrorCaptureSnapshot.I 形态，跨层共享同一份内存态。
  static final ErrorFeedbackSettings I = ErrorFeedbackSettings._();

  /// D-01 默认文件位置策略：debug 存项目目录旁（flutter run 的 cwd）、
  /// release 存 exe 旁（便携哲学：设置跟着可执行文件走）。
  ///
  /// 构造 File 对象本身零 I/O；kDebugMode 是编译期常量，release 构建里
  /// debug 分支被摇树剔除。注意 flutter clean 会清掉 build/ 下的 debug 日志
  /// 与 build 旁设置，但项目目录（cwd）旁的 debug 设置不受影响。
  static File defaultSettingsFile() {
    final Directory base = kDebugMode
        ? Directory.current
        : File(Platform.resolvedExecutable).parent;
    return File('${base.path}${Platform.pathSeparator}settings.json');
  }

  /// 内存态 —— UI（卡片宿主、设置对话框）与组合根订阅此 notifier。
  final ValueNotifier<ErrorFeedbackSettingsData> state =
      ValueNotifier<ErrorFeedbackSettingsData>(
        const ErrorFeedbackSettingsData(),
      );

  /// settings 文件 seam —— 可被 [resetForTesting] 重绑以隔离测试。
  File Function() _settingsFile;

  /// 从 settings.json 加载设置；任何失败静默保持默认值（D-01）。
  ///
  /// Side effect: settings.json 的 I/O 读取；成功时整体更新 [state]。
  /// 形状校验模板循 source_line_reader.dart:236-268（is! Map 守卫承重：
  /// `[1,2]` 解码为 List 而非 Map；空串/尾随垃圾抛 FormatException）。
  Future<void> load() async {
    try {
      final text = await _settingsFile().readAsString();
      final Object? decoded = jsonDecode(text);
      if (decoded is! Map<String, Object?>) {
        // 形状错误（List/null 等）→ 静默回退默认值。
        return;
      }
      // 逐字段独立类型校验：错型字段回退该字段默认值，不抛出。
      final cardEnabled = decoded['errorCardEnabled'];
      final directory = decoded['logDirectory'];
      state.value = ErrorFeedbackSettingsData(
        errorCardEnabled: cardEnabled is bool ? cardEnabled : true,
        logDirectory: directory is String ? directory : '',
      );
    } on FormatException {
      // 尾随垃圾/空串抛 FormatException（实测失败形态）→ 默认值。
    } on FileSystemException {
      // 无文件/不可读 → 默认值。
    } on Exception {
      // 兜底：任何意外异常都绝不阻断启动（D-01）。
    }
  }

  /// SET-01 开关写入：内存态立即生效，fire-and-forget 持久化。
  void setCardEnabled(bool enabled) {
    final next = ErrorFeedbackSettingsData(
      errorCardEnabled: enabled,
      logDirectory: state.value.logDirectory,
    );
    state.value = next;
    unawaited(_persist(next));
  }

  /// SET-02 日志目录写入：内存态立即更新，fire-and-forget 持久化。
  ///
  /// 保存失败静默（D-01）——不回滚内存态、不阻断调用方。
  void setLogDirectory(String directory) {
    final next = ErrorFeedbackSettingsData(
      errorCardEnabled: state.value.errorCardEnabled,
      logDirectory: directory,
    );
    state.value = next;
    unawaited(_persist(next));
  }

  /// 序列化并落盘当前设置（直写形态；生产加固的原子写见 Task 2）。
  Future<void> _persist(ErrorFeedbackSettingsData next) async {
    try {
      await _settingsFile().writeAsString(_encode(next), flush: true);
    } on Exception {
      // 保存失败静默（D-01）——绝不向调用方抛出、绝不回滚内存态。
    }
  }

  /// 序列化为扁平 key + version 字段的 JSON（D-01 discretion 形态）。
  static String _encode(ErrorFeedbackSettingsData data) =>
      jsonEncode(<String, Object?>{
        'version': 1,
        'errorCardEnabled': data.errorCardEnabled,
        'logDirectory': data.logDirectory,
      });

  /// 测试隔离：复位内存态为默认值并可选重绑 settings 文件 seam。
  ///
  /// 禁止生产路径调用（循 ErrorReporterImpl.resetForTesting 惯例）。
  @visibleForTesting
  void resetForTesting({File Function()? settingsFile}) {
    if (settingsFile != null) {
      _settingsFile = settingsFile;
    }
    state.value = const ErrorFeedbackSettingsData();
  }
}
