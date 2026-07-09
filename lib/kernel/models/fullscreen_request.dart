import 'fullscreen_snapshot.dart';

/// 全屏操作请求 — 命令队列的输入类型。
///
/// 设计约束:
/// - 不可变值对象
/// - 工厂构造函数提供语义化创建
/// - Phase B 命令队列使用此类型作为入参
sealed class FullscreenRequest {
  const FullscreenRequest({required this.windowId});

  /// 目标窗口 ID（单窗口默认 0）。
  final int windowId;

  /// 进入全屏。
  const factory FullscreenRequest.enter({
    FullscreenMode mode,
    int windowId,
  }) = EnterFullscreen;

  /// 退出全屏。
  const factory FullscreenRequest.leave({
    int windowId,
  }) = LeaveFullscreen;

  /// 切换全屏状态。
  const factory FullscreenRequest.toggle({
    FullscreenMode? preferredMode,
    int windowId,
  }) = ToggleFullscreen;
}

/// 进入全屏请求。
final class EnterFullscreen extends FullscreenRequest {
  const EnterFullscreen({
    this.mode = FullscreenMode.borderless,
    super.windowId = 0,
  });
  final FullscreenMode mode;
}

/// 退出全屏请求。
final class LeaveFullscreen extends FullscreenRequest {
  const LeaveFullscreen({super.windowId = 0});
}

/// 切换全屏请求。
final class ToggleFullscreen extends FullscreenRequest {
  const ToggleFullscreen({this.preferredMode, super.windowId = 0});
  final FullscreenMode? preferredMode;
}
