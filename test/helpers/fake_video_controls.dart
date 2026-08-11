import 'package:flutter/material.dart';
import 'package:simple_player_flutter/ui/player/player_video_controls.dart';

import 'fake_player_controls.dart';

/// `PlayerVideoControls` 的纯 Dart 视频 route 测试替身。
///
/// 它记录全屏与字幕安全区调用，同时复用 [FakePlayerControls] 模拟
/// media_kit Player stream，不加载 libmpv 或平台插件。
final class FakeVideoControlsPort implements VideoControlsPort {
  FakeVideoControlsPort({
    FakePlayerControls? player,
    bool isFullscreen = false,
    this.isMounted = true,
    this.subtitlePadding = EdgeInsets.zero,
  }) : _isFullscreen = isFullscreen,
       player = player ?? FakePlayerControls();

  @override
  final FakePlayerControls player;

  bool _isFullscreen;

  /// 记录 fullscreen 状态读取，便于验证 lifecycle guard 不查询 inactive VideoState。
  int isFullscreenReadCount = 0;

  @override
  bool get isFullscreen {
    isFullscreenReadCount++;
    return _isFullscreen;
  }

  set isFullscreen(bool value) => _isFullscreen = value;

  @override
  bool isMounted;

  @override
  EdgeInsets subtitlePadding;

  int toggleFullscreenCallCount = 0;
  int exitFullscreenCallCount = 0;
  int subtitlePaddingCallCount = 0;
  EdgeInsets? lastSubtitlePadding;
  final List<EdgeInsets> subtitlePaddingHistory = <EdgeInsets>[];

  @override
  void toggleFullscreen() {
    toggleFullscreenCallCount++;
  }

  @override
  void exitFullscreen() {
    exitFullscreenCallCount++;
  }

  @override
  void setSubtitleViewPadding(EdgeInsets padding) {
    subtitlePaddingCallCount++;
    lastSubtitlePadding = padding;
    subtitlePadding = padding;
    subtitlePaddingHistory.add(padding);
  }

  /// 关闭 fake Player 的全部 broadcast stream。
  void dispose() => player.dispose();
}
