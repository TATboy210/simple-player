/// media_kit 音量(0-100) ↔ 项目音量(0-1) 转换 + Duration ↔ ms 转换纯函数。
///
/// 路径B 控制栏直连 media_kit [Player],其 `stream.volume` 是 0-100 语义,
/// 项目 [MediaEngine.volume] 是 0-1 语义。集中转换避免 magic number 散落。
library;

/// media_kit 0-100 → 项目 0-1
double volumeFromMediaKit(double v) => (v / 100).clamp(0.0, 1.0);

/// 项目 0-1 → media_kit 0-100
double volumeToMediaKit(double v) => (v * 100).clamp(0.0, 100.0);

/// Duration → ms(对齐 ProgressBar seek-hold 的 int 差值比较)
int ms(Duration d) => d.inMilliseconds;

/// ms → Duration
Duration fromMs(int milliseconds) => Duration(milliseconds: milliseconds);
