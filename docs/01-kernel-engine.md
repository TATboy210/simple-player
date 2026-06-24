# Simple Player Flutter -- 内核引擎层 (Engine/Bridge/Models)

> 引擎抽象、fvp实现、窗口桥接、数据模型的完整技术分析。

---

## 1. Engine Architecture (引擎架构)

### 1.1 MediaEngine -- 抽象接口

**文件:** `lib/kernel/engine/media_engine.dart`

**职责:** 定义所有播放后端必须实现的抽象契约。UI层仅依赖此接口，不直接依赖具体引擎。这是内核层的核心架构缝合点。

**设计原则:**
- 10 个 `ValueNotifier` 字段暴露响应式状态，对齐 Flutter 重建模型
- 命令/查询分离 (CQS): 命令方法返回 `void`，查询方法返回值
- 每个方法执行 `_disposed` 守卫检查 (Guard Clause 模式)
- 输入参数在入口处钳位 (防御性编程)

#### ValueNotifier 状态暴露

| Notifier | 类型 | 说明 |
|----------|------|------|
| `textureId` | `ValueNotifier<int?>` | 纹理ID，用于 `Texture` widget |
| `state` | `ValueNotifier<MediaState>` | 当前播放状态 |
| `position` | `ValueNotifier<int>` | 当前位置 (毫秒) |
| `duration` | `ValueNotifier<int>` | 总时长 (毫秒) |
| `volume` | `ValueNotifier<double>` | 音量 0.0 - 1.0 |
| `isMuted` | `ValueNotifier<bool>` | 静音标志 |
| `isBuffering` | `ValueNotifier<bool>` | 缓冲指示器 |
| `buffered` | `ValueNotifier<int>` | 已缓冲位置 (毫秒) |
| `aspectRatio` | `ValueNotifier<double>` | 当前画面比例 |
| `errorMessage` | `ValueNotifier<String?>` | 人类可读错误信息 |
| `playbackSpeed` | `ValueNotifier<double>` | 播放速率 0.25 - 4.0 |

#### 命令 API

| 方法 | 签名 | 说明 |
|------|------|------|
| `open` | `Future<void> open(String path)` | 打开媒体文件/URL |
| `play` | `void play()` | 开始播放 |
| `pause` | `void pause()` | 暂停 |
| `stop` | `void stop()` | 停止并重置位置 |
| `seekTo` | `Future<void> seekTo(int ms)` | 跳转到位置 (自动钳位) |
| `setVolume` | `void setVolume(double value)` | 设置音量 |
| `setMute` | `void setMute(bool mute)` | 切换静音 |
| `togglePlayPause` | `void togglePlayPause()` | 播放/暂停切换 |
| `skipForward` | `void skipForward([int seconds = 10])` | 快进 (默认10秒) |
| `skipBack` | `void skipBack([int seconds = 10])` | 快退 (默认10秒) |
| `setPlaybackRate` | `void setPlaybackRate(double rate)` | 设置播放速率 |
| `setRange` | `void setRange({required int from, int to = -1})` | AB循环 (-1清除) |
| `dispose` | `void dispose()` | 释放资源 |

#### 音轨/字幕管理 API

| 方法 | 说明 |
|------|------|
| `getAudioTracks()` | 返回 `List<AudioTrackInfo>` |
| `switchAudioTrack(int index)` | 激活音频轨 |
| `getSubtitleTracks()` | 返回 `List<SubtitleTrackInfo>` |
| `switchSubtitleTrack(int index)` | 激活字幕轨 (-1禁用) |
| `toggleSubtitle()` | 字幕开/关切换 |
| `setExternalSubtitle(String path)` | 加载外挂字幕 |
| `setSubtitleDelay(int ms)` | 字幕时间偏移 |

#### 视频处理 API

| 方法 | 说明 |
|------|------|
| `setVideoEffect(VideoEffectType, double)` | 亮度/对比度/色调/饱和度 |
| `setEqualizer(String afFilter)` | FFmpeg滤镜均衡器 |
| `rotate(int degree)` | 旋转 (0/90/180/270) |
| `setAspectRatio(double ratio)` | 设置画面比例 |
| `setDeinterlace(bool enable)` | 去隔行扫描 |

---

### 1.2 FvpEngine -- 具体实现

**文件:** `lib/kernel/engine/fvp_engine.dart`

**职责:** 唯一的 `MediaEngine` 实现。封装 `fvp` 包 (MDK/FFmpeg)，暴露 Flutter 友好的 `ValueNotifier` 状态。Windows 使用 D3D11 硬件加速渲染，ARM/x86 回退到 FFmpeg 软解。

**类:** `FvpEngine implements MediaEngine`

#### 常量

| 常量 | 值 | 用途 |
|------|-----|------|
| `_prepareTimeoutSeconds` | 10 | `_player.prepare()` 超时 |
| `_textureTimeoutSeconds` | 5 | `_player.updateTexture()` 超时 |
| `_defaultSkipSeconds` | 10 | 默认跳转秒数 |
| `_minPlaybackRate` | 0.25 | 最低播放速率 |
| `_maxPlaybackRate` | 4.0 | 最高播放速率 |

#### 内部组合 (Composition)

| Helper | 职责 |
|--------|------|
| `FvpCallbackHandler` | mdk回调注册和状态映射 |
| `PositionPoller` | 250ms定时器位置轮询 |
| `TrackManager` | 音频/字幕轨选择 |

#### `open()` 方法详细生命周期

1. 守卫: 检查 `_disposed` 和 `_isOpening` (重入保护)
2. 修剪路径；验证非空
3. 本地文件: 异步检查 `File.exists()`
4. 设置 `state = MediaState.loading`，存储 `_currentPath`
5. 调用 `_player.media = trimmed` 然后 `_player.prepare()` (10秒超时)
6. prepare失败: 设置 `MediaState.error`，区分超时(-99)和其他错误
7. 从 mdk info 提取 `MediaInfo` (时长、视频编码、音频轨、字幕轨)
8. 调用 `_player.updateTexture()` (5秒超时)
9. texture失败: 设置错误，区分超时和创建失败
10. 成功: 重置位置，清除错误
11. `finally`: 重置 `_isOpening`

#### `seekTo()` 实现

- 钳位输入到 `[0, duration.value]`
- 记录 `wasPlaying` 状态
- 设置 `_positionPoller.seeking = true` (暂停轮询防止旧位置覆盖)
- 设置 `state = MediaState.seeking`
- 异步调用 `_player.seek(position: clamped)`
- 错误时: 设置 `errorMessage`，回退到 `_player.position`
- `finally`: 重置 `_positionPoller.seeking = false`
- 根据 `wasPlaying` 恢复状态

#### `_guardedAction()` 辅助方法

私有方法，包装任何操作在 `_disposed` 检查 + try/catch 中，通过 `debugPrint` 记录错误。消除了约15个方法的重复样板代码。

---

### 1.3 FvpCallbackHandler -- 回调桥接

**文件:** `lib/kernel/engine/fvp_callback_handler.dart`

**职责:** 将原生 mdk 回调事件翻译为 Flutter `ValueNotifier` 更新，通过 `SchedulerBinding.addPostFrameCallback` 分发到主线程。

**`mapMdkState()` -- 纯静态函数:**

```dart
static MediaState mapMdkState(mdk.PlaybackState mdkState) {
  return switch (mdkState) {
    mdk.PlaybackState.stopped => MediaState.stopped,
    mdk.PlaybackState.playing => MediaState.playing,
    mdk.PlaybackState.paused => MediaState.paused,
    _ => MediaState.idle,
  };
}
```

刻意使用 `static` 以提高可测试性 -- 无副作用，可独立单元测试。

**线程安全:** 所有回调使用 `_scheduleOnMain()` 包装，确保 ValueNotifier 变异发生在UI线程。双重 `_disposed` 检查守卫流处理器和调度回调。

---

### 1.4 PositionPoller -- 定时位置追踪

**文件:** `lib/kernel/engine/position_poller.dart`

**职责:** 每 250ms 轮询原生播放器位置并更新 `ValueNotifier<int> position`。在 seek 操作期间暂停以防止旧值覆盖 seek 目标。

**关键属性:**
- `set seeking(bool value)` -- 为 true 时 `_poll()` 是空操作

**`_poll()` 逻辑:**
1. 守卫: `_disposed` 或 `_seeking` -> 返回
2. 读取 `_player.position`；仅在变化时更新 `position.value`
3. 如果当前路径是URL (通过 `PathValidator.isUrl()`): 也轮询 `_player.buffered()`
4. 异常处理: 捕获并打印错误但不崩溃

**设计决策:** 250ms 间隔平衡了UI流畅度与 FFI 调用开销。

---

### 1.5 TrackManager -- 音轨/字幕管理

**文件:** `lib/kernel/engine/track_manager.dart`

**职责:** 封装音频和字幕轨的枚举、选择和切换。委托给 `mdk.Player` 执行实际轨道切换。

**关键方法:**

| 方法 | 说明 |
|------|------|
| `switchAudioTrack(int index)` | 验证索引范围，设置 `_player.activeAudioTracks = [index]` |
| `switchSubtitleTrack(int index)` | 传 -1 禁用 (设置空列表) |
| `toggleSubtitle()` | 如果活跃轨道为空则启用轨道0，否则禁用 |

---

### 1.6 EnginePrewarm -- 冷启动优化

**文件:** `lib/kernel/engine/engine_prewarm.dart`

**职责:** 通过在应用启动时预初始化 MDK/FFmpeg 渲染上下文来消除冷启动延迟。创建临时 `mdk.Player` 并立即销毁，触发 FFmpeg 编解码器注册和 D3D11 上下文创建。

**API:**
- `static bool get isPrewarmed` -- 是否已预热
- `static Future<void> prewarm()` -- 幂等，可多次调用

**设计模式:** 惰性初始化 + 急切预热。私有构造函数防止实例化。

---

## 2. Bridge Layer (桥接层)

### 2.1 WindowBridge -- 窗口控制抽象

**文件:** `lib/kernel/bridge/window_bridge.dart`

**职责:** 解耦内核与窗口管理实现。内核通过此抽象接口控制窗口操作，不依赖任何 `window/` 包。

**枚举:** `WindowMode { windowed, maximized, minimized }`

**依赖注入模式:**
```dart
static WindowBridge get I => _instance ?? _noop;
static void inject(WindowBridge impl) => _instance = impl;
```
- `inject()` 由 `WindowService` 在初始化时调用
- 注入前，`I` 返回 `NoopWindowBridge` (安全降级)

**命令方法 (全部 `Future<void>`):**

| 方法 | 说明 |
|------|------|
| `minimize()` | 最小化窗口 |
| `toggleMaximize()` | 最大化/还原切换 |
| `close()` | 关闭窗口 |
| `startDragging()` | 开始拖拽 (无边框窗口) |
| `toggleAlwaysOnTop()` | 置顶切换 |

**响应式状态 (ValueNotifier):**

| Notifier | 类型 | 说明 |
|----------|------|------|
| `mode` | `ValueNotifier<WindowMode>` | 当前窗口模式 (windowed/maximized/minimized) |
| `isAlwaysOnTop` | `ValueNotifier<bool>` | 置顶状态 |
| `isMaximized` | `ValueNotifier<bool>` | 最大化状态 |
| `isResizing` | `ValueNotifier<bool>` | 正在调整大小 |

**`NoopWindowBridge`:** 所有方法为空操作。所有 ValueNotifier 持有安全默认值。确保即使没有注入窗口实现，内核也能工作。

---

## 3. Models (数据模型)

所有模型位于 `lib/kernel/models/`，是纯数据节点 -- 零内核依赖。

### 3.1 MediaState -- 播放状态机

```
idle → loading → playing ↔ paused → stopped → completed → error
                    ↑                          ↑
                    └── seeking (瞬态) ─────────┘
                    └── buffering (瞬态) ──────┘
```

| 值 | 说明 |
|----|------|
| `idle` | 初始状态，无媒体加载 |
| `loading` | 加载中 |
| `playing` | 播放中 |
| `paused` | 已暂停 |
| `stopped` | 手动停止或完成重置 |
| `completed` | 自然播放结束 |
| `error` | 发生错误 |
| `seeking` | 瞬态: seek进行中 |
| `buffering` | 瞬态: 网络缓冲或seek后 |

### 3.2 MediaErrorType -- 错误分类

| 值 | 说明 |
|----|------|
| `file` | 路径为空、文件未找到、无效路径 |
| `codec` | 不支持的格式、解码失败 |
| `playback` | 播放失败、seek失败 |
| `unknown` | 其他错误 |

### 3.3 PlayerErrorCode -- 细粒度错误码 (11种)

```
pathEmpty, fileNotFound, pathTraversal, unsupportedFormat,
openTimeout, decodeFailed, textureFailed, networkTimeout,
codecUnsupported, fileCorruption, unknown
```

### 3.4 ValidationErrorType -- 路径验证错误 (5种)

```
empty, pathTraversal, unsupportedFormat, invalidUrl, invalidPath
```

### 3.5 MediaInfo -- 媒体元数据

```dart
class MediaInfo {
  int duration;                    // 毫秒
  VideoCodecInfo? video;           // 视频编码信息
  List<AudioTrackInfo> audioTracks;
  List<SubtitleTrackInfo> subtitleTracks;
}

class VideoCodecInfo {
  int width, height;
  double par;                      // 像素宽高比
  String codec;
  double get aspectRatio => (width * par) / height;
}

class AudioTrackInfo {
  int index;
  String language, codec;
  int channels;
}

class SubtitleTrackInfo {
  int index;
  String language, title;
}
```

### 3.6 AspectRatioMode -- 画面比例枚举

| 值 | 标签 | mdk值 |
|----|------|-------|
| `keepOriginal` | "原始" | ~1.19e-7 (mdk epsilon) |
| `stretch` | "拉伸" | 0.0 |
| `cropFill` | "裁剪填充" | ~-1.19e-7 |
| `ratio4_3` | "4:3" | 4/3 |
| `ratio16_9` | "16:9" | 16/9 |
| `ratio21_9` | "21:9" | 21/9 |

**设计决策:** 枚举封装了 mdk 特定的魔法数字 (epsilon值)，解耦UI与原生库常量。

### 3.7 PlayMode -- 播放模式枚举

| 值 | 说明 |
|----|------|
| `normal` | 顺序播放，到末尾停止 |
| `loopAll` | 循环整个播放列表 |
| `loopSingle` | 单曲循环 |
| `shuffle` | 随机顺序 |

### 3.8 VideoEffectType -- 视频效果枚举

`brightness`, `contrast`, `hue`, `saturation`

与 `mdk.VideoEffect` 解耦以保持接口纯净。

### 3.9 PlaylistItem -- 播放列表项

```dart
class PlaylistItem {
  String path;           // 文件路径
  String name;           // 从路径派生的文件名
  toJson() / fromJson(); // JSON序列化
  == / hashCode;         // 基于 path
}
```

---

## 4. 模块间依赖图

```
kernel/models/                  (无内核依赖 -- 叶子节点)
    media_state.dart
    media_error_type.dart
    player_error.dart
    validation_error.dart
    media_info.dart
    aspect_ratio_mode.dart
    play_mode.dart
    video_effect_type.dart
    playlist_item.dart

kernel/bridge/
    window_bridge.dart          → flutter/foundation.dart only

kernel/engine/
    media_engine.dart           → models/{media_state, media_info, video_effect_type}
    engine_prewarm.dart         → fvp/mdk, utils/log
    fvp_callback_handler.dart   → fvp/mdk, models/media_state
    position_poller.dart        → fvp/mdk, services/path_validator
    track_manager.dart          → fvp/mdk, models/media_info
    fvp_engine.dart             → fvp/mdk
                                  → models/{media_error_type, media_state, media_info, video_effect_type}
                                  → services/path_validator, utils/path_utils
                                  → engine/{fvp_callback_handler, media_engine, position_poller, track_manager}
```

**依赖方向:**
- Models 是纯数据 -- 零内核依赖
- `media_engine.dart` 仅依赖 models (定义契约)
- Engine helpers 依赖 `fvp/mdk` 和 models
- `fvp_engine.dart` 组合 helpers 并实现 `media_engine`
- `window_bridge.dart` 完全独立于引擎层
- `engine_prewarm.dart` 是独立工具，无耦合

---

## 5. 关键设计模式

### 5.1 Strategy Pattern (策略模式)

`MediaEngine` 是抽象策略；`FvpEngine` 是具体实现。架构明确预期替代后端 (libmpv, video_player)。

### 5.2 Composition over Inheritance (组合优于继承)

`FvpEngine` 委托给三个聚焦的 helper，而非继承基类:
- `FvpCallbackHandler` -- 事件翻译
- `PositionPoller` -- 定时轮询
- `TrackManager` -- 轨道选择

### 5.3 Guard Clause Pattern (守卫子句)

`FvpEngine` 的每个公共方法以 `if (_disposed) return` 开始。`_guardedAction` 进一步包装非关键操作在 try/catch 中。

### 5.4 Defensive Clamping (防御性钳位)

输入参数在入口处钳位:
- 音量: `[0.0, 1.0]`
- Seek位置: `[0, duration]`
- 播放速率: `[0.25, 4.0]`
- 视频效果: `[-1.0, 1.0]`

### 5.5 Reentrancy Guard (重入守卫)

`FvpEngine.open()` 中的 `_isOpening` 防止并发 open 调用。如果已有 open 进行中，后续调用被静默丢弃。

### 5.6 Seek-Aware Polling (Seek感知轮询)

`PositionPoller.seeking` 在 seek 操作期间设为 `true`。防止 250ms 轮询定时器从原生播放器读取旧位置并覆盖 seek 目标。

### 5.7 Enum Decoupling (枚举解耦)

`AspectRatioMode`, `VideoEffectType`, `MediaState` 独立于 `mdk` 常量定义。`FvpEngine` 使用 switch 表达式在它们之间映射。

### 5.8 Structured Error Hierarchy (结构化错误层次)

三级错误建模:
- `MediaErrorType` (4值) -- 粗粒度分类用于UI操作按钮
- `PlayerErrorCode` (11值) -- 全管道细粒度错误码
- `ValidationErrorType` (5值) -- 路径验证专用

### 5.9 Timeout Protection (超时保护)

`open()` 应用两个超时:
- 10秒: `prepare()` (媒体解码)
- 5秒: `updateTexture()` (GPU纹理创建)

超时产生特定错误消息，区别于其他 prepare/texture 失败。
