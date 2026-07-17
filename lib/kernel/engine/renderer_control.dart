/// 渲染器配置接口
///
/// D3D11 同步、硬件解码等渲染器级别配置。
/// 用于 UI 层在设置面板中控制渲染行为。
abstract class RendererControl {
  /// 启用/禁用 D3D11 CPU 同步
  ///
  /// requires: 无
  /// ensures: 底层渲染管线 D3D11 同步开关更新为 enabled（取效于下一帧）
  /// modifies: 无 ValueNotifier（仅委托 D3D11Configurator，不反映到状态视图）
  void setD3d11SyncEnabled(bool enabled);

  /// 启用/禁用硬件解码
  ///
  /// requires: 无（当前媒体是否重新解码取决于底层引擎，通常需重新 open() 生效）
  /// ensures: 底层解码器配置更新为 enabled；亦被 open() 的 codec 错误自动降级路径
  ///   内部调用（见 fvp_engine.dart open() 实现）
  /// modifies: 无 ValueNotifier（仅委托 D3D11Configurator）
  void setHardwareDecoding(bool enabled);
}
