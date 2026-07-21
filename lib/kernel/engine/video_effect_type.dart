/// 视频效果类型（解耦自 fvp/mdk，MediaEngine 接口使用此枚举）。
///
/// Video effect parameters decoupled from the underlying fvp/MDK engine.
///
/// - `brightness`: Luminance adjustment.
/// - `contrast`: Difference between light and dark areas.
/// - `hue`: Color rotation on the chromatic wheel.
/// - `saturation`: Color intensity / vividness.
enum VideoEffectType { brightness, contrast, hue, saturation }
