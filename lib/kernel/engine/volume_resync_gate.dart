/// WASAPI 首播音量 re-sync 门 (v0.0.8.1) — 纯逻辑，可单测。
///
/// Volume re-sync gate — pure arm/consume-once logic.
///
/// 背景（NipaPlay-Reload 同款先例）：Windows WASAPI 音频输出可能延迟到
/// 首次实际播放才完全就绪 — open 时设置的 volume/mute 属性可能不生效，
/// 表现为"切曲/启动后音量沿用 mpv 默认值，首帧后突变为设定值"的跳变
/// 观感。解法：open 成功点 [arm]，首个 playing 事件 [consumeOnPlaying]
/// 消费 — 由调用方（MediaKitEngine）幂等重写一次 volume+mute 属性。
/// 平台门（仅 Windows）由调用方持有，本类保持平台无关纯逻辑。
class VolumeResyncGate {
  bool _armed = false;

  /// open/openPlaylist 成功点调用 — 挂起一次待消费的 re-sync。
  /// 重复 arm 幂等（新文件装载覆盖旧挂起，语义即"以最新装载为准"）。
  void arm() => _armed = true;

  /// 首个 playing 事件消费：armed → 返回 true 并复位（consume-once）；
  /// 未 arm → false。调用方仅在返回 true 时执行属性重写。
  bool consumeOnPlaying() {
    if (!_armed) return false;
    _armed = false;
    return true;
  }

  /// 是否有待消费的 re-sync（诊断与测试用）。
  bool get isArmed => _armed;
}
