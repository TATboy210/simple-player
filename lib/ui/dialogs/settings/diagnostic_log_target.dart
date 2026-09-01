/// 诊断日志落点协调器 —— 仅启动激活的最小形态（G-04-1 收窄后）。
///
/// UI-layer coordinator owning the single activation implementation on top
/// of the stable startup delegate: it constructs the sink and swaps it in
/// through `activate()` once at startup. The runtime retarget protocol
/// (validate/save/swap) and the D-04 fallback notice bridge were removed
/// together with the log-path configuration feature — there is no user
/// configurable log directory anymore (D-07), so startup activation is the
/// only activation path.
///
/// 边界（D-05/D-06）：本协调器不触碰 ErrorReporter、不触碰 ErrorCaptureSnapshot、
/// 不感知错误卡片开关。
library;

import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:simple_player_flutter/kernel/diagnostics/error_log_file_sink.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_log_location.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_reporting_dependencies.dart';

/// 诊断日志落点协调器单例 —— 组合根共用的启动激活实现。
final class DiagnosticLogTarget {
  DiagnosticLogTarget._();

  /// 全局单例 —— 循 ErrorCaptureSnapshot.I 形态，跨层共享同一份内存态。
  static final DiagnosticLogTarget I = DiagnosticLogTarget._();

  DelegatingDiagnosticLogEffect? _effect;

  /// 组合根同步绑定：main 在 runApp 之前调用一次，携带两个目录 provider。
  ///
  /// 重复 attach 静默忽略（先绑定者胜）——组合根契约是只调用一次，防御性
  /// 忽略重复调用以免运行中悄然换绑 delegate。provider 形参保留组合根
  /// 调用形态（签名不变），但落点解析已收敛到 main 的 resolve 链，协调器
  /// 只消费 effect 缝。
  void attach({
    required DelegatingDiagnosticLogEffect effect,
    required ApplicationSupportDirectoryProvider applicationSupportDirectory,
    required ExecutableDirectoryProvider executableDirectory,
  }) {
    if (_effect != null) {
      return;
    }
    _effect = effect;
  }

  /// 唯一激活实现 —— 启动激活（G-04-1 后无重定向调用方）。
  ///
  /// Side effect: 创建 [ErrorLogFileSink] 并经 delegate.activate 换入。激活
  /// 只发生一次（activate 的一次性锁）：重复激活被 delegate 锁静默吞掉，
  /// 旧落点保持真实生效 —— 协调器不缓存任何平行读数，权威状态永远在
  /// delegate（effect.logPath）上。
  void activateResolved({required File file}) {
    final effect = _effect;
    if (effect == null) {
      // attach 未发生属组合根编程错误：不伪造激活状态。生产路径 attach
      // 先于 runApp，不可达。
      return;
    }
    effect.activate(sink: ErrorLogFileSink(file: file), resolvedPath: file.path);
  }

  /// 测试隔离：重绑 effect 缝。
  ///
  /// 禁止生产路径调用（循 resetForTesting 惯例）。
  @visibleForTesting
  void resetForTesting({DelegatingDiagnosticLogEffect? effect}) {
    if (effect != null) {
      _effect = effect;
    }
  }
}
