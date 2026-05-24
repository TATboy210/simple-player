import 'package:flutter/foundation.dart';

import '../../../kernel/engine/media_engine.dart';
import '../../../kernel/playlist/playlist.dart';

/// 播放控制器公共契约
///
/// 归纳 3 个 mixin（FileOperations、PlaybackNavigator、StateMonitor）
/// 共享的抽象成员，消除隐式依赖。新 mixin 作者只需阅读此文件
/// 即可了解所有前置条件。
abstract class PlaybackContract {
  MediaEngine get engine;
  Playlist get playlist;
  ValueNotifier<String> get currentFileName;
  VoidCallback get onNeedRebuild;
  void Function(Object error)? get onError;

  /// 播放指定索引
  Future<void> playIndex(int index);

  /// 播放下一首
  Future<void> playNext();

  /// 保存播放列表（异步防抖写入）
  void savePlaylist();
}
