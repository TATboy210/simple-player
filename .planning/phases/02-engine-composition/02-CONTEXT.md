---
phase: 02-engine-composition
type: context
created: "2026-06-29"
---

## Phase 2 讨论结论：引擎组合重构

### 核心发现

3 个 helper 类（VolumeController、SubtitleConfigurator、D3D11Configurator）**已存在但未被 FvpEngine 使用**。Phase 2 的核心工作是"激活"而非"创建"。

### 决策 1: D3D11 全部移入

`_applyD3d11Defaults()` 的全部 5 个 setProperty 移入 D3D11Configurator：
- `d3d11.sync.cpu` — CPU/GPU 同步
- `video.decoders` — 解码器优先级链
- `avcodec.threads` — FFmpeg 软解线程数（内存优化）
- `videoout.buffer_frames` — 渲染器最大帧缓冲（内存优化）
- `reader.starts_with_key` — 丢弃首个关键帧前的非关键包（内存优化）

D3D11Configurator 需要扩展：
- 新增 `applyDefaults()` 方法（包含全部 5 个属性）
- 新增 `DisplayConfig` 依赖（获取 d3d11SyncMode + refreshRate）
- 保留现有 `setSyncEnabled()` + `setHardwareDecoding()`

### 决策 2: FvpEngine 保留 guard

`_guardedAction`（disposed 检查 + error handling）保留在 FvpEngine 的方法中。Helper 类是纯逻辑，不负责生命周期管理。

委托模式：
```dart
@override
void setVolume(double value) {
  _guardedAction('setVolume', () {
    _volumeController.setVolume(value);
  });
}
```

### 决策 3: ValueNotifier 所有权不变

ValueNotifier 保持在 FvpEngine 的 `final` 字段中。Helper 通过构造函数接收引用：
```dart
VolumeController(this._player, {required this.volume, required this.isMuted});
```
这是安全的 — FvpEngine 持有 `final` 字段，helper 持有引用。

### 委托映射

| FvpEngine 方法 | 委托目标 | 行数变化 |
|---------------|---------|---------|
| `setVolume()` | `_volumeController.setVolume()` | -12 |
| `setMute()` | `_volumeController.setMute()` | -4 |
| `setExternalSubtitle()` | `_subtitleConfigurator.setExternalSubtitle()` | -3 |
| `setSubtitleDelay()` | `_subtitleConfigurator.setSubtitleDelay()` | -3 |
| `subtitleDelay` getter | `_subtitleConfigurator.getSubtitleDelay()` | -7 |
| `setEqualizer()` | `_subtitleConfigurator.setEqualizer()` | -3 |
| `_applyD3d11Defaults()` | `_d3d11Configurator.applyDefaults()` | -25 |
| `setD3d11SyncEnabled()` | `_d3d11Configurator.setSyncEnabled()` | -5 |
| `setHardwareDecoding()` | `_d3d11Configurator.setHardwareDecoding()` | -8 |

**预估行数变化：** 553 → ~484（减少 ~70 行，约 13%）

### 测试策略

- VolumeController/SubtitleConfigurator: 通过 MockEngine 集成测试覆盖
- D3D11Configurator: 依赖 mdk.Player.setProperty，需要 mock 或单独单元测试
- MockEngine (438行): 不变 — 重构后应继续通过所有 widget 测试
- 新 helper 单元测试: COMP-03 要求新 helper 有独立测试

### 约束

- COMP-05 CRITICAL: ValueNotifier 所有权保持在 FvpEngine 的 `final` 字段中
- PLAT-01: D3D11 属性必须在 `open()` 调用前设置
- `_guardedAction` 不移入 helper — FvpEngine 保留生命周期管理
