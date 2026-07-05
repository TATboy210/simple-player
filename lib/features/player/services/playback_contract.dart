/// Services 层播放契约接口 — 子模块依赖解耦
///
/// 本文件定义 [PlaybackContract] 抽象接口，子模块（PlaybackNavigator / FileOperations /
/// AutoAdvancePolicy / BreakpointSaver）通过此接口访问共享资源，而非直接依赖
/// [PlaybackController] 具体类。
///
/// 架构位置：PlaybackController（实现）→ **PlaybackContract**（接口）← 子模块（消费）
/// 设计模式：Dependency Inversion（依赖反转）— 高层模块不依赖低层模块，两者都依赖抽象
/// 好处：子模块可独立构造和测试，测试时只需 mock PlaybackContract 接口
library;

import '../../../kernel/engine/engine_state.dart';
import '../../../kernel/playlist/playlist.dart';
import 'subtitle_service.dart';

/// 播放子模块的共享依赖契约 — 抽象接口
///
/// 子模块通过此接口访问共享资源，而非直接依赖 [PlaybackController] 具体类。
/// 这使得每个子模块可以独立构造和单元测试。
///
/// 实现方：[PlaybackController] 构造时将 `this` 传给子模块。
/// 测试方：构造 MockPlaybackContract 提供假的 engine / playlist / onError。
abstract interface class PlaybackContract {
  /// 视频渲染引擎 — 子模块通过此访问播放状态和控制方法
  EngineState get engine;

  /// 播放列表 — 子模块通过此访问当前索引和曲目数据
  Playlist get playlist;

  /// 字幕服务（nullable）— 可选依赖，非所有播放路径都有字幕支持
  SubtitleService? get subtitleService;

  /// 错误回调 — 子模块捕获异常时调用（null 表示忽略错误）
  void Function(Object error)? get onError;

  /// UI 重建回调 — 子模块播放列表变更时通知 UI 刷新
  void Function() get onNeedRebuild;

  /// 曲目切换回调 — 文件名变化时通知 UI 更新标题（null 表示不处理）
  void Function(String fileName)? get onTrackChanged;

  /// 保存播放列表 — 跨模块共享的持久化操作
  void savePlaylist();
}
