import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 视频显示比例模式
///
/// 控制 Texture 在窗口中的缩放/裁剪行为。
/// [auto_] 和 [stretch] 纯 Flutter 处理；
/// [r16_9] / [r4_3] 需要 mpv 端配合 [video-aspect-override]。
enum AspectMode {
  /// 自动：保持视频源比例，窗口加黑边（默认）
  auto_,

  /// 拉伸：填满窗口，不保持比例
  stretch,

  /// 裁剪填充：保持比例，裁剪超出部分
  fill,

  /// 强制 16:9
  r16_9,

  /// 强制 4:3
  r4_3,
}

/// [AspectMode] 的 UI 扩展
extension AspectModeX on AspectMode {
  String get label => switch (this) {
    AspectMode.auto_   => 'Auto',
    AspectMode.stretch => 'Stretch',
    AspectMode.fill    => 'Fill',
    AspectMode.r16_9   => '16:9',
    AspectMode.r4_3    => '4:3',
  };

  /// 需要通知 mpv 改变内容比例的模式
  bool get needsMpvAspect => this == AspectMode.r16_9 || this == AspectMode.r4_3;

  /// mpv video-aspect-override 值
  ///
  /// `0` = 自动（恢复默认）
  String get mpvAspectValue => switch (this) {
    AspectMode.r16_9 => '16:9',
    AspectMode.r4_3  => '4:3',
    _                => '0',
  };

  BoxFit get boxFit => switch (this) {
    AspectMode.auto_   => BoxFit.contain,
    AspectMode.stretch => BoxFit.fill,
    AspectMode.fill    => BoxFit.cover,
    AspectMode.r16_9   => BoxFit.contain,
    AspectMode.r4_3    => BoxFit.contain,
  };
}

/// 视频渲染表面 — Texture widget 的薄封装
///
/// 职责：
/// 1. 纹理显示（aspect ratio + BoxFit）
/// 2. 状态映射（textureId → 正确的视觉状态）
/// 3. 比例模式切换
///
/// 不持有 MpvRenderService，不订阅 EventBus，不管理纹理生命周期。
class VideoSurface extends StatelessWidget {
  const VideoSurface({
    super.key,
    required this.textureId,
    required this.aspectMode,
    this.videoWidth,
    this.videoHeight,
  });

  /// 纹理 ID，null 表示无媒体
  final int? textureId;

  /// 当前比例模式
  final AspectMode aspectMode;

  /// 视频源宽度（来自 TextureCreated 事件）
  final int? videoWidth;

  /// 视频源高度（来自 TextureCreated 事件）
  final int? videoHeight;

  @override
  Widget build(BuildContext context) {
    final id = textureId;
    if (id == null || id < 0) {
      return const _EmptyState();
    }

    return ColoredBox(
      color: Colors.black,
      child: _buildTexture(id),
    );
  }

  Widget _buildTexture(int textureId) {
    final ratio = _targetRatio();

    // stretch 模式：无比例约束，直接填满
    if (ratio == null) {
      return Texture(textureId: textureId);
    }

    // auto / fill / r16_9 / r4_3：用 AspectRatio 约束
    final srcW = videoWidth?.toDouble() ?? 1920;
    final srcH = videoHeight?.toDouble() ?? 1080;

    return Center(
      child: AspectRatio(
        aspectRatio: ratio,
        child: FittedBox(
          fit: aspectMode.boxFit,
          child: SizedBox(
            width: srcW,
            height: srcH,
            child: Texture(textureId: textureId),
          ),
        ),
      ),
    );
  }

  /// 目标宽高比（null = 无约束）
  double? _targetRatio() {
    return switch (aspectMode) {
      AspectMode.auto_   => _sourceRatio(),
      AspectMode.stretch => null,
      AspectMode.fill    => _sourceRatio(),
      AspectMode.r16_9   => 16 / 9,
      AspectMode.r4_3    => 4 / 3,
    };
  }

  /// 视频源比例（null = 未知，回退到 16:9）
  double? _sourceRatio() {
    if (videoWidth == null || videoHeight == null) return null;
    if (videoHeight! <= 0) return null;
    return videoWidth! / videoHeight!;
  }
}

/// 无媒体加载时的空状态
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 64,
              color: Color(0x3DFFFFFF), // white 24%
            ),
            SizedBox(height: 16),
            Text(
              'No media loaded',
              style: TextStyle(
                color: Color(0x3DFFFFFF),
                fontSize: Tokens.fontCaption,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
