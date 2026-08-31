/// 诊断日志落点协调器 —— 校验→保存→dispose→activate 的安全重定向单点。
///
/// UI-layer coordinator owning the SET-02 retarget protocol on top of the
/// stable startup delegate: validate first, save only on success, then swap
/// the sink through the existing public `dispose()` → `activate()` cycle
/// (single-writer semantics untouched, kernel zero change). Startup activation
/// and user-initiated retarget share the same activation implementation
/// ([activateResolved]) so exactly one activation path exists.
///
/// 边界（D-05/D-06）：本协调器不触碰 ErrorReporter、不触碰 ErrorCaptureSnapshot、
/// 不感知错误卡片开关；也不持久化回退原因、不维护 last-known-good key、不做
/// 会话内自动重回退（回退链本身即 last-known-good，原因每次启动重算）。
library;

import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:simple_player_flutter/kernel/diagnostics/error_log_file_sink.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_log_location.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_reporting_dependencies.dart';

import 'error_feedback_settings.dart';

/// 诊断日志落点协调器单例 —— 设置 UI 与组合根共用的重定向协议实现。
final class DiagnosticLogTarget {
  DiagnosticLogTarget._();

  /// 全局单例 —— 循 ErrorCaptureSnapshot.I 形态，跨层共享同一份内存态。
  static final DiagnosticLogTarget I = DiagnosticLogTarget._();

  DelegatingDiagnosticLogEffect? _effect;
  ApplicationSupportDirectoryProvider? _asProvider;
  ExecutableDirectoryProvider? _exeProvider;

  /// UI 的权威有效日志路径 —— 每次 activate 时写入。
  ///
  /// 免疫 dispose 期间 delegate.logPath 的瞬时 null 闪烁（RESEARCH Pattern 2
  /// caveat）：设置 UI 的「当前有效路径」应读此 notifier，而非 delegate 的。
  final ValueNotifier<String?> effectiveLogPath = ValueNotifier<String?>(null);

  /// D-04 一次性回退通知 —— 置值一次、消费即清空；null = 无待通知。
  ///
  /// 仅 null→值 转换：挂起未消费时后到的失败不覆盖，避免通知刷屏。
  final ValueNotifier<Object?> pendingFallbackNotice =
      ValueNotifier<Object?>(null);

  /// 组合根同步绑定：main 在 runApp 之前调用一次，携带两个目录 provider。
  ///
  /// 重复 attach 静默忽略（先绑定者胜）——组合根契约是只调用一次，防御性
  /// 忽略重复调用以免运行中悄然换绑 delegate。
  void attach({
    required DelegatingDiagnosticLogEffect effect,
    required ApplicationSupportDirectoryProvider applicationSupportDirectory,
    required ExecutableDirectoryProvider executableDirectory,
  }) {
    if (_effect != null) {
      return;
    }
    _effect = effect;
    _asProvider = applicationSupportDirectory;
    _exeProvider = executableDirectory;
  }

  /// 唯一激活实现 —— 启动激活与重定向共用（research 单一激活实现 caveat）。
  ///
  /// Side effect: 创建 [ErrorLogFileSink] 并经 delegate.activate 换入（activate
  /// 的一次性锁前置条件由 `_swapTo` 的 dispose 复位保证）；随后同步写
  /// [effectiveLogPath]，configuredFailure 非空时将 [pendingFallbackNotice]
  /// 置值一次（仅 null→值）。
  void activateResolved({required File file, Object? configuredFailure}) {
    final effect = _effect;
    if (effect == null) {
      // attach 未发生属组合根编程错误：不伪造激活状态，也不触碰 notifier
      //（此时任何路径值都是谎言）。生产路径 attach 先于 runApp，不可达。
      return;
    }
    effect.activate(
      sink: ErrorLogFileSink(file: file),
      resolvedPath: file.path,
    );
    effectiveLogPath.value = file.path;
    if (configuredFailure != null && pendingFallbackNotice.value == null) {
      pendingFallbackNotice.value = configuredFailure;
    }
  }

  /// 校验非空目录（D-03 行内校验数据源）；空串返回 Invalid。
  ///
  /// 空串的「回默认链」语义由 [apply] 处理，本方法只管非空输入的形态与
  /// 可写性校验，转发 kernel 单层校验（唯一实现，无第二份探测逻辑）。
  Future<ConfiguredDirectoryValidation> validate(String directory) async {
    if (directory.trim().isEmpty) {
      return const ConfiguredDirectoryInvalid(
        ConfiguredDirectoryFailure.notAbsolute,
      );
    }
    return ErrorLogLocation.validateConfiguredDirectory(directory);
  }

  /// 校验→保存→换位的安全重定向入口（SET-02 配置变更面）。
  ///
  /// 非空输入：校验失败原样返回 Invalid —— 三不：不保存 / 不换位 / 不通知；
  /// 通过后（a）与当前有效落点同目录时幂等返回（无换位副作用），
  /// （b）否则先保存（D-03 discretion：校验通过即保存）再经 [_swapTo] 换位。
  /// 空输入：保存 '' 后走默认三层链（跳过配置层），链结果换位。
  Future<ConfiguredDirectoryValidation> apply(String directory) async {
    final trimmed = directory.trim();
    if (trimmed.isEmpty) {
      return _applyDefaultChain();
    }
    final validation = await validate(trimmed);
    switch (validation) {
      case ConfiguredDirectoryInvalid():
        return validation;
      case ConfiguredDirectoryValid(:final directory):
        final newFile = _logFileIn(directory);
        if (newFile.path == effectiveLogPath.value) {
          // (a) 幂等：同目录不保存、不换位（无副作用返回）。
          return validation;
        }
        // (b) 校验通过即保存（D-03 discretion）——保存失败静默由 store 承担，
        // 内存态不回滚（D-01），随后仍换位（内存态与真实落点一致）。
        ErrorFeedbackSettings.I.setLogDirectory(trimmed);
        await _swapTo(newFile);
        return validation;
    }
  }

  /// 空输入 = 回默认链：保存 '' 后 resolve 三层链（configuredDirectory 省略）。
  ///
  /// resolve 失败返回 Invalid 且**不 dispose** —— 「先确认新位置再换位」消除
  /// 失败窗口（RESEARCH Pattern 2 caveat），旧 sink 继续服务。
  Future<ConfiguredDirectoryValidation> _applyDefaultChain() async {
    final asProvider = _asProvider;
    final exeProvider = _exeProvider;
    if (asProvider == null || exeProvider == null) {
      // 未 attach 属组合根编程错误：折叠为 typed 失败而非伪造成功。
      return ConfiguredDirectoryInvalid(
        ConfiguredDirectoryFailure.notWritable,
        error: StateError('DiagnosticLogTarget is not attached'),
      );
    }
    ErrorFeedbackSettings.I.setLogDirectory('');
    final result = await ErrorLogLocation.resolve(
      applicationSupportDirectory: asProvider,
      executableDirectory: exeProvider,
    );
    switch (result) {
      case ErrorLogLocationResolved(:final file):
        await _swapTo(file);
        return ConfiguredDirectoryValid(file.parent);
      case ErrorLogLocationUnavailable(:final error):
        return ConfiguredDirectoryInvalid(
          ConfiguredDirectoryFailure.notWritable,
          error: error,
        );
    }
  }

  /// 全协调器唯一的 dispose→activate 通道（RESEARCH Pitfall 2：绝不
  /// activate→activate —— activate 的一次性锁只有 dispose 会复位）。
  ///
  /// 1. `dispose()` drain 旧 Future 链 → 旧文件完整收尾（每条记录都是独立
  ///    append、无 OS 句柄残留），同步复位 delegate 的激活锁；
  /// 2. `activateResolved` 换入新 sink —— 换位间隙到达的记录由 delegate 的
  ///    有界 pending FIFO（容量 32，drop-oldest）保序缓冲，activate 时冲刷。
  Future<void> _swapTo(File newFile) async {
    await _effect?.dispose();
    activateResolved(file: newFile);
  }

  /// 组合一个候选目录下的诊断日志文件路径（与链层落点形态一致，不触 I/O）。
  static File _logFileIn(Directory directory) => File(
        '${directory.path}${Platform.pathSeparator}'
        '${ErrorLogLocation.logFileName}',
      );

  /// 消费一次性回退通知（D-04）：置回 null，此后新失败可再次置值。
  void consumeFallbackNotice() {
    pendingFallbackNotice.value = null;
  }

  /// 测试隔离：重绑 effect/provider seam 并清空两个 notifier。
  ///
  /// 非空参数覆盖重绑、空参数保留原值；notifier 恒复位初始态。
  /// 禁止生产路径调用（循 resetForTesting 惯例）。
  @visibleForTesting
  void resetForTesting({
    DelegatingDiagnosticLogEffect? effect,
    ApplicationSupportDirectoryProvider? applicationSupportDirectory,
    ExecutableDirectoryProvider? executableDirectory,
  }) {
    if (effect != null) {
      _effect = effect;
    }
    if (applicationSupportDirectory != null) {
      _asProvider = applicationSupportDirectory;
    }
    if (executableDirectory != null) {
      _exeProvider = executableDirectory;
    }
    effectiveLogPath.value = null;
    pendingFallbackNotice.value = null;
  }
}
