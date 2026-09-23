/// Duration ↔ ms 转换纯函数。
///
/// 路径B 控制栏直连 media_kit [Player] 用于进度/倍速低延迟订阅。
/// 音量换算函数已随 v0.0.8.1 移除 — volume01 改为复用 [MediaEngine.volume]
/// 单一数据源（引擎内部完成 mpv 立方增益 ↔ 用户感知刻度的换算），
/// 避免双源换算漂移。
library;

/// Duration → ms(对齐 ProgressBar seek-hold 的 int 差值比较)
int ms(Duration d) => d.inMilliseconds;

/// ms → Duration
Duration fromMs(int milliseconds) => Duration(milliseconds: milliseconds);
