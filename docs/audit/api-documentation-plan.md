# API Documentation Plan — Simple Player Flutter

> Generated: 2026-07-20
> Branch: feat/v1.8-stability-polish-plan-02-02

---

## 1. Executive Summary

### 1.1 Document Objectives

Simple Player Flutter 是一个基于 fvp (MDK/FFmpeg) 的 Flutter 桌面媒体播放器。项目经历了多轮重构（ISP 接口拆分、门面模式引入、ValueNotifier 响应式状态），形成了清晰的 4 层架构（Kernel / Bridge / Service / UI）。然而，随着代码演进，API 文档覆盖率参差不齐：核心引擎接口文档完善，但部分子模块和 UI 组件缺乏系统性文档。

本计划旨在：
1. **建立统一文档标准** — 基于 Dartdoc 规范，定义注释格式、示例代码模板
2. **补齐核心 API 文档** — 覆盖 kernel/ 层全部公共 API（engine / services / models / playlist / utils）
3. **完善 UI 层文档** — 为播放器组件、播放列表组件、共享组件添加接口文档
4. **建立质量保证机制** — 通过 CI 检查和代码审查确保文档持续更新

### 1.2 Coverage Scope

| Layer | Files | Public API Count | Current Coverage | Target Coverage |
|-------|-------|-----------------|-----------------|----------------|
| kernel/engine/ | 12 | ~65 | ~85% | 100% |
| kernel/services/ | 8 | ~45 | ~70% | 100% |
| kernel/models/ | 8 | ~30 | ~90% | 100% |
| kernel/playlist/ | 1 | ~15 | ~60% | 100% |
| kernel/utils/ | 5 | ~20 | ~80% | 100% |
| ui/player/ | 12 | ~50 | ~40% | 90% |
| ui/playlist/ | 4 | ~20 | ~30% | 90% |
| ui/shared/ | 5 | ~15 | ~50% | 90% |
| ui/dialogs/ | 3 | ~10 | ~40% | 90% |

### 1.3 Expected Benefits

- **开发者体验**: 新贡献者可在 30 分钟内理解核心 API 而非阅读源码
- **维护效率**: 接口变更时文档自动暴露不一致，降低回归风险
- **测试质量**: 契约文档（requires/ensures/modifies）直接指导测试用例设计
- **跨团队协作**: Bridge 层文档使 C++ 嵌入层和 Dart 层的边界更清晰

---

## 2. Current State Analysis

### 2.1 Existing Documentation Strengths

项目已有较好的文档基础：

1. **MediaEngine ISP 接口体系** — 7 个接口（EngineStateView / PlaybackControl / TrackControl / SubtitleConfig / VideoEffectControl / RendererControl / VolumeControl）全部有完整的 `///` doc comment，包含 requires/ensures/modifies 契约
2. **PlaybackController 门面** — 文件头 `library;` 注释说明架构位置和设计模式，每个公共方法有中英双语 doc comment
3. **PlaylistItem 数据模型** — 字段级 doc comment、fromJson 异常说明、copyWith 语义说明
4. **PlayMode / MediaState 枚举** — 每个枚举值有中英双语说明
5. **PathUtils / formatMs 工具函数** — 完整的参数说明和示例

### 2.2 Documentation Gaps

| Gap Category | Affected Files | Severity |
|-------------|---------------|----------|
| UI 组件缺少 props 说明 | PlayerScreen, ControlsOverlay, PlaylistPanel | HIGH |
| 子模块无文件头架构说明 | PlaybackStateManager, AutoAdvancePolicy | MEDIUM |
| 回调参数无类型文档 | PlayerActions, KeyboardHandler callbacks | MEDIUM |
| 缺少使用示例 | PlaybackController, Playlist | MEDIUM |
| 私有方法无 inline 注释 | _PlayerScreenState, _VolumeMerged | LOW |
| 模型类缺 equals/hashCode 说明 | PlaylistItem (已有, 但其他模型类缺失) | LOW |

### 2.3 API Classification

#### Core API (kernel/)
- **Engine 接口**: MediaEngine (composite), EngineStateView, PlaybackControl, TrackControl, SubtitleConfig, VideoEffectControl, RendererControl, VolumeControl
- **Engine 实现**: FvpEngine, PositionPoller, TrackManager, D3D11Configurator, SubtitleManager, EngineStateMachine
- **Services**: PlaybackController, PlaybackNavigator, FileOperations, PlaybackStateManager, AutoAdvancePolicy, SubtitleService, TrackPreferenceService, ThumbnailService, VideoProcessingService, PathValidator
- **Models**: PlaylistItem, PlayMode, MediaState (engine/), PlayerError, AppSettings, AspectRatioMode, ValidationError, TrackPreferences, ExportData, MediaInfo, AudioTrackInfo, SubtitleTrackInfo, VideoCodecInfo
- **Playlist**: Playlist
- **Persistence**: PlaylistStore, SettingsStore
- **Utils**: PathUtils, formatMs, DebugProbe, KernelLogger

#### UI API (ui/)
- **Player**: PlayerScreen, CustomTitleBar, ControlsOverlay, ControlBar, ProgressBar, VolumeControls, SpeedButton, KeyboardHandler, VideoSurface, DropHandler, SmartDragToResizeArea, PlaybackStatusOverlay
- **Playlist**: PlaylistPanel, FolderTab, HistoryTab, ThumbnailTile
- **Shared**: GlassContainer, EmptyState, PlayModeUtils, OsDOverlay
- **Dialogs**: SettingsDialog, MediaInfoDialog

#### Utility API (kernel/utils/ + kernel/bridge/)
- **Bridge**: WindowBridge, WindowMode
- **Scanner**: FolderScanner
- **Diagnostics**: KernelLogger, DebugProbe

---

## 3. Documentation Standards

### 3.1 Dartdoc Conventions

遵循 Dart 官方文档规范，结合项目双语惯例（中英并行）：

```dart
/// 中文主描述 — 简要说明用途
///
/// English description — explains purpose and behavior.
///
/// Architecture: 上下文说明模块在架构中的位置。
///
/// Contract:
/// - requires: 前置条件
/// - ensures: 后置条件
/// - modifies: 修改的状态
/// - throws: 异常条件
///
/// Example:
/// ```dart
/// final item = PlaylistItem(path: '/videos/movie.mkv');
/// print(item.name); // 'movie.mkv'
/// ```
```

### 3.2 Comment Format Rules

| Element | Format | Example |
|---------|--------|---------|
| 类/枚举 | `///` + 中英双语 | `/// 播放模式 — LoopAll/LoopSingle/Shuffle` |
| 公共方法 | `///` + 契约（requires/ensures/modifies） | 见 PlaybackControl |
| 公共 getter | `///` + 返回值说明 + pure read 标注 | `/// 当前音量值 (pure read)` |
| 构造函数 | `///` + 参数列表说明 | `/// 创建播放列表项。[path] 必填` |
| 私有方法 | `//` 行内注释说明 *why* | `// 延迟卸载，等待淡出动画完成` |
| 魔法数字 | 命名常量 + 注释 | `const _seekDeltaMs = 5000; // 5 秒步进` |
| 回调参数 | 独立 typedef + doc comment | `/// 文件拖放回调，参数为文件路径列表` |

### 3.3 Bilingual Strategy

- **核心 API (kernel/)**: 中英双语 — 中文为主描述，English 为补充说明
- **UI 层**: 中文为主，关键 props 补充英文
- **枚举值**: 中英双语（已有良好范例：MediaState, PlayMode）

### 3.4 Example Code Standards

每个公共类至少包含一个使用示例：

```dart
/// 播放控制器 — 全部运行时能力的统一门面
///
/// Example:
/// ```dart
/// final controller = PlaybackController(
///   engine: fvpEngine,
///   playlist: playlist,
///   onNeedRebuild: () => setState(() {}),
/// );
/// await controller.init();
/// await controller.playIndex(0);
/// ```
```

---

## 4. Documentation Generation Strategy

### 4.1 Auto-Generation (dart doc)

**适用范围**: 所有 `///` doc comment 注释的公共 API

```bash
# 生成 HTML 文档
dart doc

# 输出到 doc/api/ 目录
# 可集成到 CI 流程作为文档完整性检查
```

**CI 集成**:
```yaml
# .github/workflows/docs.yml
- name: Generate docs
  run: dart doc --validate-links
- name: Check coverage
  run: dart doc --dry-run --warnings
```

### 4.2 Manual Documentation

以下内容需要手动编写，无法自动生成：

1. **架构文档** — 模块关系、数据流、设计决策
2. **使用指南** — 快速开始、常见场景、最佳实践
3. **迁移指南** — API 变更的升级路径
4. **示例代码** — 完整的端到端用法

### 4.3 Documentation-as-Code Workflow

```
编写代码 → 同步写 doc comment → dart doc 生成 → CI 验证 → PR 审查
     ↑                                                      ↓
     └──────────── 文档不通过 ← 审查发现问题 ←──────────────┘
```

---

## 5. Core API Documentation Checklist

### 5.1 kernel/engine/ — Engine Layer

#### 5.1.1 MediaEngine (Composite Interface)

- **File**: `lib/kernel/engine/media_engine.dart`
- **Status**: DONE — 文件头注释完整，说明 ISP 聚合设计和架构位置
- **Action**: 无需补充

| Member | Doc Status | Action |
|--------|-----------|--------|
| class MediaEngine | DONE | — |
| implements 列表 | DONE | — |

#### 5.1.2 EngineStateView (Read-Only State)

- **File**: `lib/kernel/engine/engine_state_view.dart`
- **Status**: DONE — 全部 15 个 getter 有完整 doc comment
- **Action**: 补充 dispose() 的生命周期说明

| Member | Doc Status | Action |
|--------|-----------|--------|
| textureId | DONE | — |
| state | DONE | — |
| position | DONE | — |
| duration | DONE | — |
| volume | DONE | — |
| isMuted | DONE | — |
| isBuffering | DONE | — |
| isSeeking | DONE | — |
| subtitleText | DONE | — |
| buffered | DONE | — |
| aspectRatio | DONE | — |
| lastError | DONE | — |
| playbackSpeed | DONE | — |
| mediaInfo | DONE | — |
| stateMachine | DONE | — |
| dispose() | PARTIAL | 补充：disposed 后的 ValueNotifier 行为 |

#### 5.1.3 PlaybackControl (Control Methods)

- **File**: `lib/kernel/engine/playback_control.dart`
- **Status**: DONE — 全部方法有 requires/ensures/modifies 契约
- **Action**: 补充异常场景的使用示例

| Member | Doc Status | Action |
|--------|-----------|--------|
| open() | DONE | 补充 async 示例 |
| play() | DONE | — |
| pause() | DONE | — |
| stop() | DONE | — |
| togglePlayPause() | DONE | — |
| seekTo() | DONE | 补充 clamp 行为示例 |
| setVolume() | DONE | — |
| setMute() | DONE | — |
| setPlaybackRate() | DONE | — |
| setRange() | DONE | — |
| skipForward() | DONE | — |
| skipBack() | DONE | — |

#### 5.1.4 TrackControl (Audio Tracks)

- **File**: `lib/kernel/engine/track_control.dart`
- **Status**: DONE
- **Action**: 补充 AudioTrackInfo 数据模型引用

#### 5.1.5 SubtitleConfig (Subtitle Management)

- **File**: `lib/kernel/engine/subtitle_config.dart`
- **Status**: DONE
- **Action**: 补充 SubtitleTrackInfo 数据模型引用

#### 5.1.6 VideoEffectControl (Video Effects)

- **File**: `lib/kernel/engine/video_effect_control.dart`
- **Status**: DONE
- **Action**: 补充 VideoEffectType 枚举文档

#### 5.1.7 RendererControl (Renderer Config)

- **File**: `lib/kernel/engine/renderer_control.dart`
- **Status**: DONE
- **Action**: 补充 D3D11 参数说明

#### 5.1.8 VolumeControl (Volume)

- **File**: `lib/kernel/engine/volume_control.dart`
- **Status**: DONE
- **Action**: 无需补充

#### 5.1.9 MediaState (State Enum)

- **File**: `lib/kernel/engine/media_state.dart`
- **Status**: DONE — 6 个枚举值有中英双语说明
- **Action**: 补充状态转换图 (ASCII art)

#### 5.1.10 FvpEngine (Concrete Implementation)

- **File**: `lib/kernel/engine/fvp_engine.dart`
- **Status**: NEEDS REVIEW — 需检查内部方法注释
- **Action**:
  - [ ] 文件头架构说明（MDK 桥接、D3D11 渲染、Texture 生命周期）
  - [ ] open() 的完整流程注释（MDK.setMedia → 等待 MediaOpened → 初始化 Texture）
  - [ ] dispose() 的资源释放顺序说明
  - [ ] 错误恢复路径注释（codec 降级、网络重试）

#### 5.1.11 PositionPoller

- **File**: `lib/kernel/engine/position_poller.dart`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] 文件头：Timer-based position polling 机制说明
  - [ ] 轮询间隔策略说明
  - [ ] 与 engine 状态的同步机制

#### 5.1.12 TrackManager

- **File**: `lib/kernel/engine/track_manager.dart`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] 文件头：音轨/字幕轨管理职责
  - [ ] 轨道切换的 MDK API 调用说明

#### 5.1.13 EngineStateMachine

- **File**: `lib/kernel/engine/engine_state_machine.dart`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] 文件头：状态机设计（6 态正交枚举 + openGeneration 计数器）
  - [ ] _canTransitionTo 转换表文档
  - [ ] generation 原子递增的并发安全说明

---

### 5.2 kernel/services/ — Service Layer

#### 5.2.1 PlaybackController (Facade)

- **File**: `lib/kernel/services/playback_controller.dart`
- **Status**: GOOD — 文件头 + class doc + 大部分方法有 doc comment
- **Action**:
  - [ ] 补充 init() 的 settings 参数使用示例
  - [ ] 补充 dispose() 的资源释放顺序说明
  - [ ] 补充子模块交互的时序说明

| Member | Doc Status | Action |
|--------|-----------|--------|
| engine | DONE | — |
| playlist | DONE | — |
| navigator | DONE | — |
| fileOps | DONE | — |
| stateManager | DONE | — |
| autoAdvance | DONE | — |
| probe | DONE | — |
| currentFileName | DONE | — |
| onNeedRebuild() | DONE | — |
| onError | DONE | — |
| subtitleService | DONE | — |
| trackPreferenceService | DONE | — |
| savePlaylist() | DONE | — |
| playIndex() | DONE | — |
| playNext() | DONE | — |
| playPrevious() | DONE | — |
| openAndPlay() | DONE | — |
| addFiles() | DONE | — |
| validationError | DONE | — |
| removeAt() | DONE | — |
| reorder() | DONE | — |
| clearPlaylist() | DONE | — |
| togglePlayMode() | DONE | — |
| init() | PARTIAL | 补充 settings 使用示例 |
| dispose() | PARTIAL | 补充释放顺序说明 |

#### 5.2.2 PlaybackNavigator

- **File**: `lib/kernel/services/playback_navigator.dart`
- **Status**: GOOD — 文件头说明并发模型
- **Action**:
  - [ ] playIndex() 的完整流程步骤注释（已部分存在，需完善）
  - [ ] openGeneration 守卫的时序图说明
  - [ ] playNext() / playPrevious() 的 shuffle 逻辑说明

#### 5.2.3 PlaybackStateManager

- **File**: `lib/kernel/services/playback_state_manager.dart`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] 文件头：设置恢复、断点保存、销毁持久化的职责说明
  - [ ] init() 的 settings 加载流程
  - [ ] 断点保存的触发时机（position 变化、dispose）

#### 5.2.4 AutoAdvancePolicy

- **File**: `lib/kernel/services/auto_advance_policy.dart`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] 文件头：自动连播策略（completed → loopSingle / next）
  - [ ] 与 PlayMode 的交互逻辑

#### 5.2.5 FileOperations

- **File**: `lib/kernel/services/file_operations.dart`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] 文件头：文件打开和批量添加职责
  - [ ] openAndPlay() 的路径校验流程
  - [ ] addFiles() 的去重逻辑

#### 5.2.6 SubtitleService

- **File**: `lib/kernel/services/subtitle_service.dart`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] 文件头：外挂字幕管理职责
  - [ ] 字幕文件格式支持列表

#### 5.2.7 TrackPreferenceService

- **File**: `lib/kernel/services/track_preference_service.dart`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] 文件头：轨道偏好持久化职责
  - [ ] load() / save() 的存储格式说明

#### 5.2.8 ThumbnailService

- **File**: `lib/kernel/services/thumbnail_service.dart`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] 文件头：平台感知缩略图服务（LRU 缓存）
  - [ ] 缓存策略说明（容量、淘汰、失效）
  - [ ] Windows COM / macOS / Linux 的平台差异

#### 5.2.9 VideoProcessingService

- **File**: `lib/kernel/services/video_processing_service.dart`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] 文件头：色彩校正和旋转处理职责

#### 5.2.10 PathValidator

- **File**: `lib/kernel/services/path_validator.dart`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] 文件头：路径安全校验（路径遍历防护）
  - [ ] 校验规则列表

---

### 5.3 kernel/models/ — Data Models

#### 5.3.1 PlaylistItem

- **File**: `lib/kernel/models/playlist_item.dart`
- **Status**: DONE — 完整的字段说明、copyWith、fromJson/toJson、equals/hashCode
- **Action**: 无需补充

#### 5.3.2 PlayMode

- **File**: `lib/kernel/models/play_mode.dart`
- **Status**: DONE
- **Action**: 无需补充

#### 5.3.3 PlayerError

- **File**: `lib/kernel/models/player_error.dart`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] sealed class 层次结构文档
  - [ ] 各错误子类的触发条件说明
  - [ ] 错误恢复建议

#### 5.3.4 AppSettings

- **File**: `lib/kernel/models/app_settings.dart`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] 文件头：应用设置数据模型
  - [ ] 各字段的默认值和有效范围

#### 5.3.5 AspectRatioMode

- **File**: `lib/kernel/models/aspect_ratio_mode.dart`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] 枚举值说明和使用场景

#### 5.3.6 ValidationError

- **File**: `lib/kernel/models/validation_error.dart`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] 错误类型和修复建议

#### 5.3.7 TrackPreferences

- **File**: `lib/kernel/models/track_preferences.dart`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] 轨道偏好数据结构说明

#### 5.3.8 ExportData

- **File**: `lib/kernel/models/export_data.dart`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] 数据导出格式说明

#### 5.3.9 MediaInfo (engine/models/)

- **File**: `lib/kernel/engine/models/media_info.dart`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] 字段说明（codec、resolution、tracks）

#### 5.3.10 AudioTrackInfo / SubtitleTrackInfo / VideoCodecInfo

- **Files**: `lib/kernel/engine/models/`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] 各数据模型的字段说明

---

### 5.4 kernel/playlist/ — Playlist

#### 5.4.1 Playlist

- **File**: `lib/kernel/playlist/playlist.dart`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] 文件头：播放列表管理（当前索引、播放模式、历史记录）
  - [ ] currentIndex 的边界处理说明
  - [ ] peekNext() / peekPrevious() 的 shuffle 逻辑
  - [ ] add() / removeAt() / reorder() 的不变量说明

---

### 5.5 kernel/utils/ — Utilities

#### 5.5.1 PathUtils

- **File**: `lib/kernel/utils/path_utils.dart`
- **Status**: DONE
- **Action**: 无需补充

#### 5.5.2 formatMs

- **File**: `lib/kernel/utils/time_utils.dart`
- **Status**: DONE
- **Action**: 无需补充

#### 5.5.3 DebugProbe

- **File**: `lib/kernel/utils/debug_probe.dart`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] 性能探针使用说明

#### 5.5.4 KernelLogger

- **File**: `lib/kernel/diagnostics/kernel_logger.dart`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] 日志级别和使用规范

---

## 6. UI API Documentation Checklist

### 6.1 ui/player/ — Player Components

#### 6.1.1 PlayerScreen

- **File**: `lib/ui/player/player_screen.dart`
- **Status**: PARTIAL — class doc 存在但 props 无文档
- **Action**:
  - [ ] 每个构造函数参数的 doc comment
  - [ ] 响应式布局逻辑说明（≥600dp Row / <600dp Stack）
  - [ ] SmartDragToResizeArea 的 canUpdate 问题说明（已有 inline 注释，需提升为 doc comment）

```dart
/// 播放器主屏幕 — 组合层，接线键盘 + 控制层
///
/// 布局策略：
/// - 宽屏（≥600dp）: Row 布局，视频左、播放列表右
/// - 窄屏（<600dp）: 播放列表叠加为 Stack overlay
///
/// [engine] 播放引擎实例（只读状态 + 控制）
/// [controller] 播放控制器（门面入口）
/// [playlist] 播放列表管理器
/// [playlistGeneration] 播放列表变更通知器
/// [windowService] 窗口桥接服务
/// [customBindings] 自定义键盘绑定覆盖
/// [onTogglePlaylist] 播放列表切换回调
/// [onSettings] 设置面板打开回调
/// [onSettingsSecondary] 右键设置菜单回调
/// [onOpenFile] 文件打开回调
/// [onTogglePlayMode] 播放模式切换回调
/// [onFilesDropped] 文件拖放回调
/// [onDragHoverChanged] 拖拽悬停状态变化回调
/// [emptyState] 空状态 Widget（idle 时显示）
/// [onFolderScanned] 文件夹扫描完成回调
/// [onClearHistory] 清除历史回调
/// [onShowProperties] 显示文件属性回调
```

#### 6.1.2 ControlsOverlay

- **File**: `lib/ui/player/controls_overlay.dart`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] 自动隐藏机制说明（Timer + 鼠标移动重置）
  - [ ] PlayerActions 回调参数文档

#### 6.1.3 ControlBar

- **File**: `lib/ui/player/control_bar.dart`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] 毛玻璃控制栏的布局说明
  - [ ] 各按钮的回调参数

#### 6.1.4 ProgressBar

- **File**: `lib/ui/player/progress_bar.dart`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] SeekBar 交互说明（拖拽、点击、缩略图预览）
  - [ ] 与 engine.position 的同步机制

#### 6.1.5 VolumeControls

- **File**: `lib/ui/player/volume_controls.dart`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] 音量滑块 + 静音按钮的交互说明
  - [ ] 100ms debounce 策略说明

#### 6.1.6 SpeedButton

- **File**: `lib/ui/player/speed_button.dart`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] 横向选择器的交互说明
  - [ ] 倍速范围和步进值

#### 6.1.7 KeyboardHandler

- **File**: `lib/ui/player/keyboard_handler.dart`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] 20+ 快捷键映射表
  - [ ] customBindings 覆盖机制说明

#### 6.1.8 VideoSurface

- **File**: `lib/ui/player/video_surface.dart`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] Texture 渲染说明
  - [ ] aspectRatio 适配逻辑

#### 6.1.9 DropHandler

- **File**: `lib/ui/player/drop_handler.dart`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] 文件拖放处理流程

### 6.2 ui/playlist/ — Playlist Components

#### 6.2.1 PlaylistPanel

- **File**: `lib/ui/playlist/playlist_panel.dart`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] 浮窗动画说明（淡入/淡出、滑入/滑出）
  - [ ] 双 Tab 布局说明（文件夹 / 历史）

#### 6.2.2 FolderTab / HistoryTab

- **Files**: `lib/ui/playlist/`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] 分组逻辑和排序规则

#### 6.2.3 ThumbnailTile

- **File**: `lib/ui/playlist/thumbnail_tile.dart`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] 16:9 缩略图卡片的渲染说明

### 6.3 ui/shared/ — Shared Components

#### 6.3.1 GlassContainer

- **File**: `lib/ui/shared/glass_container.dart`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] 3 层毛玻璃结构说明（BackdropFilter + bgGlass + borderHighlight）

#### 6.3.2 EmptyState

- **File**: `lib/ui/shared/empty_state.dart`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] 空状态显示条件

### 6.4 ui/dialogs/ — Dialogs

#### 6.4.1 SettingsDialog

- **File**: `lib/ui/dialogs/settings_dialog.dart`
- **Status**: NEEDS REVIEW
- **Action**：
  - [ ] 侧边栏导航结构
  - [ ] 延迟应用机制说明

#### 6.4.2 MediaInfoDialog

- **File**: `lib/ui/dialogs/media_info_dialog.dart`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] 文件属性展示字段

---

## 7. Utility API Documentation Checklist

### 7.1 kernel/bridge/ — Window Bridge

#### 7.1.1 WindowBridge

- **File**: `lib/kernel/bridge/window_bridge.dart`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] Win32 MethodChannel 通信协议说明
  - [ ] 命令/事件列表

#### 7.1.2 WindowMode

- **File**: `lib/kernel/bridge/window_mode.dart`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] 枚举值说明（windowed / maximized / fullscreen）

### 7.2 kernel/scanner/ — Folder Scanner

#### 7.2.1 FolderScanner

- **File**: `lib/kernel/scanner/folder_scanner.dart`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] 支持的视频格式列表
  - [ ] 递归扫描策略

### 7.3 kernel/persistence/ — Storage

#### 7.3.1 PlaylistStore

- **File**: `lib/kernel/persistence/playlist_store.dart`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] JSON 序列化格式说明
  - [ ] 存储路径

#### 7.3.2 SettingsStore

- **File**: `lib/kernel/persistence/settings_store.dart`
- **Status**: NEEDS REVIEW
- **Action**:
  - [ ] 键值对存储说明

---

## 8. Documentation Templates

### 8.1 File Header Template

```dart
/// [模块中文名] — [一句话职责说明]
///
/// [Module English Name] — [one-line responsibility description].
///
/// Architecture:
///   [上层] → **[本模块]** → [下层]
///
/// Design pattern: [设计模式名称]
///
/// Responsibilities:
/// - [职责 1]
/// - [职责 2]
/// - [职责 3]
library;
```

### 8.2 Class Doc Template

```dart
/// [类中文名] — [一句话说明]
///
/// [English class description].
///
/// [架构位置说明或设计决策说明].
///
/// Example:
/// ```dart
/// final instance = ClassName(param: value);
/// instance.method();
/// ```
class ClassName { ... }
```

### 8.3 Method Doc Template

```dart
/// [方法中文说明]
///
/// [English method description].
///
/// requires: [前置条件]
/// ensures: [后置条件]
/// modifies: [修改的状态]
/// throws: [异常条件]
Future<void> methodName(Type param) async { ... }
```

### 8.4 Enum Doc Template

```dart
/// [枚举中文名] — [一句话说明]
///
/// [English enum description].
///
/// Values:
/// - [value1]: [说明]
/// - [value2]: [说明]
enum EnumName {
  /// [值中文说明].
  ///
  /// [English value description].
  value1,

  /// [值中文说明].
  ///
  /// [English value description].
  value2,
}
```

### 8.5 Callback Typedef Template

```dart
/// [回调中文说明]
///
/// [English callback description].
///
/// - [param1]: [参数说明]
/// - [param2]: [参数说明]
typedef CallbackName = void Function(Type param1, Type param2);
```

---

## 9. Naming Conventions

### 9.1 Doc Comment Naming

| Entity | Convention | Example |
|--------|-----------|---------|
| 类 | `/// 中文名 — 英文补充` | `/// 播放控制器 — unified facade` |
| 方法 | `/// 动词 + 宾语` | `/// 播放指定索引` |
| Getter | `/// 名词 + (pure read)` | `/// 当前音量值 (pure read)` |
| 枚举值 | `/// 中文说明. /// English.` | `/// 顺序播放. /// Sequential.` |
| 回调 | `/// 动词 + 宾语 + 回调` | `/// 文件拖放回调` |

### 9.2 Internal Naming

| Entity | Convention | Example |
|--------|-----------|---------|
| 私有方法 | `// why 注释` | `// 延迟卸载，等待淡出动画完成` |
| 魔法数字 | `命名常量` | `const _seekDeltaMs = 5000;` |
| TODO | `// TODO(reason): action` | `// TODO(perf): cache thumbnails` |
| FIXME | `// FIXME(bug-id): description` | `// FIXME(BUG-01): race condition` |

---

## 10. Quality Assurance

### 10.1 Automated Checks

#### 10.1.1 dart doc Validation

```bash
# 检查文档完整性（未文档化的公共 API 会产生 warning）
dart doc --dry-run --warnings

# 检查链接有效性
dart doc --validate-links
```

#### 10.1.2 Custom Lint Rule

```yaml
# analysis_options.yaml
analyzer:
  errors:
    public_member_api_docs: warning  # 未文档化的公共 API 产生 warning
```

#### 10.1.3 CI Pipeline Integration

```yaml
# .github/workflows/docs.yml
name: Documentation
on: [push, pull_request]
jobs:
  docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
      - run: dart doc --dry-run --warnings
      - run: dart doc --validate-links
```

### 10.2 Manual Review Checklist

PR 审查时检查以下文档项：

- [ ] 新增/修改的公共 API 有 `///` doc comment
- [ ] doc comment 包含中文主描述
- [ ] 关键方法有 requires/ensures/modifies 契约
- [ ] 枚举值有独立 doc comment
- [ ] 复杂逻辑有 inline 注释说明 *why*
- [ ] 魔法数字已替换为命名常量
- [ ] 回调参数有类型文档

### 10.3 Documentation Coverage Report

每次 PR 生成覆盖率报告：

```bash
# 统计未文档化的公共 API 数量
dart doc --dry-run 2>&1 | grep -c "warning"
```

目标：0 warnings for kernel/ 层，<5 warnings for ui/ 层。

---

## 11. Implementation Roadmap

### Phase 1: Foundation (Week 1-2) — kernel/ 层核心文档

**目标**: kernel/ 层 100% 文档覆盖

| Task | Priority | Est. Hours | Owner |
|------|----------|-----------|-------|
| engine/ 层补充（FvpEngine, PositionPoller, TrackManager, EngineStateMachine） | P0 | 4h | — |
| services/ 层补充（PlaybackStateManager, AutoAdvancePolicy, FileOperations） | P0 | 3h | — |
| models/ 层补充（PlayerError, AppSettings, MediaInfo 等） | P0 | 2h | — |
| playlist/ 层补充（Playlist） | P0 | 2h | — |
| utils/ 层补充（DebugProbe, KernelLogger） | P1 | 1h | — |
| bridge/ 层补充（WindowBridge, WindowMode） | P1 | 1h | — |
| persistence/ 层补充（PlaylistStore, SettingsStore） | P1 | 1h | — |
| 启用 public_member_api_docs lint | P0 | 0.5h | — |
| 修复 kernel/ 层所有 lint warnings | P0 | 2h | — |

**Deliverables**:
- kernel/ 层 100% 文档覆盖
- `dart doc --dry-run --warnings` 0 warnings for kernel/
- CI 集成 dart doc 检查

### Phase 2: Polish (Week 3-4) — UI 层文档 + 使用示例

**目标**: UI 层 90% 文档覆盖，核心 API 补充使用示例

| Task | Priority | Est. Hours | Owner |
|------|----------|-----------|-------|
| PlayerScreen 构造函数参数文档 | P0 | 1h | — |
| ControlsOverlay / ControlBar 文档 | P0 | 2h | — |
| PlaylistPanel / FolderTab / HistoryTab 文档 | P0 | 2h | — |
| KeyboardHandler 快捷键映射表 | P1 | 1h | — |
| GlassContainer 毛玻璃结构说明 | P1 | 0.5h | — |
| SettingsDialog / MediaInfoDialog 文档 | P1 | 1h | — |
| PlaybackController 使用示例 | P0 | 1h | — |
| Playlist 使用示例 | P0 | 1h | — |
| MediaEngine 接口组合示例 | P1 | 0.5h | — |

**Deliverables**:
- UI 层 90% 文档覆盖
- 核心 API 有完整使用示例
- `dart doc --dry-run --warnings` <5 warnings total

### Phase 3: Optimize (Week 5-6) — 文档质量优化 + 持续维护

**目标**: 建立文档维护机制，优化生成的 HTML 文档

| Task | Priority | Est. Hours | Owner |
|------|----------|-----------|-------|
| 配置 dartdoc.yaml 自定义主题 | P2 | 2h | — |
| 添加 README.md 到 doc/ 输出 | P2 | 1h | — |
| 创建 API 快速参考卡（markdown） | P2 | 2h | — |
| 建立文档审查 checklist（集成到 PR 模板） | P1 | 0.5h | — |
| 运行 dart doc 并修复所有 warnings | P1 | 2h | — |
| 创建 CONTRIBUTING.md 文档规范章节 | P2 | 1h | — |

**Deliverables**:
- 自定义 dartdoc 主题
- API 快速参考卡
- PR 模板集成文档审查
- `dart doc` 0 warnings

---

## 12. Appendix

### A. File Inventory

#### kernel/engine/ (12 files)

```
lib/kernel/engine/
├── media_engine.dart           # Composite interface (DONE)
├── engine_state_view.dart      # Read-only state (DONE)
├── playback_control.dart       # Control methods (DONE)
├── track_control.dart          # Audio tracks (DONE)
├── subtitle_config.dart        # Subtitle management (DONE)
├── video_effect_control.dart   # Video effects (DONE)
├── renderer_control.dart       # Renderer config (DONE)
├── volume_control.dart         # Volume control (DONE)
├── media_state.dart            # State enum (DONE)
├── fvp_engine.dart             # Concrete impl (NEEDS REVIEW)
├── position_poller.dart        # Position polling (NEEDS REVIEW)
├── track_manager.dart          # Track management (NEEDS REVIEW)
└── engine_state_machine.dart   # State machine (NEEDS REVIEW)
```

#### kernel/services/ (8 files)

```
lib/kernel/services/
├── playback_controller.dart    # Facade (GOOD)
├── playback_navigator.dart     # Navigation (GOOD)
├── playback_state_manager.dart # State mgmt (NEEDS REVIEW)
├── auto_advance_policy.dart    # Auto-advance (NEEDS REVIEW)
├── file_operations.dart        # File ops (NEEDS REVIEW)
├── subtitle_service.dart       # Subtitles (NEEDS REVIEW)
├── track_preference_service.dart # Track prefs (NEEDS REVIEW)
└── thumbnail_service.dart      # Thumbnails (NEEDS REVIEW)
```

#### kernel/models/ (8 files + 4 engine/models)

```
lib/kernel/models/
├── playlist_item.dart          # (DONE)
├── play_mode.dart              # (DONE)
├── player_error.dart           # (NEEDS REVIEW)
├── app_settings.dart           # (NEEDS REVIEW)
├── aspect_ratio_mode.dart      # (NEEDS REVIEW)
├── validation_error.dart       # (NEEDS REVIEW)
├── track_preferences.dart      # (NEEDS REVIEW)
└── export_data.dart            # (NEEDS REVIEW)

lib/kernel/engine/models/
├── media_info.dart             # (NEEDS REVIEW)
├── audio_track_info.dart       # (NEEDS REVIEW)
├── subtitle_track_info.dart    # (NEEDS REVIEW)
└── video_codec_info.dart       # (NEEDS REVIEW)
```

#### ui/player/ (12 files)

```
lib/ui/player/
├── player_screen.dart          # (PARTIAL)
├── controls_overlay.dart       # (NEEDS REVIEW)
├── control_bar.dart            # (NEEDS REVIEW)
├── progress_bar.dart           # (NEEDS REVIEW)
├── volume_controls.dart        # (NEEDS REVIEW)
├── speed_button.dart           # (NEEDS REVIEW)
├── keyboard_handler.dart       # (NEEDS REVIEW)
├── video_surface.dart          # (NEEDS REVIEW)
├── drop_handler.dart           # (NEEDS REVIEW)
├── custom_title_bar.dart       # (NEEDS REVIEW)
├── player_actions.dart         # (NEEDS REVIEW)
└── playback_status_overlay.dart # (NEEDS REVIEW)
```

### B. Documentation Metrics Target

| Metric | Current | Phase 1 Target | Phase 2 Target | Phase 3 Target |
|--------|---------|---------------|---------------|---------------|
| kernel/ coverage | ~78% | 100% | 100% | 100% |
| ui/ coverage | ~38% | 38% | 90% | 95% |
| dart doc warnings | ~25 | 0 (kernel) | <5 total | 0 total |
| Example code | 5 | 5 | 15 | 20 |
| Lint rule enabled | No | Yes | Yes | Yes |

### C. References

- [Dart Doc Comment Guidelines](https://dart.dev/guides/language/effective-dart/documentation)
- [dartdoc Configuration](https://github.com/dart-lang/dartdoc#readme)
- [Flutter API Docs Style](https://github.com/flutter/flutter/wiki/Style-guide-for-Flutter-repo#documentation-dartdocs-javadocs-etc)
- Project CLAUDE.md — Comment Policy section
