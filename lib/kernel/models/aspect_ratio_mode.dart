/// 宽高比模式（解耦自 fvp/mdk 常量）
///
/// 每个枚举值映射到 mdk Player.setAspectRatio() 所需的浮点值。
/// keepOriginal / stretch / cropFill 使用 mdk 特殊常量，
/// ratio4_3 / ratio16_9 / ratio21_9 使用标准数学比率。
enum AspectRatioMode {
  // mdk 特殊常量 — 表示"保持原始宽高比"，非零极小值触发 mdk 的 preserve-aspect-ratio 逻辑（0.0 表示拉伸，负值表示裁剪填充）
  keepOriginal('原始', 1.1920928955078125e-7),
  stretch('拉伸', 0.0),
  // mdk 特殊常量的负值 — 表示"裁剪填充"，负号触发 mdk 的 crop-to-fill 模式
  cropFill('裁剪填充', -1.1920928955078125e-7),
  ratio4_3('4:3', 4.0 / 3.0),
  ratio16_9('16:9', 16.0 / 9.0),
  ratio21_9('21:9', 21.0 / 9.0);

  /// Display label for UI.
  final String label;

  /// mdk Player.setAspectRatio() float value.
  final double mdkValue;
  const AspectRatioMode(this.label, this.mdkValue);
}
