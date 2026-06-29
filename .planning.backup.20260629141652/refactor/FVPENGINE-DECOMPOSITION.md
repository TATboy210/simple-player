# FvpEngine Decomposition Plan

> P0 重构：693 行 → 目标 <300 行，提取 3 个职责模块

## 当前状态

- **文件**: `lib/kernel/engine/fvp_engine.dart` (693 行)
- **职责**: 12 个（违反单一职责原则）
- **最大问题**: `open()` 方法 ~150 行，混合路径验证、prepare、metadata 解析、纹理创建

## 已提取的 Helper（已完成）

| Helper | 职责 | 状态 |
|--------|------|------|
| `FvpCallbackHandler` | mdk 回调注册、状态映射 | ✅ 已提取 |
| `PositionPoller` | 250ms 定时器轮询 | ✅ 已提取 |
| `TrackManager` | 音频/字幕轨道切换 | ✅ 已提取 |

## 待提取模块

### 1. `NetworkConfigurator` (P0)

**职责**: URL 源的网络参数配置

**提取内容**:
- `_configureNetworkOptions()` (lines 163-209)
- 网络常量: `_networkTimeoutMs`, `_networkProbeSize`, `_networkAnalyzeDurationUs`, `_rtspProbeSize`

**接口设计**:
```dart
class NetworkConfigurator {
  static const _networkTimeoutMs = 10000;
  static const _networkProbeSize = 1000000;
  static const _networkAnalyzeDurationUs = 5000000;
  static const _rtspProbeSize = 500000;

  /// 为 URL 源配置 FFmpeg 网络参数
  static void configure(mdk.Player player, String url) {
    player.setProperty('timeout', _networkTimeoutMs.toString());
    player.setProperty('avformat.probesize', _networkProbeSize.toString());
    player.setProperty('avformat.analyzeduration', _networkAnalyzeDurationUs.toString());

    if (url.startsWith('rtsp://')) {
      _configureRtsp(player);
    } else if (url.startsWith('rtmp://')) {
      _configureRtmp(player);
    } else if (url.startsWith('srt://')) {
      _configureSrt(player);
    } else if (url.startsWith('udp://') || url.startsWith('tcp://')) {
      _configureUdpTcp(player);
    } else if (url.startsWith('http://') || url.startsWith('https://')) {
      _configureHttp(player);
    }
  }

  static void _configureRtsp(mdk.Player player) { ... }
  static void _configureRtmp(mdk.Player player) { ... }
  static void _configureSrt(mdk.Player player) { ... }
  static void _configureUdpTcp(mdk.Player player) { ... }
  static void _configureHttp(mdk.Player player) { ... }
}
```

**收益**: FvpEngine 减少 ~50 行，网络逻辑可独立测试

### 2. `MediaOpener` (P0)

**职责**: 媒体打开流程编排（路径验证 → prepare → metadata → texture）

**提取内容**:
- `open()` 方法的核心逻辑 (lines 226-378)
- 路径验证逻辑
- metadata 解析逻辑
- 纹理创建逻辑

**接口设计**:
```dart
class MediaOpener {
  final mdk.Player _player;
  final PositionPoller _positionPoller;
  final TrackManager _trackManager;

  MediaOpener(this._player, this._positionPoller, this._trackManager);

  /// 打开媒体文件或 URL
  ///
  /// 返回 [OpenResult] 表示成功或失败原因
  Future<OpenResult> open(String path) async {
    final trimmed = _validatePath(path);
    if (trimmed == null) return OpenResult.invalidPath;

    _player.media = trimmed;
    if (PathValidator.isUrl(trimmed)) {
      NetworkConfigurator.configure(_player, trimmed);
    }

    final prepareResult = await _prepare(trimmed);
    if (prepareResult != null) return prepareResult;

    final metadata = _parseMetadata();
    _trackManager.updateMediaInfo(metadata);

    final textureResult = await _createTexture(trimmed);
    if (textureResult != null) return textureResult;

    return OpenResult.success;
  }

  String? _validatePath(String path) { ... }
  Future<OpenResult?> _prepare(String path) { ... }
  MediaInfo _parseMetadata() { ... }
  Future<OpenResult?> _createTexture(String path) { ... }
}

sealed class OpenResult {
  const OpenResult();
  static const success = OpenSuccess();
  static const invalidPath = OpenError(MediaErrorType.file, '文件路径为空');
  // ...
}
final class OpenSuccess extends OpenResult { ... }
final class OpenError extends OpenResult {
  final MediaErrorType type;
  final String message;
  const OpenError(this.type, this.message);
}
```

**收益**: FvpEngine 减少 ~150 行，open 流程可独立测试

### 3. `VideoEffectController` (P1)

**职责**: 视频效果（亮度/对比度/饱和度/色调）和旋转

**提取内容**:
- `setVideoEffect()` (lines 592-604)
- `rotate()` (lines 607-619)
- `setAspectRatio()` (lines 622-626)
- `setDeinterlace()` (lines 629-637)

**接口设计**:
```dart
class VideoEffectController {
  final mdk.Player _player;

  VideoEffectController(this._player);

  void setEffect(VideoEffectType effect, double value) {
    final clamped = value.clamp(-1.0, 1.0);
    final mdkEffect = switch (effect) {
      VideoEffectType.brightness => mdk.VideoEffect.brightness,
      VideoEffectType.contrast => mdk.VideoEffect.contrast,
      VideoEffectType.hue => mdk.VideoEffect.hue,
      VideoEffectType.saturation => mdk.VideoEffect.saturation,
    };
    _player.setVideoEffect(mdkEffect, [clamped]);
  }

  void rotate(int degree) {
    const valid = {0, 90, 180, 270};
    if (!valid.contains(degree)) return;
    _player.rotate(degree);
  }

  void setAspectRatio(double ratio) => _player.setAspectRatio(ratio);

  void setDeinterlace(bool enable) {
    _player.setProperty(
      'video.avfilter',
      enable ? 'yadif=mode=send_frame:deint=all' : '',
    );
  }
}
```

**收益**: FvpEngine 减少 ~50 行，视频效果逻辑可独立测试

## 重构后 FvpEngine 结构

```dart
class FvpEngine extends PlayerEngine {
  // ─── Helpers ───
  late FvpCallbackHandler _callbackHandler;
  late PositionPoller _positionPoller;
  late TrackManager _trackManager;
  late MediaOpener _mediaOpener;
  late VideoEffectController _videoEffectController;

  // ─── ValueNotifier 实现 (不变) ───
  // ...

  // ─── 播放控制 (保留，<50 行) ───
  Future<void> open(String path) async {
    if (_disposed || _isOpening) return;
    _isOpening = true;
    state.value = MediaState.loading;
    try {
      final result = await _mediaOpener.open(path);
      switch (result) {
        case OpenSuccess():
          position.value = 0;
          _errorType = MediaErrorType.unknown;
          errorMessage.value = null;
        case OpenError(:final type, :final message):
          state.value = MediaState.error;
          _errorType = type;
          errorMessage.value = message;
      }
    } finally {
      isBuffering.value = false;
      _isOpening = false;
    }
  }

  void play() { ... }
  void pause() { ... }
  void stop() { ... }
  Future<void> seekTo(int ms) async { ... }

  // ─── 委托调用 (保留，~100 行) ───
  void setVideoEffect(VideoEffectType effect, double value) =>
      _guardedAction('setVideoEffect', () => _videoEffectController.setEffect(effect, value));

  void rotate(int degree) =>
      _guardedAction('rotate', () => _videoEffectController.rotate(degree));

  // ... 其他委托
}
```

## 重构后行数预估

| 文件 | 行数 |
|------|------|
| `fvp_engine.dart` | ~300 (从 693 减少) |
| `fvp_callback_handler.dart` | ~80 (已有) |
| `position_poller.dart` | ~80 (已有) |
| `track_manager.dart` | ~60 (已有) |
| `network_configurator.dart` | ~70 (新增) |
| `media_opener.dart` | ~180 (新增) |
| `video_effect_controller.dart` | ~60 (新增) |
| **总计** | ~830 (从 693 增加，但职责清晰) |

## 实施顺序

1. **Phase 1**: 提取 `NetworkConfigurator` (P0, 最简单)
2. **Phase 2**: 提取 `MediaOpener` (P0, 最大收益)
3. **Phase 3**: 提取 `VideoEffectController` (P1, 可选)

## 测试策略

- `NetworkConfigurator`: 测试 URL 协议识别、参数配置
- `MediaOpener`: 测试路径验证、prepare 超时、metadata 解析、纹理创建
- `VideoEffectController`: 测试效果值 clamping、旋转角度验证

## 风险

- **MDK API 变化**: 提取后更容易隔离变化
- **测试覆盖**: 需要更新 FakeEngine 以支持新接口
- **性能**: 间接调用增加微小开销（可忽略）
