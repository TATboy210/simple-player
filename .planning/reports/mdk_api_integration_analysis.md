# MDK API 对接深度分析

> **分析范围**：`lib/kernel/engine/` 目录下 28 个文件，聚焦 FvpEngine 如何将 Flutter 控制栏的每个用户操作映射到 MDK (libmdk) 底层 API。
>
> **关联文档**：控制栏分析报告 [第 8.4 节](control_bar_analysis_report.md#84-mdk-api-对接细节)。

## 1. MDK API 表面总览

### 1.1 mdk.Player 使用的方法/属性

项目通过 `package:fvp/mdk.dart` 访问 MDK 的 Dart 绑定。以下是 `mdk.Player` 的完整 API 使用清单：

#### 1.1.1 直接属性赋值（Dart setter）

这些属性直接映射到 MDK C++ Player 的同名方法，通过 FFI 调用 `mdkPlayerSetProperty` / `mdkPlayerGetProperty`：

```dart
_player.state = mdk.PlaybackState.playing;   // 播放状态（3 种：stopped/playing/paused）
_player.playbackRate = 1.5;                   // 播放速率（double）
_player.volume = 0.8;                         // 音量（0.0-1.0，线性映射）
_player.mute = true;                          // 静音（bool）
_player.activeAudioTracks = [0];              // 活跃音轨（List<int>）
_player.activeSubtitleTracks = [];            // 活跃字幕轨（空列表 = 禁用字幕）
_player.media = 'path/to/file.mp4';           // 媒体源路径或 URL
```

**关键细节**：
- `volume` 是线性映射（0.0-1.0），MDK 内部处理对数曲线（人耳感知）
- `activeSubtitleTracks = []` 是 MDK 的字幕禁用约定（不是特殊值 -1）
- `state` 只有 3 种值，项目在之上构建了 9 种 `MediaState`

#### 1.1.2 专用方法调用

```dart
_player.prepare();                             // 异步准备媒体（返回 int，负值 = 错误码）
_player.seek(position: 5000);                  // 异步跳转（毫秒）
_player.setVideoEffect(mdk.VideoEffect.brightness, [0.5]);  // 视频效果（值为单元素数组）
_player.rotate(90);                            // 旋转（仅 0/90/180/270）
_player.setAspectRatio(1.778);                 // 宽高比
_player.setBufferRange(min: 500, max: 2000, drop: true);  // 缓冲范围
_player.updateTexture();                       // 创建/更新 D3D11 纹理
_player.dispose();                             // 释放 FFI 资源
```

**关键细节**：
- `setVideoEffect` 的值参数是 `[value]` 单元素数组（mpv 历史 API 设计）
- `rotate` 只接受 4 个硬件旋转角度，不支持任意角度
- `prepare()` 返回负值表示错误码，`-99` 是项目自定义的超时代号
- `updateTexture()` 返回负值表示纹理创建失败

#### 1.1.3 通用属性系统（setProperty 键值对）

继承自 mpv 的 `mp_set_property_string`，所有未暴露专用 setter 的属性通过此方式设置：

```dart
// D3D11 渲染参数
_player.setProperty('d3d11.sync.cpu', '1');                    // CPU 同步模式
_player.setProperty('video.decoders', 'D3D11:shader_resource=1,NVDEC,FFmpeg');  // 解码器链
_player.setProperty('avcodec.threads', '2');                   // FFmpeg 线程数
_player.setProperty('videoout.buffer_frames', '3');            // 帧缓冲数
_player.setProperty('reader.starts_with_key', '1');            // 关键帧起始解码

// 字幕配置
_player.setProperty('subtitle.external', '/path/to/sub.srt');  // 外挂字幕
_player.setProperty('subtitle.delay', '500');                  // 字幕延迟（ms）

// 音频滤镜
_player.setProperty('af', 'lavfi=[equalizer=f=1000:width_type=h:width=200:g=-10]');

// 视频滤镜
_player.setProperty('video.avfilter', 'yadif=mode=send_frame:deint=all');  // 反交错

// 网络参数
_player.setProperty('timeout', '10000');                       // 网络超时（ms）
_player.setProperty('avformat.probesize', '1000000');          // 流探测大小（bytes）
_player.setProperty('avformat.analyzeduration', '5000000');    // 流分析时长（μs）
_player.setProperty('avformat.fflags', '+nobuffer');           // 禁用 FFmpeg 缓冲
_player.setProperty('avformat.fpsprobesize', '0');             // 跳过 FPS 探测
_player.setProperty('avformat.avioflags', 'direct');           // 绕过 IO 缓冲

// 缓冲策略
_player.setProperty('demux.buffer.ranges', '0');               // 禁用 demux 缓存
_player.setProperty('buffer', '1000000');                      // 缓冲大小（bytes）
```

#### 1.1.4 事件流（Dart Stream）

```dart
_player.onStateChanged    // Stream<StateChangeEvent> — 播放状态变化
_player.onMediaStatus     // Stream<MediaStatusEvent> — 缓冲/结束等状态
_player.textureId         // ValueNotifier<int?> — 纹理 ID（Dart ValueNotifier，非 Stream）
```

#### 1.1.5 同步 getter（FFI 同步调用）

```dart
_player.position          // 当前位置（int，毫秒）— FFI 同步调用
_player.buffered()        // 缓冲位置（int，毫秒）— 仅 URL 源
_player.mediaInfo         // 媒体信息（MediaInfo 对象）
_player.state             // 当前播放状态
```

### 1.2 API 调用统计

| 类别 | 数量 | 说明 |
|------|------|------|
| 直接 setter | 7 | state/rate/volume/mute/audioTracks/subtitleTracks/media |
| 专用方法 | 7 | prepare/seek/setVideoEffect/rotate/setAspectRatio/setBufferRange/updateTexture |
| setProperty 键值对 | ~20 | 覆盖 D3D11/字幕/滤镜/网络/缓冲 |
| 事件流 | 2 | onStateChanged + onMediaStatus |
| 同步 getter | 4 | position/buffered/mediaInfo/state |

**总计**：约 40 个 MDK API 调用点，通过 8 个 helper 类分散管理。

---

## 2. Helper 类委托架构

FvpEngine 不直接调用所有 MDK API，而是通过 8 个职责单一的 helper 类分散管理：

```
FvpEngine (协调者)
├── MediaOpener          — 媒体打开流程（prepare + metadata + texture）
├── PositionPoller       — 位置轮询（自适应间隔）
├── VolumeController     — 音量/静音控制
├── TrackManager         — 音轨/字幕轨管理
├── FvpCallbackHandler   — MDK 回调 → ValueNotifier 映射
├── D3D11Configurator    — D3D11 渲染参数
├── SubtitleConfigurator — 字幕/均衡器配置
├── VideoEffectController — 视频效果（亮度/对比度/旋转/宽高比/反交错）
└── NetworkConfigurator  — 网络协议配置（静态工具类）
```

### 2.1 MediaOpener — 媒体打开流程

**职责**：编排完整的打开流程，从路径验证到纹理创建。

**MDK API 调用链**：

```
open(path)
  → _player.media = path              // 设置媒体源
  → NetworkConfigurator.configure()   // URL 专用网络参数
  → _player.setBufferRange()          // 本地文件紧凑缓冲
  → _player.setProperty()             // demux 缓冲策略
  → _player.prepare()                 // 异步准备（10 秒超时）
  → _player.mediaInfo                 // 读取元数据
  → _player.updateTexture()           // 创建 D3D11 纹理（5 秒超时）
```

**关键设计**：
- 返回 `OpenResult` sealed class（`OpenSuccess` | `OpenError`），Dart 3 穷举匹配
- 本地文件缓冲参数紧凑化：`min=500ms, max=2000ms`（默认 1000-4000ms），减少内存占用
- `prepare()` 超时返回 `-99`，区分超时和解码错误
- PAR 修正：`aspectRatio = width * par / height`，处理像素宽高比 ≠ 显示宽高比的情况

### 2.2 PositionPoller — 自适应位置轮询

**职责**：主动轮询播放位置和缓冲进度，而非依赖 MDK 回调推送。

**为什么不用回调**：MDK 的 `onStateChanged` 只报告播放状态变化，不推送位置。位置信息需要主动查询 `_player.position`（FFI 同步调用）。

**4 种轮询模式**：

| 模式 | 间隔 | 触发条件 | MDK API |
|------|------|----------|---------|
| 拖拽模式 | 16ms | 拖拽进度条时 | `_player.position` |
| 活跃模式 | 100ms | seek 完成后 | `_player.position` + `_player.buffered()` |
| 稳态模式 | 250ms | 正常播放 | `_player.position` + `_player.buffered()` |
| 静默模式 | 500ms | 无交互 3 秒后 | `_player.position` |

**自适应策略**：
- 倍速播放时按比例缩短间隔：`250ms / rate`，最低 50ms
- seek 期间暂停轮询，防止旧位置覆盖 seek 目标
- 值变化时才更新 ValueNotifier，避免不必要的 widget 重建
- 本地文件跳过 `_player.buffered()` 调用（瞬间完全缓存）

### 2.3 VolumeController — 音量控制

**职责**：管理音量和静音状态，处理自动静音逻辑。

**MDK API 调用**：
```dart
_player.volume = clamped;   // 设置音量（0.0-1.0）
_player.mute = mute;        // 设置静音
```

**自动静音逻辑**：
- 音量降到 0.0 → 自动 `_player.mute = true`（防止极低音量噪声）
- 从 0.0 提升 → 自动 `_player.mute = false`（UX 便捷操作）

**测试性**：通过 `PlayerProxy` 抽象而非直接依赖 `mdk.Player`，支持纯 Dart fake 单元测试。

### 2.4 TrackManager — 音轨/字幕管理

**职责**：查询和切换音轨/字幕轨。

**MDK API 调用**：
```dart
_player.activeAudioTracks = [index];      // 切换音轨
_player.activeSubtitleTracks = [index];   // 切换字幕轨
_player.activeSubtitleTracks = [];        // 禁用字幕
_player.activeAudioTracks                 // 读取当前音轨
_player.activeSubtitleTracks              // 读取当前字幕轨
```

**防御性编程**：切换前检查索引范围，因为 MDK 在无效索引时会崩溃：
```dart
if (tracks.isEmpty || trackIndex < 0 || trackIndex >= tracks.length) return;
```

**字幕切换**：采用简单的开/关循环（`[]` ↔ `[0]`），而非遍历所有字幕轨。大多数内容只有一个字幕轨，遍历增加复杂度无实际收益。

### 2.5 FvpCallbackHandler — 回调映射

**职责**：将 MDK 的异步事件流映射为 Flutter ValueNotifier 更新。

**MDK API 调用**：
```dart
_player.onStateChanged.listen(...)    // 状态变化回调
_player.onMediaStatus.listen(...)     // 媒体状态回调
_player.state                         // 缓冲结束时读取当前状态
```

**状态映射**：
- `mdk.PlaybackState.stopped` → `MediaState.stopped`
- `mdk.PlaybackState.playing` → `MediaState.playing`
- `mdk.PlaybackState.paused` → `MediaState.paused`
- `mdk.MediaStatus.buffering` → `MediaState.buffering` + `isBuffering = true`
- 缓冲结束 → 根据 `_player.state` 恢复到 playing 或 paused
- `mdk.MediaStatus.end` → `MediaState.completed`

**主线程调度**：所有回调通过 `SchedulerBinding.instance.addPostFrameCallback` 调度到 Flutter UI 线程，确保 ValueNotifier 更新发生在帧间，避免渲染管线中断。

### 2.6 D3D11Configurator — D3D11 渲染参数

**职责**：配置 D3D11 渲染后端的性能参数。

**MDK API 调用**（全部通过 `setProperty`）：
```dart
_player.setProperty('d3d11.sync.cpu', '1');                    // CPU 同步（防撕裂）
_player.setProperty('video.decoders', 'D3D11:shader_resource=1,NVDEC,FFmpeg');  // 硬解链
_player.setProperty('avcodec.threads', '2');                   // FFmpeg 线程数
_player.setProperty('videoout.buffer_frames', '3');            // 帧缓冲
_player.setProperty('reader.starts_with_key', '1');            // 关键帧起始
```

**解码器优先级链**：D3D11（GPU 硬解 + 色彩空间转换）→ NVDEC（NVIDIA 硬解）→ FFmpeg（软解兜底）。

### 2.7 SubtitleConfigurator — 字幕/均衡器

**职责**：外挂字幕、字幕延迟、音频均衡器。

**MDK API 调用**（通过 `PlayerProxy`）：
```dart
_player.setProperty('subtitle.external', path);    // 外挂字幕
_player.setProperty('subtitle.delay', ms);         // 字幕延迟
_player.setProperty('af', 'lavfi=[equalizer=...]');  // 音频均衡器
```

### 2.8 VideoEffectController — 视频效果

**职责**：亮度/对比度/饱和度/色相、旋转、宽高比、反交错。

**MDK API 调用**：
```dart
_player.setVideoEffect(mdkEffect, [clamped]);      // 视频效果（值为单元素数组）
_player.rotate(degree);                             // 旋转（0/90/180/270）
_player.setAspectRatio(ratio);                      // 宽高比
_player.setProperty('video.avfilter', 'yadif=...'); // 反交错
```

### 2.9 NetworkConfigurator — 网络协议配置

**职责**：为不同网络协议设置低延迟参数。

**MDK API 调用**（静态工具类，不持有状态）：

| 协议 | 配置要点 | MDK 属性 |
|------|---------|---------|
| RTSP | 最小探测 + 禁用缓冲 + 绕过 IO | `probesize=500K`, `fflags=+nobuffer`, `fpsprobesize=0`, `avioflags=direct`, `buffer=0-0` |
| RTMP | 同 RTSP 但无 avioflags | `fflags=+nobuffer`, `fpsprobesize=0`, `buffer=0-0` |
| SRT | 同 RTMP | 同上 |
| UDP/TCP | 同 SRT | 同上 |
| HTTP/HTTPS | 启用 demux 缓存 | `demux.buffer.ranges=1` |

**自适应缓冲**：高延迟（>500ms）时增大缓冲到 5MB，低延迟时保持 1MB。

---

## 3. PlayerProxy 抽象层 — 测试性设计

### 3.1 接口定义

```dart
/// mdk.Player API 子集抽象 — 仅包含 helper 类需要的方法
abstract class PlayerProxy {
  set volume(double value);                        // 音量
  set mute(bool value);                            // 静音
  void setProperty(String key, String value);      // 通用属性
  String? getProperty(String key);                 // 读取属性
}
```

### 3.2 委托实现

```dart
class MdkPlayerProxy implements PlayerProxy {
  final mdk.Player _player;

  @override
  set volume(double value) => _player.volume = value;

  @override
  set mute(bool value) => _player.mute = value;

  @override
  void setProperty(String key, String value) => _player.setProperty(key, value);

  @override
  String? getProperty(String key) => _player.getProperty(key);
}
```

### 3.3 受益的 helper 类

| Helper | 依赖 PlayerProxy | 测试收益 |
|--------|-----------------|---------|
| `VolumeController` | ✅ | 纯 Dart fake 测试音量逻辑 |
| `SubtitleConfigurator` | ✅ | 纯 Dart fake 测试字幕配置 |
| `D3D11Configurator` | ✅ | 纯 Dart fake 测试渲染参数 |

**未使用 PlayerProxy 的 helper**（直接依赖 `mdk.Player`）：
- `MediaOpener` — 需要 `prepare()`、`mediaInfo`、`updateTexture()` 等专用方法
- `PositionPoller` — 需要 `position` getter 和 `buffered()` 方法
- `TrackManager` — 需要 `activeAudioTracks`/`activeSubtitleTracks` 属性
- `FvpCallbackHandler` — 需要 `onStateChanged`/`onMediaStatus` 事件流
- `VideoEffectController` — 需要 `setVideoEffect()`、`rotate()` 等专用方法

---

## 4. 完整调用链路图

### 4.1 用户操作 → MDK API 全链路

以控制栏最常见的 5 个操作为例：

#### 4.1.1 点击播放按钮

```
用户点击 PlayPauseButton
  → PlayerActions.onTogglePlayPause()
  → PlaybackController.togglePlayPause()
  → FvpEngine.togglePlayPause()
    → state.value == MediaState.playing ? pause() : play()
      → _player.state = mdk.PlaybackState.playing
      → _safeSetState(MediaState.playing, 'play')
      → FvpCallbackHandler._player.onStateChanged
        → mapMdkState(playing) = MediaState.playing
        → _scheduleOnMain(() => state.value = MediaState.playing)
```

#### 4.1.2 拖拽进度条

```
用户拖拽 ProgressBar
  → ProgressBar.onChanged(position)
  → FvpEngine.seekTo(ms)
    → _positionPoller.seeking = true          // 暂停轮询
    → _safeSetState(MediaState.seeking, 'seekTo')
    → _player.seek(position: clamped)         // MDK 异步 seek
    → await 完成
    → _positionPoller.seeking = false         // 恢复轮询（100ms 快速模式）
    → _safeSetState(wasPlaying ? playing : paused)
```

#### 4.1.3 拖拽音量滑块

```
用户拖拽 VolumeSlider
  → VolumeSlider.onChanged(value)
  → FvpEngine.setVolume(value)
    → _guardedAction('setVolume', () {
        _volumeController.setVolume(value)
          → _player.volume = clamped           // MDK 音量设置
          → volume.value = clamped             // ValueNotifier 更新
          → auto-mute/unmute 逻辑
      })
```

#### 4.1.4 打开文件

```
用户点击打开按钮 / 拖放文件
  → FileOperations.openFile()
  → PlaybackController.open(path)
  → FvpEngine.open(path)
    → _isOpening = true                       // 防重入
    → _safeSetState(MediaState.loading)
    → MediaOpener.open(path)
      → _player.media = path                  // 设置媒体源
      → NetworkConfigurator.configure()       // URL 专用配置
      → _player.prepare()                     // 异步准备（10s 超时）
      → _player.mediaInfo                     // 读取元数据
      → _player.updateTexture()               // 创建纹理（5s 超时）
      → return OpenSuccess / OpenError
    → 成功: _safeSetState(MediaState.idle)
    → 失败: codec 错误 + 本地文件 → 软解降级递归重试
```

#### 4.1.5 切换倍速

```
用户点击 SpeedButton 选择 1.5x
  → SpeedButton.onChanged(1.5)
  → FvpEngine.setPlaybackRate(1.5)
    → _guardedAction('setPlaybackRate', () {
        _player.playbackRate = 1.5             // MDK 倍速设置
        playbackSpeed.value = 1.5              // ValueNotifier 更新
        _positionPoller.setPlaybackRate(1.5)   // 调整轮询间隔
          → interval = 250ms / 1.5 ≈ 167ms
      })
```

### 4.2 数据流方向总结

```
┌─────────────────────────────────────────────────────────────┐
│                      控制栏 UI 层                            │
│  ControlBar → CenterGroup → PlayPauseButton/ProgressBar/... │
│                  ↓ (PlayerActions 回调)                      │
├─────────────────────────────────────────────────────────────┤
│                    FvpEngine 协调层                          │
│  _safeSetState + _guardedAction + _disposed 检查             │
│                  ↓ (委托)                                    │
├─────────────────────────────────────────────────────────────┤
│                    Helper 类层                               │
│  MediaOpener | PositionPoller | VolumeController | ...      │
│                  ↓ (mdk.Player API)                          │
├─────────────────────────────────────────────────────────────┤
│                    MDK Dart 绑定层                           │
│  mdk.Player (package:fvp/mdk.dart, ~934 行)                 │
│                  ↓ (FFI)                                     │
├─────────────────────────────────────────────────────────────┤
│                    MDK C++ 原生层                            │
│  libmdk → FFmpeg (解码) + D3D11 (渲染) + ...                │
└─────────────────────────────────────────────────────────────┘
```

---

## 5. 设计模式与最佳实践

### 5.1 委托模式（Delegation）

FvpEngine 自身不直接调用大部分 MDK API，而是委托给职责单一的 helper 类。每个 helper 只关注一个维度：
- `VolumeController` — 音量
- `TrackManager` — 音轨
- `D3D11Configurator` — 渲染参数

**收益**：FvpEngine 从 ~600 行减少到 ~350 行（不含 helper），每个 helper 可独立测试。

### 5.2 抽象接口（PlayerProxy）

`PlayerProxy` 为 helper 类提供了 `mdk.Player` 的子集抽象，使得 `VolumeController`、`SubtitleConfigurator`、`D3D11Configurator` 可以用纯 Dart fake 测试，无需 FFI 依赖。

### 5.3 状态机守卫（State Machine Guard）

`MediaStateTransition.canTransitionTo()` 定义了合法的状态转换矩阵，`_safeSetState()` 在每次状态变更前检查。debug 模式下非法转换打印警告但仍然执行（保证不崩溃），release 模式下静默忽略。

### 5.4 自适应轮询（Adaptive Polling）

`PositionPoller` 根据用户交互频率动态调整轮询间隔：
- 拖拽时 16ms（60fps 跟手）
- seek 后 100ms（1 秒快速模式）
- 正常播放 250ms
- 无交互 500ms（节省 CPU）
- 倍速时按比例缩短

### 5.5 防御性编程（Defensive Programming）

- `TrackManager`：切换前检查索引范围，防止 MDK 崩溃
- `VolumeController`：音量 clamp 到 0.0-1.0，自动静音/取消静音
- `MediaOpener`：prepare 超时 10s，texture 超时 5s，防止永久挂起
- `FvpCallbackHandler`：`_disposed` 标志阻止释放后的回调处理
- `PositionPoller`：`_disposed` + `_seeking` 双重保护

### 5.6 sealed class 返回值

`MediaOpener.open()` 返回 `OpenResult` sealed class，Dart 3 穷举匹配确保所有分支被处理：

```dart
switch (result) {
  case OpenSuccess(:final mediaInfo): ...
  case OpenError(:final type, :final message): ...
}
```

---

## 6. 已知限制与改进方向

### 6.1 位置轮询的固有延迟

位置信息通过轮询而非推送获取，最坏情况下有 250ms 延迟。对于 60fps 视频，这意味着进度条最多落后 15 帧。

**改进方向**：MDK 未来可能支持位置变化回调，届时可替换轮询机制。

### 6.2 PlayerProxy 接口不完整

当前 `PlayerProxy` 只包含 4 个方法（volume/mute/setProperty/getProperty），导致 `MediaOpener`、`PositionPoller`、`TrackManager`、`FvpCallbackHandler`、`VideoEffectController` 5 个 helper 直接依赖 `mdk.Player`，无法用 fake 测试。

**改进方向**：扩展 `PlayerProxy` 为更完整的接口，或为每个 helper 定义专用的窄接口。

### 6.3 setProperty 字符串类型

MDK 的通用属性系统全部使用字符串值，没有类型安全。错误的值类型（如传 `'abc'` 给数字属性）会导致 MDK 内部静默忽略或行为未定义。

**改进方向**：封装类型安全的 wrapper 方法，如 `setSyncEnabled(bool)` 替代 `setProperty('d3d11.sync.cpu', '1')`。

### 6.4 网络配置硬编码

`NetworkConfigurator` 的参数（超时、探测大小、缓冲大小）全部硬编码为常量，无法根据用户网络环境动态调整。

**改进方向**：引入配置文件或设置面板，允许高级用户自定义网络参数。

---

## 7. MDK API 速查表

| 操作 | MDK API | 参数 | 返回 |
|------|---------|------|------|
| 播放 | `_player.state = mdk.PlaybackState.playing` | 枚举 | — |
| 暂停 | `_player.state = mdk.PlaybackState.paused` | 枚举 | — |
| 停止 | `_player.state = mdk.PlaybackState.stopped` | 枚举 | — |
| 跳转 | `_player.seek(position: ms)` | int (毫秒) | Future<int> |
| 音量 | `_player.volume = value` | double (0-1) | — |
| 静音 | `_player.mute = value` | bool | — |
| 倍速 | `_player.playbackRate = rate` | double | — |
| 打开 | `_player.media = path` + `_player.prepare()` | String + async | int |
| 纹理 | `_player.updateTexture()` | — | Future<int> |
| 音轨 | `_player.activeAudioTracks = [index]` | List<int> | — |
| 字幕 | `_player.activeSubtitleTracks = [index]` | List<int> | — |
| 旋转 | `_player.rotate(degree)` | int (0/90/180/270) | — |
| 宽高比 | `_player.setAspectRatio(ratio)` | double | — |
| 视频效果 | `_player.setVideoEffect(effect, [value])` | enum + [double] | — |
| 属性 | `_player.setProperty(key, value)` | String, String | — |
| 缓冲 | `_player.setBufferRange(min, max, drop)` | int, int, bool | — |
| 释放 | `_player.dispose()` | — | — |
