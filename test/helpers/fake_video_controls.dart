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
    this.isFullscreen = false,
    this.isMounted = true,
    this.subtitlePadding = EdgeInsets.zero,
  }) : player = player ?? FakePlayerControls();

  @override
  final FakePlayerControls player;

  @override
  bool isFullscreen;

  @override
  bool isMounted;

  @override
  EdgeInsets subtitlePadding;

  int toggleFullscreenCallCount = 0;
  int exitFullscreenCallCount = 0;
  EdgeInsets? lastSubtitlePadding;

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
    lastSubtitlePadding = padding;
  }

  /// 关闭 fake Player 的全部 broadcast stream。
  void dispose() => player.dispose();
}
