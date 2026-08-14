/// 播放状态管理 — 维护单文件播放器的运行时生命周期状态。
///
/// 用户设置已移除，因此该服务不执行跨会话读取或写入。
library;

/// 单文件播放器状态管理器 — 运行时生命周期占位模块。
class PlaybackStateManager {
  const PlaybackStateManager();

  /// 标记运行时状态管理器已初始化。
  ///
  /// 用户设置已移除，音量和静音由引擎默认值管理。
  Future<void> init() async {}

  /// 释放运行时状态管理器。
  void dispose() {
    // 无持久化副作用；引擎资源由 PlaybackController 统一释放。
  }
}
