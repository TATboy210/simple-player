import 'package:flutter/foundation.dart';

import '../models/play_mode.dart';
import 'open_result.dart';

/// 队列控制接口 — 播放列表队列的装载、导航与播放模式 (ISP 第 8 facet).
///
/// Queue control facet — playlist loading, navigation and play mode.
///
/// 队列权威是 mpv 原生 playlist (media_kit `Player.open(Playlist)` / `add` /
/// `remove` / `jump`), 本接口是其项目层投影. 实现者 (MediaKitEngine) 订阅
/// `Player.stream.playlist` 把 mpv 侧队列状态镜像到 [queuePaths] / [queueIndex]
/// — 自动续播、坏文件跳过、shuffle 重排等 mpv 原生行为都经该镜像自动同步.
///
/// Contract:
/// - 镜像与 mpv 侧最终一致: 操作方法先行本地乐观更新, stream 广播随后幂等覆盖.
/// - 越界导航是 no-op 并返回 `false`, 不产生任何副作用 (含不唤醒播放).
/// - 方法可在任意可达态调用 (空队列 no-op), 正常失败不抛异常 —
///   经 `lastError` + `state → error` 表达, 与 [PlaybackControl] 同哲学.
abstract class QueueControl {
  /// 装载整个队列并指向 [startIndex] (替换语义: 清掉旧队列再装载).
  ///
  /// requires: paths 非空 (空列表返回 [OpenError])
  /// ensures: 成功时队列镜像已更新、state == idle (调用方随后 play());
  ///   当前播放被替换 (mpv `loadlist` 重建队列).
  /// returns: [OpenSuccess] / [OpenError]; 被新请求取代时 [OpenSuperseded].
  Future<OpenResult> openPlaylist(List<String> paths, {int startIndex});

  /// 追加条目到队列末尾 — 不打断当前播放 (mpv `loadfile append`).
  Future<void> appendToQueue(List<String> paths);

  /// 移除指定索引条目. 删除正在播放条目时 mpv 自动跳转, 经 stream 镜像同步.
  Future<void> removeFromQueue(int index);

  /// 跳到指定索引并播放; 越界 (index ∉ [0, length)) 为 no-op 返回 `false`.
  Future<bool> jumpTo(int index);

  /// 跳到下一个条目.
  ///
  /// 边界语义由实现者按 [playMode] 统一裁定 (不透传 media_kit 内部判断):
  /// - `loopAll` / `shuffle`: 末尾回绕到 0 (随机模式乱序循环)
  /// - `loopSingle`: 用户主动切曲仍正常回绕 (单曲循环只约束自然播完)
  /// - 不循环的 none 语义: 末尾 no-op 返回 `false`
  bool nextInQueue();

  /// 跳到上一个条目 — 边界语义同 [nextInQueue] (镜像方向).
  bool previousInQueue();

  /// 设置播放模式.
  ///
  /// 映射: `loopAll` → PlaylistMode.loop + 无 shuffle;
  /// `loopSingle` → PlaylistMode.single (mpv `loop-file`);
  /// `shuffle` → PlaylistMode.loop + mpv `playlist-shuffle` (乱序循环).
  Future<void> setPlayMode(PlayMode mode);

  // ---- 队列状态镜像 (身份保持 — UI/服务层监听同一实例) ----

  /// 队列条目路径列表 (展示顺序 = mpv 队列顺序, shuffle 重排后随之更新).
  ValueNotifier<List<String>> get queuePaths;

  /// 当前播放条目索引; 空队列 / 无媒体为 -1.
  ValueNotifier<int> get queueIndex;

  /// 队列状态代数 — [queuePaths] / [queueIndex] 任一变更后递增.
  ///
  /// 单通知点: paths 与 index 是两次独立赋值, 分开监听会读到"新列表+旧索引"
  /// 的中间态 (整队列替换时产生虚假切曲). 需要原子观察两者一致状态的服务层
  /// 只监听本 notifier, 触发时再读两者即为一致快照.
  ValueNotifier<int> get queueRevision;

  /// 当前播放模式 — 引擎为单一数据源, Coordinator 重启恢复时经 [setPlayMode] 写回.
  ValueNotifier<PlayMode> get playMode;
}
