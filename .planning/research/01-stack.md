# Technology Stack — v4.5 设置面板横向重构 + 音频功能填充

**Project:** simple_player_flutter
**Milestone:** v4.5 (Panel Layout Redesign + Audio Features)
**Researched:** 2026-07-25
**Overall confidence:** HIGH (grounded in live code at `lib/kernel/engine/*` + `lib/ui/dialogs/settings/*`)

---

## Executive Summary

v4.5 不引入任何新依赖。所有目标功能可由 **现有 fvp 0.37.2 + v3.0 内核接口 + v4.0 设置面板骨架 + Flutter Material 自带 widget** 组合实现。研究聚焦五个维度：(1) fvp/MDK 音频能力边界，(2) Flutter 桌面 UI 构建块选择，(3) ValueNotifier + 延迟应用模式，(4) Steam Input 手柄输入链路，(5) 现有内核接口供给清单。

关键判断：**音频 tab 的 EQ/平衡/同步/标准化全部经 `MediaEngine.setEqualizer(afFilter)` 单一入口走 FFmpeg `af` 滤镜链**——无需扩展内核接口，只需在 AudioTab 内构造滤镜字符串并经 PendingSettingsState 延迟提交。手柄输入模式检测是 v4.5 唯一真正的新增基础设施，因 Steam Input API 把手柄事件转成合成键盘事件，Flutter 侧无法从 KeyEvent 区分设备源——必须用启发式或显式 toggle。

---

## 1. fvp (MDK/FFmpeg) Desktop Playback Stack

### 1.1 当前版本与绑定

| 项 | 值 | 来源 |
|----|----|----|
| fvp pub package | `^0.37.2` | `pubspec.yaml` L13 |
| 后端引擎 | MDK (libmdk.dll) + FFmpeg demuxer/decoder | Context7 `/wang-bin/fvp` |
| 渲染 API (Windows) | D3D11 (默认，硬件解码默认开) | fvp wiki Features |
| 绑定方式 | `MdkPlayerLike` 抽象 + `FvpEngine` 实现 + `TrackManager`/`VolumeController`/`SubtitleConfigurator` 委托 | `lib/kernel/engine/fvp_engine.dart` |

### 1.2 音频 API 表面 — v4.5 音频 tab 可消费的能力

| 能力 | 接口入口 | 实现路径 | 可用性 | 备注 |
|------|----------|---------|--------|------|
| 查询音轨列表 | `MediaEngine.getAudioTracks()` → `TrackControl.getAudioTracks()` | `TrackManager` 读 `MediaInfo.audioTracks` | ✓ 现有 | 返回 `List<AudioTrackInfo>`（codec/channels/language） |
| 切换音轨 | `MediaEngine.switchAudioTrack(int)` → `TrackControl.switchAudioTrack()` | `_player.activeAudioTracks = [idx]` | ✓ 现有 | MDK 索引语义，越界静默忽略 |
| 当前活跃音轨 | `MediaEngine.activeAudioTracks` | `_player.activeAudioTracks` | ✓ 现有 | `List<int>`，空=无音轨 |
| 设置音量 | `MediaEngine.setVolume(double)` → `VolumeControl.setVolume()` | `VolumeController` 写 `ValueNotifier<double> volume` | ✓ 现有 | 0.0~1.0，clamp，穿越 0 自动联动 mute |
| 静音切换 | `MediaEngine.setMute(bool)` → `VolumeControl.setMute()` | `VolumeController` 写 `ValueNotifier<bool> isMuted` | ✓ 现有 | 直接设置，不触发音量联动 |
| 音量响应式读 | `MediaEngine.volume` / `MediaEngine.isMuted` | `ValueNotifier` 暴露 | ✓ 现有 | UI 用 `ValueListenableBuilder` 监听 |
| 音频 EQ / 滤镜链 | `MediaEngine.setEqualizer(String afFilter)` → `SubtitleConfig.setEqualizer()` | `_subtitleConfigurator.setEqualizer(afFilter)` → MDK `af` 属性 | ✓ 现有 | **单一入口**，FFmpeg `af` 语法 |
| 字幕延迟（参照） | `MediaEngine.setSubtitleDelay(int)` | `_subtitleConfigurator` | ✓ 现有 | 音频延迟走同一 `af` 链，见下 |

**关键发现：`setEqualizer` 命名误导**——它不只是 EQ。该方法是 MDK `af` 属性的通用入口，任何 FFmpeg 音频滤镜链都可经此注入。v4.5 音频 tab 的 EQ/平衡/同步/标准化全部复用此入口，零内核改动。

### 1.3 FFmpeg `af` 滤镜链语法（v4.5 音频 tab 功能填充依据）

MDK 的 `af` 属性直接透传 FFmpeg `avfilter` 图语法。滤镜链以逗号分隔顺序应用，空字符串 `''` 禁用（原始音频直通）。已在 `equalizer_tab.dart` L42-48 验证现有用法：

```dart
// 现有（equalizer_tab.dart）— 单/双段 EQ
''                              // 禁用
'bass=g=10'                     // 低频 +10dB
'treble=g=5'                    // 高频 +5dB
'bass=g=8,treble=g=6'           // 低+高
```

v4.5 音频 tab 四项功能的滤镜串方案：

| 功能 | FFmpeg 滤镜 | 示例 `af` 串 | 范围/约定 | 风险 |
|------|------------|--------------|----------|------|
| **EQ（多段）** | `bass` / `treble` / `equalizer` / `anequaler` | `bass=g=5,treble=g=3,equalizer=f=1000:w=h:g=2` | gain ±20dB，过高削波 | 低 — 现有 EQ tab 已验证热切换 |
| **平衡（声道增益）** | `pan` | `pan=stereo|c0=0.3*c0+0*c1|c1=0*c0+0.7*c1` | c0=左、c1=右；系数 0.0~1.0 控制各声道增益 | 中 — `pan` 语法繁琐，需 UI 抽象为 -1.0~+1.0 平衡滑块再生成串 |
| **同步（音频延迟）** | `adelay` | `adelay=1500|0`（左 1500ms / 右 0ms）或 `adelay=1500`（双声道） | 正=延后，负=提前（用 `adelay` + 负值需 `adelay=delays` 配合） | 中 — 与字幕延迟语义方向需对齐（字幕正=延后已确认） |
| **音量标准化** | `loudnorm`（EBU R128）或 `dynaudnorm`（动态） | `loudnorm=I=-16:LRA=11:TP=-1.5` 或 `dynaudnorm=f=150:g=15` | `loudnorm` 两段式（测量+应用），单次实时模式质量稍降；`dynaudnorm` 单段实时 | 高 — `loudnorm` 实时模式有启停爆音；建议默认 off，提供 toggle |

**推荐**：v4.5 音频 tab 用 `bass`+`treble`+`equalizer` 组合做 EQ（与现有 EQ tab 一致），`pan` 做平衡，`adelay` 做同步，`dynaudnorm` 做标准化（避开 `loudnorm` 两段式复杂度）。所有串以逗号拼接经 `setEqualizer` 提交。

### 1.4 桌面端限制

- **无原生音轨偏好 API**：MDK 不暴露"默认音轨语言"设置，自动选择由 demuxer 决定。v4.5 AudioTab 的"自动选择音轨"开关只能存偏好到 SharedPreferences，在 open() 后由 PlaybackController 应用（需新增钩子，但属服务层改动，非内核）。
- **af 滤镜热切换无回调**：MDK 重新初始化音频滤镜图是异步的，无完成事件。EQ 调整后短暂音频中断（~100ms）属正常，无需处理。
- **平衡/标准化滤镜不可逆查询**：MDK 不暴露当前 `af` 串回读。SettingsPanel 必须自己持有 pending 值（已有 `PendingSettingsState`），关闭/重开面板时由 Dart 侧重建 `af` 串。

---

## 2. Flutter Desktop UI Stack

### 2.1 横向 Tab 栏 — TabBar vs 自绘

| 方案 | 优点 | 缺点 | 判定 |
|------|------|------|------|
| **Material `TabBar` + `TabBarView`** | 内置 `TabController`、`IndexedStack` 懒加载、无障碍语义、键盘 ←→ 切换 | 默认下划线指示器与控制栏毛玻璃语言不符；indicator 需自定义 `Decoration`；两端箭头不内置 | △ 可用但需重写 indicator |
| **自绘横向 `ListView` + `GlassButton` 序列** | 完全对齐控制栏 `GlassButton` 三态；两端竖向圆角箭头自由放置；与 v4.0 `SettingsNavItem` 复用 hover/selected 动画 | 需自管 `selectedIndex` 状态（已有 `SettingsPanelState.selectedTab` ValueNotifier）；键盘 ←→ 需绑 `Focus` onKeyEvent | ✓ **推荐** |

**推荐理由**：v4.5 设计北极星是"面板视觉/交互全程对齐控制栏"。控制栏按钮已用 `GlassButton.iconOnly`（见 `right_button_group.dart`），横向 tab 栏复用同一组件家族可保证三态（normal/hover/selected）一致。Material `TabBar` 的 indicator 抽象会引入第二个视觉系统。

**实现要点**：
- 容器：`GlassContainer(GlassTier.normal)` + `Row` of `GlassButton.iconOnly`（7 个 tab，图标沿用 `_tabIcons` in `settings_overlay_shell.dart` L100-108）
- 两端竖向圆角左右箭头：`RotatedBox(quarterTurns: 1)` 包裹 `GlassButton`（← / →），持久可见，`onTap` 调 `controller.state.selectedTab` 的 prevTab/nextTab
- 选中态：`GlassButton` 已支持 selected 三态，沿用
- 键盘 ←→：`Focus(onKeyEvent)` 拦截 `LogicalKeyboardKey.arrowLeft/arrowRight`，调 `controller.prevTab()/nextTab()`（已有方法，见 `settings_panel_controller.dart` L72-79）

### 2.2 BackdropFilter 毛玻璃（桌面）

项目已验证桌面 BackdropFilter 模式，v4.5 直接复用：

- `GlassContainer`（`lib/ui/shared/glass_container.dart`）封装 `BackdropFilter(ImageFilter.blur)` + `bgGlass` + `borderHighlight`
- 三档 blur：`GlassTier.normal` / `GlassTier.strong` / `GlassTier.subtle`（控制栏用 normal）
- **窗口 resize 期间跳过**：`SettingsOverlayShell.resizing` ValueListenable 已实现（见 `settings_overlay_shell.dart` L37），防止 GPU readback 卡顿。v4.5 重构布局时保留此参数

**桌面特定注意**：Windows 上 `BackdropFilter` 走 D3D11 compute shader，性能可接受（项目 v2.0+ 全屏毛玻璃已验证 60fps）。但多层叠加（面板 + 控制栏 + OSD）会累积 GPU 开销，v4.5 面板内部避免重复 BackdropFilter——面板背景一层，选项卡片用纯色 `Tokens.bgElevated` 而非二级 BackdropFilter。

### 2.3 RepaintBoundary for 60fps

v4.0 Phase 27 已引入 `RepaintBoundary`（`Responsive Scaling` 阶段）。v4.5 重构时保留以下边界：

| 位置 | 原因 | 现状 |
|------|------|------|
| 面板根 `Stack` 外 | 隔离面板重绘与播放器纹理层 | ✓ v4.0 已有 |
| 每个 tab 内容外 | 切 tab 时隔离重建范围 | 需新增（横向布局 tab 切换更频繁） |
| 两端箭头按钮外 | hover 动画不污染选项列表 | 需新增 |
| 上下薄毛玻璃箭头 | 透看选项 + 滚动时不重绘 | 需新增（v4.5 新组件） |

### 2.4 FocusTraversalGroup（键盘/手柄导航）

v4.0 Phase 26 已用 `FocusTraversalGroup` + `SpinControl`（`lib/ui/dialogs/settings/` 内）。v4.5 横向布局需调整 traversal 顺序：

- **横向 tab 栏**：独立 `FocusTraversalGroup`，`WidgetOrderTraversalPolicy`，顺序为 左箭头 → tab 序列 → 右箭头
- **选项详情区**：独立 `FocusTraversalGroup`，`ReadingOrderTraversalPolicy`，上下箭头遍历 SettingRow
- **手柄 RB/LB**：不经 Focus 系统，直接绑到面板根 `Focus(onKeyEvent)`，调 `controller.nextTab()/prevTab()`
- **上下方向键发光反馈**：SettingRow 已有 hover 状态，键盘上下时通过 `FocusNode` 高亮模拟 hover（`widgets` 内已有模式）

---

## 3. ValueNotifier + 延迟应用模式

### 3.1 现有状态架构（v4.0 已交付，v4.5 复用）

| 组件 | 持有状态 | 文件 | v4.5 处置 |
|------|---------|------|-----------|
| `SettingsPanelState` | 恰 3 个 `ValueNotifier`：`isOpen` / `selectedTab` / `dragOffset` | `settings_panel_state.dart` | 保留，不改（PROJECT.md 确认） |
| `SettingsPanelController` | `open()/close()/toggle()` + `nextTab()/prevTab()` + `pending` 引用 + `_wasPlaying` 快照 | `settings_panel_controller.dart` | 改 `open()` 策略：总是暂停（非 wasPlaying 条件） |
| `PendingSettingsState` | `_pending` map + `_originals` map + `register/update/current/commit/cancel` | `pending_settings.dart` | 扩展：注册音频 tab 新键（eq/balance/delay/normalize） |

### 3.2 延迟应用（OK/Cancel/Apply）模式

已在 `_SettingsPanelState._ok/_cancel/_apply` 实现（`settings_panel.dart` L156-166）。v4.5 音频 tab 必须沿用此模式：

- **AudioTab 交互**：用户调 EQ 滑块 → `pending.update('eqBass', 5.0)`（不直接调 `engine.setEqualizer`）
- **OK**：`_commitChanges()` → 读 `pending.commit()` → 构造 `af` 串 → `engine.setEqualizer(afString)` → `Navigator.pop()`
- **Apply**：同 commit，但不 pop，`pending` 基准更新为已提交值
- **Cancel**：`pending.cancel()` → 回滚到 `_originals` → 重建 `af` 串 → `engine.setEqualizer(originalAfString)` 恢复

**新增需求**：`af` 串构造函数。建议在 AudioTab 内私有函数 `_buildAfString(PendingSettingsState pending) → String`，读 4 个键合成串。OK/Apply 时由 `_SettingsPanelState` 调用并经 `engine.setEqualizer` 提交。

### 3.3 实时预览 vs 延迟——设计决策

| 模式 | UX | 复杂度 | 判定 |
|------|----|--------|------|
| 全延迟（OK/Apply 才生效） | 用户调滑块无即时声音反馈，体验差 | 低 | △ |
| 全实时（滑块即 `engine.setEqualizer`） | 即时反馈好，但 Cancel 难恢复 | 中 | △ |
| **混合：滑块实时预览 + OK/Apply 才落盘偏好** | 即时反馈 + 偏好持久化分离 | 中 | ✓ **推荐** |

推荐：滑块 `onChanged` 直接 `engine.setEqualizer(_buildAfString(pending))` 预览，同时 `pending.update()` 记录值。Cancel 时从 `_originals` 重建串恢复。OK/Apply 时把 pending 值写 SharedPreferences（下次 open 注册为 originals）。此模式与现有 EQ tab（`equalizer_tab.dart` L91-94 实时调 `engine.setEqualizer`）一致。

---

## 4. Steam Input API — 手柄输入链路

### 4.1 自动映射机制（无需 Flutter 代码）

Steam Input API 把手柄输入转换为**合成键盘事件**注入焦点窗口：

| 手柄输入 | 默认键盘映射（Gamepad 模板） | 来源 |
|----------|------------------------------|------|
| D-pad ↑↓←→ | 方向键 | Steamworks `ISteamInput` 文档 |
| LB / RB | 可绑定任意键（默认 Q/E 或 Tab/Shift） | Steamworks controller config |
| A / B | Enter / ESC | 默认 |
| 左摇杆 | WASD 或方向键 | 默认 |
| Start / Guide | ESC / Tab | 默认 |

**关键事实**：Flutter 通过 `Focus(onKeyEvent)` 收到的 `KeyEvent` 无法区分物理来源是键盘还是手柄——Steam Input 在 OS 层合成键盘事件，Flutter `HardwareKeyboard` 不暴露设备源元数据。

### 4.2 输入模式检测方案（v4.5 新增基础设施）

| 方案 | 实现 | 准确性 | 复杂度 | 判定 |
|------|------|--------|--------|------|
| Steamworks SDK FFI 轮询 `ISteamInput` | C++ bridge 调 `ISteamInput::GetDigitalActionData` | 高 | 高（需 native + SDK 集成） | ✗ Out of scope（PROJECT.md 排除手柄适配层） |
| 鼠标移动 → 键盘模式 / 键盘事件 → 键盘模式 | `Listener` 监听 `PointerHoverEvent` 设 keyboard，`Focus.onKeyEvent` 设 gamepad（启发式：←→ 在 tab 切换 + 上下在选项 + 无鼠标移动 = gamepad） | 中（手柄用鼠标键盘混合时误判） | 低 | ✓ **v4.5 推荐** |
| 显式 toggle（设置面板"输入模式: 自动/键盘/手柄"） | 用户手选 | 100% | 极低 | ✓ 作为兜底/备选 |
| 不检测，提示同时显示 RB/LB + ←→ | UI 同时显示两套提示 | 100% 但丑 | 零 | ✗ 违反 PROJECT.md"提示置换"要求 |

**推荐**：v4.5 用启发式 + 显式 toggle 兜底。新增 `InputModeService`（kernel/services，ValueNotifier<InputMode> {keyboard, gamepad, auto}）：
- 默认 auto → 由启发式决定显示哪套提示
- `Listener` on `PointerMoveEvent` → 设 keyboard
- `Focus.onKeyEvent` 收到 ←/→/↑/↓/Tab/Q/E 且 5s 内无鼠标移动 → 设 gamepad
- 5s 无任何输入 → 保持当前模式（不重置）
- 设置面板提供 toggle 覆盖（持久化到 SharedPreferences）

提示置换组件：`InputModeHint(inputMode: gamepad, gamepadText: 'RB/LB', keyboardText: '← →')` 读 `InputModeService` 决定显示哪个文本。

### 4.3 桌面端手柄限制

- **Steam 必须运行**：Steam Input 仅在 Steam 客户端运行时启用。非 Steam 场景（直接运行 exe）手柄输入不会被映射——此场景下手柄事件到达 Windows 消息循环但不被 Flutter `Focus` 拦截（Flutter 只处理键盘事件）。v4.5 不解决此场景，文档应注明"手柄导航需通过 Steam 添加为非 Steam 游戏"。
- **xinput/directinput 手柄**：不经 Steam 的原生手柄不走 Flutter 键盘路径，需 `gamepadder` 或原生 `XInputGetCapabilities` FFI——v4.5 不做。
- **macOS/Linux 手柄**：Steam 行为一致，但本项目主平台 Windows，非 Windows 手柄支持推迟。

---

## 5. 现有 v3.0 内核接口供给清单（音频 tab 消费依据）

已读 `lib/kernel/engine/media_engine.dart` + 4 个能力接口确认：

```dart
abstract class MediaEngine
    implements
        EngineStateView,      // 只读状态（position/duration/volume/isMuted/...）
        PlaybackControl,       // 播放/暂停/seek
        TrackControl,          // getAudioTracks/switchAudioTrack/activeAudioTracks
        SubtitleConfig,        // setEqualizer/setSubtitleDelay/getSubtitleTracks/...
        VideoEffectControl,    // setVideoEffect/rotate/setAspectRatio/setDeinterlace
        RendererControl,       // 渲染器配置
        VolumeControl {}       // setVolume/setMute/volume/isMuted
```

| v4.5 功能 | 消费接口 | 消费方法 | 备注 |
|-----------|---------|---------|------|
| 音轨切换（控制栏按钮） | `TrackControl` | `getAudioTracks()` / `switchAudioTrack(int)` / `activeAudioTracks` | 控制栏弹轨列表 = AudioTab 内 `_AudioTrackRow` 逻辑复用 |
| 音轨列表（Audio tab） | `TrackControl` | 同上 | 与控制栏按钮共用组件 |
| 音量滑块（Audio tab 默认音量偏好） | `VolumeControl` | `setVolume(double)` + `volume` ValueNotifier | 偏好存 SharedPreferences，启动时 PlaybackController 应用 |
| EQ（Audio tab） | `SubtitleConfig` | `setEqualizer(String afFilter)` | 命名误导，实为通用 `af` 入口 |
| 平衡（Audio tab） | `SubtitleConfig` | `setEqualizer('pan=...')` | 复用同入口 |
| 同步/音频延迟（Audio tab） | `SubtitleConfig` | `setEqualizer('adelay=...')` | 复用同入口（与字幕延迟独立） |
| 音量标准化（Audio tab） | `SubtitleConfig` | `setEqualizer('dynaudnorm=...')` | 复用同入口 |
| 暂停/恢复（Auto-Pause Always） | `PlaybackControl`（经 `SettingsPanelPlayback` 边界） | `pause()` / `play()` | 现有 `_wasPlaying` 快照逻辑改为总是暂停 |

**零内核改动结论**：v4.5 所有音频功能经现有接口实现。Audio tab 新增的偏好持久化（默认音量、EQ 预设、平衡值等）走 `SettingsStore`（SharedPreferences），不经内核接口。

---

## Alternatives Considered

| 类别 | 推荐 | 替代 | 不选原因 |
|------|------|------|---------|
| 状态管理 | ValueNotifier + ValueListenableBuilder | Riverpod / Bloc / Provider | PROJECT.md 约束 + v2.1 已验证成熟，引入新框架增加复杂度 |
| 横向 tab 实现 | 自绘 `GlassButton` 序列 | Material `TabBar` | 视觉对齐控制栏北极星；`TabBar` indicator 引入第二视觉系统 |
| 音频滤镜入口 | 复用 `setEqualizer(afString)` | 新增 `setAudioFilter` 接口 | 内核零改动；`setEqualizer` 实为通用 `af` 入口，命名可后续重命名 |
| 输入模式检测 | 启发式 + 显式 toggle | Steamworks SDK FFI | PROJECT.md 排除手柄适配层；native 集成超 v4.5 范围 |
| 音量标准化滤镜 | `dynaudnorm`（实时单段） | `loudnorm`（EBU R128 两段式） | `loudnorm` 实时模式有启停爆音；`dynaudnorm` 单段实时，UX 更平滑 |
| 平衡实现 | `pan` 滤镜 | `volume` + `channelmap` | `pan` 直接控制各声道增益系数，语义最贴近"平衡"滑块 |

---

## Installation

**无新增依赖**。v4.5 全部基于现有 pubspec 依赖：

```yaml
# 现有（pubspec.yaml 节选，无需修改）
dependencies:
  fvp: ^0.37.2                  # MDK/FFmpeg 引擎
  flutter_localizations: {sdk: flutter}
  shared_preferences: ^2.5.5     # 偏好持久化（音频 tab 偏好）
  # ...其余依赖不变
```

如未来需 Steamworks SDK 原生手柄轮询（v4.6+ 评估），需新增：
- `windows/runner/steam_api.dll`（Steamworks SDK 二进制）
- `ffi` binding（项目已有 `ffi: ^2.1.0` 依赖）
- 新增 `lib/kernel/bridge/steam_input_bridge.dart`（参照 `window_bridge.dart` 模式）

v4.5 不做此集成。

---

## Sources

- Live code（D:\simple_player_flutter）:
  - `lib/kernel/engine/media_engine.dart` — MediaEngine 组合接口（7 implements）
  - `lib/kernel/engine/track_control.dart` — TrackControl 契约
  - `lib/kernel/engine/volume_control.dart` — VolumeControl 契约 + ValueNotifier 暴露
  - `lib/kernel/engine/subtitle_config.dart` — SubtitleConfig（含 setEqualizer）契约
  - `lib/kernel/engine/engine_state_view.dart` — 只读状态视图
  - `lib/kernel/engine/track_manager.dart` — TrackControl 实现（MDK activeAudioTracks）
  - `lib/kernel/engine/fvp_engine.dart` — FvpEngine 实现（setEqualizer L908）
  - `lib/ui/dialogs/settings_panel.dart` — 旧左侧栏面板（v4.5 重构对象，含 OK/Cancel/Apply 模式）
  - `lib/ui/dialogs/settings/settings_overlay_shell.dart` — v4.0 覆盖层壳
  - `lib/ui/dialogs/settings/settings_panel_state.dart` — 3 ValueNotifier 状态容器
  - `lib/ui/dialogs/settings/settings_panel_controller.dart` — open/close + wasPlaying 暂停逻辑
  - `lib/ui/dialogs/settings/pending_settings.dart` — 延迟应用容器
  - `lib/ui/dialogs/settings/tabs/audio_tab.dart` — v4.0 骨架占位（v4.5 填充）
  - `lib/ui/dialogs/settings/equalizer_tab.dart` — 现有 EQ 实现（`af` 串用法验证）
  - `lib/ui/dialogs/settings/audio_tab.dart`（顶层）— 旧版音轨选择（控制栏按钮复用其 `_AudioTrackRow` 模式）
  - `lib/ui/player/right_button_group.dart` — 控制栏按钮模式（GlassButton.iconOnly）
  - `lib/ui/player/control_bar.dart` — 控制栏毛玻璃装饰（设计北极星参考）
- `.planning/PROJECT.md` — v4.5 6 目标功能 + 约束 + 决策表
- `pubspec.yaml` — 依赖版本锁定
- Context7 `/wang-bin/fvp` — fvp 平台/渲染 API 能力（confidence: MEDIUM，未直接覆盖音频滤镜细节）
- [Steamworks Controller Documentation](https://partner.steamgames.com/doc/features/controller) — Steam Input 自动映射机制（confidence: HIGH）
- [ISteamInput API](https://partner.steamgames.com/doc/sdk/api/ISteamInput) — 原生手柄轮询接口（confidence: HIGH，v4.5 不集成）
- FFmpeg `avfilter` 文档（`bass`/`treble`/`equalizer`/`pan`/`adelay`/`dynaudnorm`/`loudnorm`）— 滤镜语法（confidence: HIGH，已在 equalizer_tab.dart 验证 `bass`/`treble` 子集）
