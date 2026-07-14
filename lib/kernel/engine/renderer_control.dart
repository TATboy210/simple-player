/// 渲染器配置接口
///
/// D3D11 同步、硬件解码等渲染器级别配置。
/// 用于 UI 层在设置面板中控制渲染行为。
abstract class RendererControl {
  /// 启用/禁用 D3D11 CPU 同步
  void setD3d11SyncEnabled(bool enabled);

  /// 启用/禁用硬件解码
  void setHardwareDecoding(bool enabled);
}
