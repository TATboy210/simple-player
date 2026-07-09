import 'fullscreen_snapshot.dart';

/// 全屏操作错误 — sealed class 设计，7 种类型可携带上下文。
///
/// 设计约束:
/// - 每种错误类型携带足够的诊断上下文
/// - error 不是锁死态，下次合法操作自动清理
/// - UI 对 PermissionDenied 和 Unsupported 有明确用户提示
sealed class FullscreenError {
  const FullscreenError();

  /// 平台不支持全屏（如 Web 无用户手势）。
  const factory FullscreenError.unsupported(String message) = Unsupported;

  /// 窗口句柄无效。
  const factory FullscreenError.invalidWindow(int windowId) = InvalidWindow;

  /// 权限拒绝（如 Web 手势限制）。
  const factory FullscreenError.permissionDenied(String reason) =
      PermissionDenied;

  /// 过渡忙 — 上一个操作尚未完成。
  const factory FullscreenError.busyTransition(FullscreenPhase currentPhase) =
      BusyTransition;

  /// 平台原生调用失败。
  const factory FullscreenError.platformFailure(
    String platformMessage, [
    Object? originalError,
  ]) = PlatformFailure;

  /// 退出全屏后恢复失败。
  const factory FullscreenError.restoreFailure(FullscreenMode attemptedMode) =
      RestoreFailure;

  /// 状态不同步 — 回读状态与预期不一致。
  const factory FullscreenError.stateDesync({
    required FullscreenMode expected,
    required FullscreenMode actual,
  }) = StateDesync;
}

/// 平台不支持全屏。
final class Unsupported extends FullscreenError {
  const Unsupported(this.message);
  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Unsupported && message == other.message;

  @override
  int get hashCode => message.hashCode;
}

/// 窗口句柄无效。
final class InvalidWindow extends FullscreenError {
  const InvalidWindow(this.windowId);
  final int windowId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvalidWindow && windowId == other.windowId;

  @override
  int get hashCode => windowId.hashCode;
}

/// 权限拒绝。
final class PermissionDenied extends FullscreenError {
  const PermissionDenied(this.reason);
  final String reason;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PermissionDenied && reason == other.reason;

  @override
  int get hashCode => reason.hashCode;
}

/// 过渡忙。
final class BusyTransition extends FullscreenError {
  const BusyTransition(this.currentPhase);
  final FullscreenPhase currentPhase;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BusyTransition && currentPhase == other.currentPhase;

  @override
  int get hashCode => currentPhase.hashCode;
}

/// 平台原生调用失败。
final class PlatformFailure extends FullscreenError {
  const PlatformFailure(this.platformMessage, [this.originalError]);
  final String platformMessage;
  final Object? originalError;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlatformFailure &&
          platformMessage == other.platformMessage &&
          originalError == other.originalError;

  @override
  int get hashCode => Object.hash(platformMessage, originalError);
}

/// 退出全屏后恢复失败。
final class RestoreFailure extends FullscreenError {
  const RestoreFailure(this.attemptedMode);
  final FullscreenMode attemptedMode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RestoreFailure && attemptedMode == other.attemptedMode;

  @override
  int get hashCode => attemptedMode.hashCode;
}

/// 状态不同步。
final class StateDesync extends FullscreenError {
  const StateDesync({required this.expected, required this.actual});
  final FullscreenMode expected;
  final FullscreenMode actual;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StateDesync &&
          expected == other.expected &&
          actual == other.actual;

  @override
  int get hashCode => Object.hash(expected, actual);
}
