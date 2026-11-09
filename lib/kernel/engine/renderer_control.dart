/// 渲染器配置接口
///
/// 硬件解码等渲染器级别配置。
/// 用于 UI 层在设置面板中控制渲染行为。
abstract class RendererControl {
  /// 启用/禁用硬件解码
  ///
  /// requires: 无（当前媒体是否重新解码取决于底层引擎，通常需重新 open() 生效）
  /// ensures: 底层解码器配置更新为 enabled（写 mpv `hwdec` 全局属性）
  /// modifies: 无 ValueNotifier（仅委托 mpv 属性，不反映到状态视图）
  void setHardwareDecoding(bool enabled);
}
