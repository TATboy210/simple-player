/// 播放列表 UI 本地常量 — 数值与重构前硬编码逐一一致 (视觉零变化).
///
/// Local layout/typography constants for the playlist UI. Values mirror the
/// literals that used to be inlined in the panel/tile files, so extracting
/// them is visually a no-op. Shared design tokens stay in `Tokens`.
abstract final class PlaylistTokens {
  // ---------------------------------------------------------------- tile
  /// 缩略图宽度 — 决定条目高度 (16:9 → 72px).
  static const double thumbWidth = 128.0;

  /// 缩略图高度 (16:9).
  static const double thumbHeight = 72.0;

  /// 解码宽度上限 — 与 ThumbnailSpec 冻结值 320 一致, 防高 DPI 无限放大.
  static const int maxDecodeWidth = 320;

  /// 条目边框恒定宽度 — 宽度 0↔1.5 切换会让内容随高亮跳变, 故恒占位.
  static const double tileBorderWidth = 1.5;

  /// 勾选圆标距缩略图右上角的内缩.
  static const double selectBadgeInset = 4;

  /// 勾选圆标尺寸.
  static const double selectBadgeSize = 18;

  /// 断点进度条高度.
  static const double resumeBarHeight = 3;

  /// 进度条与断点时间文字的间距.
  static const double resumeBarGap = 2;

  /// 断点时间文字字号.
  static const double breakpointFontSize = 10;

  /// 缩略图占位 (电影) 图标尺寸.
  static const double placeholderIconSize = 22;

  /// 重试按钮图标尺寸.
  static const double retryIconSize = 16;

  /// 塑料膜按钮 flex: 播放 3/5 上.
  static const int filmPlayFlex = 3;

  /// 塑料膜按钮 flex: 续播 2/5 下.
  static const int filmResumeFlex = 2;

  /// 塑料膜按钮水平内边距.
  static const double filmHPadding = 6;

  /// 塑料膜按钮图标与文字间距.
  static const double filmLabelGap = 4;

  /// 塑料膜按钮图标尺寸.
  static const double filmIconSize = 22;

  /// 塑料膜按钮文字字号.
  static const double filmLabelFontSize = 11;

  /// 塑料膜按下态过渡时长 (ms) — 即时反馈.
  static const int filmPressMs = 100;

  /// 塑料膜 hover 后图标显现延迟 (ms).
  static const int filmIconDelayMs = 400;

  /// 塑料膜图标显现后文字展开延迟 (ms).
  static const int filmTextDelayMs = 1000;

  /// 塑料膜按下态背景透明度.
  static const double filmPressedAlpha = 0.12;

  /// 塑料膜 hover 态背景透明度.
  static const double filmHoverAlpha = 0.06;

  // --------------------------------------------------------------- panel
  /// 滚动条交叉轴边距.
  static const double scrollbarCrossMargin = 3;

  /// 列表右侧留白 — 滚动条不贴边.
  static const double listRightPadding = 8;
}
