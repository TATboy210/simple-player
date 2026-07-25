# Engine API

## MediaEngine (abstract class)

**File:** `lib/kernel/engine/media_engine.dart`

播放引擎组合接口 — 服务层统一依赖类型。聚合 `EngineStateView` 只读状态视图与 6 个控制类 ISP 接口。

### 继承关系

```
MediaEngine
├── EngineStateView      (只读状态)
├── PlaybackControl      (播放控制)
├── TrackControl         (音轨管理)
├── SubtitleConfig       (字幕配置)
├── VideoEffectControl   (视频效果)
├── RendererControl      (渲染器配置)
└── VolumeControl        (音量控制)
```

### 架构位置

- **UI 层** → `EngineStateView`（只读状态）
- **服务层** → `MediaEngine`（状态 + 控制）
- **FvpEngine** implements `MediaEngine`（具体实现）

---

## EngineStateView (abstract class)

**File:** `lib/kernel/engine/engine_state_view.dart`

播放器只读状态视图 — UI 层通过 `ValueListenableBuilder` 监听变化。

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `textureId` | `ValueNotifier<int?>` | 纹理 ID，null 表示尚未就绪 |
| `state` | `ValueNotifier<MediaState>` | 主播放状态（正交 6 值） |
| `position` | `ValueNotifier<int>` | 当前播放位置（毫秒） |
| `duration` | `ValueNotifier<int>` | 媒体总时长（毫秒） |
| `volume` | `ValueNotifier<double>` | 音量（0.0 ~ 1.0） |
| `isMuted` | `ValueNotifier<bool>` | 是否静音 |
| `isBuffering` | `ValueNotifier<bool>` | 是否正在缓冲 |
| `isSeeking` | `ValueNotifier<bool>` | 是否正在 seek |
| `subtitleText` | `ValueNotifier<String>` | 当前字幕文本 |
| `buffered` | `ValueNotifier<int>` | 已缓冲位置（毫秒） |
| `aspectRatio` | `ValueNotifier<double>` | 视频宽高比 |
| `lastError` | `ValueNotifier<PlayerError?>` | 最近一次错误 |
| `playbackSpeed` | `ValueNotifier<double>` | 播放速度倍率 |
| `mediaInfo` | `MediaInfo` | 媒体元信息 |
| `stateMachine` | `EngineStateMachine` | 状态机访问器 |

### Methods

```dart
void dispose()  // 释放所有 ValueNotifier 资源
```

---

## MediaState (enum)

**File:** `lib/kernel/engine/media_state.dart`

播放器主状态枚举 — 正交 6 值。

```
idle → opening → playing ⇄ paused → completed → error
```

| Value | Description |
|-------|-------------|
| `idle` | 初始状态，未加载任何媒体 |
| `opening` | 正在加载/打开媒体 |
| `playing` | 正在播放 |
| `paused` | 已暂停 |
| `completed` | 播放完成（自然播放到末尾） |
| `error` | 发生错误 |

> seeking/buffering 已移至独立的 `ValueNotifier<bool>`，避免组合爆炸。

---

## PlaybackControl (abstract class)

**File:** `lib/kernel/engine/playback_control.dart`

核心播放控制接口。

### Methods

| Method | Signature | Description |
|--------|-----------|-------------|
| `open` | `Future<void> open(String path)` | 打开媒体文件。成功时 state → idle |
| `play` | `void play()` | 开始播放。state → playing |
| `pause` | `void pause()` | 暂停播放。state → paused |
| `stop` | `void stop()` | 停止播放并重置位置。state → idle, position → 0 |
| `togglePlayPause` | `void togglePlayPause()` | 切换播放/暂停 |
| `seekTo` | `Future<void> seekTo(int ms)` | 跳转到指定位置（毫秒） |
| `setVolume` | `void setVolume(double volume)` | 设置音量（0.0 ~ 1.0） |
| `setMute` | `void setMute(bool mute)` | 设置静音 |
| `setPlaybackRate` | `void setPlaybackRate(double rate)` | 设置播放速度（0.25 ~ 4.0） |
| `setRange` | `void setRange({required int from, int to = -1})` | 设置 AB 循环范围 |
| `skipForward` | `void skipForward([int ms = 10000])` | 快进（默认 10 秒） |
| `skipBack` | `void skipBack([int ms = 10000])` | 快退（默认 10 秒） |

---

## TrackControl (abstract class)

**File:** `lib/kernel/engine/track_control.dart`

音轨控制接口。

| Method | Signature | Description |
|--------|-----------|-------------|
| `getAudioTracks` | `List<AudioTrackInfo> getAudioTracks()` | 获取所有可用音轨 |
| `switchAudioTrack` | `void switchAudioTrack(int trackId)` | 切换到指定音轨 |
| `activeAudioTracks` | `List<int> get activeAudioTracks` | 当前活跃音轨 ID 列表 |

---

## SubtitleConfig (abstract class)

**File:** `lib/kernel/engine/subtitle_config.dart`

字幕配置接口。

| Method | Signature | Description |
|--------|-----------|-------------|
| `getSubtitleTracks` | `List<SubtitleTrackInfo> getSubtitleTracks()` | 获取所有字幕轨道 |
| `switchSubtitleTrack` | `void switchSubtitleTrack(int trackId)` | 切换字幕轨道 |
| `toggleSubtitle` | `void toggleSubtitle()` | 切换字幕开/关 |
| `setExternalSubtitle` | `void setExternalSubtitle(String path)` | 加载外部字幕文件 |
| `setSubtitleDelay` | `void setSubtitleDelay(int delay)` | 设置字幕延迟（毫秒） |
| `setEqualizer` | `void setEqualizer(String preset)` | 设置音频均衡器 |
| `subtitleDelay` | `int get subtitleDelay` | 当前字幕延迟（毫秒） |
| `activeSubtitleTracks` | `List<int> get activeSubtitleTracks` | 当前活跃字幕轨道 |

---

## VolumeControl (abstract class)

**File:** `lib/kernel/engine/volume_control.dart`

| Method/Property | Signature | Description |
|-----------------|-----------|-------------|
| `setVolume` | `void setVolume(double value)` | 设置音量（0.0 ~ 1.0），穿越 0 边界时自动联动 isMuted |
| `setMute` | `void setMute(bool mute)` | 设置静音 |
| `volume` | `ValueNotifier<double> get volume` | 当前音量值 |
| `isMuted` | `ValueNotifier<bool> get isMuted` | 是否静音 |

---

## VideoEffectControl (abstract class)

**File:** `lib/kernel/engine/video_effect_control.dart`

| Method | Signature | Description |
|--------|-----------|-------------|
| `setVideoEffect` | `void setVideoEffect(VideoEffectType effectType, double value)` | 设置视频效果值 |
| `rotate` | `void rotate(int degrees)` | 旋转视频（0/90/180/270） |
| `setAspectRatio` | `void setAspectRatio(double ratio)` | 设置视频宽高比 |
| `setDeinterlace` | `void setDeinterlace(bool enable)` | 启用/禁用反交错 |

---

## RendererControl (abstract class)

**File:** `lib/kernel/engine/renderer_control.dart`

| Method | Signature | Description |
|--------|-----------|-------------|
| `setD3d11SyncEnabled` | `void setD3d11SyncEnabled(bool enabled)` | 启用/禁用 D3D11 CPU 同步 |
| `setHardwareDecoding` | `void setHardwareDecoding(bool enabled)` | 启用/禁用硬件解码 |

---

## FvpEngine (class)

**File:** `lib/kernel/engine/fvp_engine.dart`

fvp/MDK 引擎实现。封装 fvp/MDK 播放器，暴露 Flutter 友好的 ValueNotifier 接口。

### 构造

```dart
factory FvpEngine({
  DiagnosticsBundle bundle = const DiagnosticsBundle.noop(),
  MdkPlayerLike Function()? playerFactory,
})
```

- `bundle` — 诊断能力载体（日志/指标/事件/内存监控）
- `playerFactory` — mdk.Player 工厂，测试时注入 FakeMdkPlayer 消除 mdk.dll 依赖

### 组成（6 个 helper）

| Helper | Responsibility |
|--------|---------------|
| `EngineStateMachine` | 独立状态机，管理 state/isSeeking/isBuffering |
| `FvpCallbackHandler` | 回调注册、状态映射、主线程调度 |
| `PositionPoller` | 自适应间隔轮询播放位置 |
| `TrackManager` | 音频/字幕轨道选择与切换 |
| `VolumeController` | 音量/静音控制 |
| `SubtitleConfigurator` | 外挂字幕、字幕延迟、均衡器 |
| `D3D11Configurator` | D3D11 渲染管线配置 |

### Additional Properties

| Property | Type | Description |
|----------|------|-------------|
| `metrics` | `EngineMetrics` | 引擎健康指标 |
| `eventLog` | `EngineEventLog` | 引擎事件日志（最近 100 条） |
| `lifecyclePhase` | `ValueNotifier<LifecyclePhase>` | 引擎生命周期阶段 |

### Additional Methods

| Method | Signature | Description |
|--------|-----------|-------------|
| `recover` | `void recover()` | 从 error 状态恢复到 idle |
| `trackControl` | `TrackControl get trackControl` | 音轨控制接口 |
| `subtitleConfig` | `SubtitleConfig get subtitleConfig` | 字幕配置接口 |
| `videoEffectControl` | `VideoEffectControl get videoEffectControl` | 视频效果接口 |
| `rendererControl` | `RendererControl get rendererControl` | 渲染器配置接口 |
| `volumeControl` | `VolumeControl get volumeControl` | 音量控制接口 |

### Usage

```dart
final engine = FvpEngine();

// Listen to state changes
engine.state.addListener(() {
  debugPrint('State: ${engine.state.value}');
});

// Open and play
await engine.open('C:/Videos/movie.mp4');
engine.play();

// Seek
await engine.seekTo(60000); // 1 minute

// Volume
engine.setVolume(0.8);
engine.setMute(true);

// Cleanup
engine.dispose();
```

---

## EngineConstants

**File:** `lib/kernel/engine/engine_constants.dart`

引擎层共享常量。

| Constant | Value | Description |
|----------|-------|-------------|
| `minPlaybackRate` | `0.25` | 最小播放速率 |
| `maxPlaybackRate` | `4.0` | 最大播放速率 |
| `defaultPlaybackRate` | `1.0` | 默认播放速率 |
| `defaultVolume` | `1.0` | 默认音量 |
| `minVolume` | `0.0` | 最小音量 |
| `maxVolume` | `1.0` | 最大音量 |
| `defaultSkipMs` | `10000` | 默认快进/快退步长（毫秒） |

---

## MediaInfo

**File:** `lib/kernel/engine/models/media_info.dart`

媒体文件信息。

| Property | Type | Description |
|----------|------|-------------|
| `duration` | `int` | 总时长（毫秒） |
| `video` | `VideoCodecInfo?` | 视频编解码信息 |
| `audioTracks` | `List<AudioTrackInfo>` | 音频轨道列表 |
| `subtitleTracks` | `List<SubtitleTrackInfo>` | 字幕轨道列表 |

| Getter | Type | Description |
|--------|------|-------------|
| `hasVideo` | `bool` | 是否有视频流 |
| `hasAudio` | `bool` | 是否有音频流 |
| `hasSubtitles` | `bool` | 是否有字幕流 |

---

## VideoCodecInfo

**File:** `lib/kernel/engine/models/video_codec_info.dart`

| Property | Type | Description |
|----------|------|-------------|
| `width` | `int` | 视频宽度（像素） |
| `height` | `int` | 视频高度（像素） |
| `par` | `double` | 像素宽高比（Pixel Aspect Ratio） |
| `codec` | `String` | 编解码器名称 |
| `aspectRatio` | `double` (getter) | 含 PAR 修正的宽高比 |

---

## AudioTrackInfo

**File:** `lib/kernel/engine/models/audio_track_info.dart`

| Property | Type | Description |
|----------|------|-------------|
| `index` | `int` | 轨道索引 |
| `language` | `String` | 语言代码 |
| `codec` | `String` | 编解码器名称 |
| `channels` | `int` | 声道数 |

---

## SubtitleTrackInfo

**File:** `lib/kernel/engine/models/subtitle_track_info.dart`

| Property | Type | Description |
|----------|------|-------------|
| `index` | `int` | 轨道索引 |
| `language` | `String` | 语言代码 |
| `title` | `String` | 轨道标题 |

---

## MdkPlayerProxy

**File:** `lib/kernel/engine/mdk_player_proxy.dart`

mdk.Player 的 Dart 适配器，实现 `MdkPlayerLike` 接口。

```dart
factory MdkPlayerProxy.create()  // 创建默认的真实 mdk.Player 代理
mdk.Player get rawPlayer          // 暴露底层 mdk.Player
```
