# Requirements: Simple Player — 设置面板横向重构 + 音频功能填充 v4.5

**Defined:** 2026-07-25
**Supersedes:** v3.0 REQUIREMENTS.md（v3.0 已验证能力见 `PROJECT.md` Validated 节；v3.0 内核能力 BASE/ADAPT/LOG/ERR/MEM/STATE/VERIFY/DOC 全部 Complete，v4.5 不再重复）
**Core Value:** 设置面板的产品级体验 — 横向 tab 布局 + 控制栏级视觉/交互一致性 + 输入模式感知导航（键鼠/手柄自适应）、音频功能可用、延迟应用保护设置安全。

> **需求表述约定：** 本里程碑为 UI/UX 体验升级，需求按**用户可见行为/可验证 UI 状态**表述，每条原子、可测、独立。REQ-ID 类别对齐 `research/SUMMARY.md` 的 7 阶段（Phase 28-34）构建顺序。Traceability 按 SUMMARY 推荐 phase 顺序预填，由 roadmapper 在 Step 10 复核确认。研究揭示的 research-flag gap（MDK `af` 可用性 / Steam Input 事件签名 / 字幕按钮 primitive / legacy callers grep）不进 REQ，在各 Phase 规划时研究。3 项 PRODUCT 决策已固化：① 前置重构纳入 v4.5（REFAC-01/02）② 音频 EQ 纯延迟应用（AUDIO-06）③ 面板 16:9 主约束 + 50% 面积次约束（LAYOUT-02）。

## v1 Requirements

### REFAC — 重构前置（Phase 28）

- [ ] **REFAC-01**: 拆分 `settings_overlay_shell.dart`（517 行，接近 500 上限）为 `tab_strip.dart` + `tab_content.dart` + `panel_key_bindings.dart` 三个子文件，零行为变更，全测试套件绿
- [ ] **REFAC-02**: 删除 legacy `settings_panel.dart`（88px sidebar，非 PROJECT.md 误记的 200px），`grep -r "SettingsPanel(" lib/ test/` 验证零生产调用，相关测试迁移至 `settings/` 框架

### PAUSE — 自动暂停（总是）（Phase 29）

- [x] **PAUSE-01**: 面板开启即暂停（总是，非 `wasPlaying` 条件）— `open()` 无条件调 `pause()`
- [x] **PAUSE-02**: `bool _wasPlaying` 拓宽为 `MediaState _preOpenState` 快照（覆盖 loading/buffering/ended/manual-pause 四子竞态）
- [x] **PAUSE-03**: `close()` 仅当 `_preOpenState == MediaState.playing` 才恢复播放；loading/buffering/ended/manual-pause 显式 NO-RESUME
- [x] **PAUSE-04**: Widget 测试覆盖四子竞态 — load→loading→open→close→断言 `play()` 未调用；EOF→open→close→断言；manual-pause→open→close→断言未恢复

### LAYOUT — 面板布局重构（Phase 30）

- [ ] **LAYOUT-01**: 面板比例从 5:4（clamp 400-600）改为 16:9 / 占屏约 50% 面积
- [ ] **LAYOUT-02**: 面板尺寸公式 `width = min(0.5 × screenW, screenH × 16/9)`，clamp `[400, 960]`；**16:9 为主约束，50% 面积为次约束**（PRODUCT 决策固化）
- [ ] **LAYOUT-03**: 通用 tab（General）从当前位置移到 tab 序列中间位置
- [ ] **LAYOUT-04**: 多显示器拖拽钳制（`display_enumerator` work-area，非 `MediaQuery`）
- [ ] **LAYOUT-05**: 面板上中下垂直结构颜色统一为控制栏色（与 VISUAL-01 协同）

### VISUAL — 视觉设计对齐（Phase 31）

- [ ] **VISUAL-01**: 面板 chrome 对齐控制栏 — `bgGlass` → `controlBarBg` + `controlBarBorderWhite` + `glowOuterRing`（4-shadow decoration 来自 `ControlBar._decorationPlaying`）
- [ ] **VISUAL-02**: 选项行默认无边框无白光融合于面板，仅选中态高亮（控制栏按钮三态：default/hover/selected）
- [ ] **VISUAL-03**: 选项边界更紧凑（减小 padding/margin，与控制栏按钮密度对齐）
- [ ] **VISUAL-04**: 薄毛玻璃"透看选项"效果用 `Tokens.bgGlass` 色实现（非第二层 `BackdropFilter`，避免 GPU readback 堆叠）
- [ ] **VISUAL-05**: 提取 `PanelDecoration`/`ControlBarDecoration` 共享 token，颜色统一单路由

### NAV — 导航与交互打磨（Phase 32）

- [ ] **NAV-01**: tab 两端竖向圆角左右箭头按钮（持久可见 + 可点 + 键盘左右切 tab）
- [ ] **NAV-02**: `InputModeDetector` singleton `ValueNotifier<InputMode>{keyboard, gamepad, auto}`（heuristic + toggle 兜底，非 Steamworks SDK FFI）— v4.5 唯一新基础设施
- [ ] **NAV-03**: 提示置换 — 手柄模式 RB/LB 渐入 / 方向键渐退；键盘模式反向（`AnimatedSwitcher` 渐入渐出）
- [ ] **NAV-04**: 删除 raw `gameButtonLeft1`/`gameButtonRight1` 绑定（防 Steam Input LB/RB → ←/→ double-fire）
- [ ] **NAV-05**: 上下薄毛玻璃盖在选项上下端（透看选项，`Container(color: Tokens.bgGlass)` 非第二层 blur）
- [ ] **NAV-06**: 键盘上下时上下箭头发光反馈
- [ ] **NAV-07**: 单一 `Focus(onKeyEvent: _handleKeyEvent)` 根捕获所有方向键，返回 `handled`，防 ←/→ 逃逸到 `KeyboardHandler` seek ±5s

### AUDIO — 音频设置 tab（Phase 33）

- [ ] **AUDIO-01**: EQ 预设（`bass`/`treble`/`equalizer` af 滤镜，复用 `MediaEngine.setEqualizer(String afFilter)` 通用 af 入口，零内核改动）
- [ ] **AUDIO-02**: 平衡滑块（`pan` 滤镜，UI 抽象 -1.0..+1.0 → 滤镜字符串）
- [ ] **AUDIO-03**: 音频同步滑块（`adelay` 滤镜，方向对齐字幕延迟 UX）
- [ ] **AUDIO-04**: 音量标准化开关（`dynaudnorm` 滤镜，默认关）
- [ ] **AUDIO-05**: `_buildAfString(PendingSettingsState) → String` 私有组合器，将 EQ/平衡/同步/标准化合成为单一 `af` 链
- [ ] **AUDIO-06**: **纯延迟应用** — 拖动滑块只更新 `PendingSettingsState`，OK/Apply 才调 `engine.setEqualizer()`；Cancel 天然回滚（pending 丢弃，零引擎状态快照管理）（PRODUCT 决策固化）
- [ ] **AUDIO-07**: `SettingsStore`（SharedPreferences）持久化 EQ 预设/平衡/同步/标准化偏好（OK/Apply 时提交）

### CTRLBAR — 控制栏音轨切换（Phase 34）

- [ ] **CTRLBAR-01**: 控制栏右下区（字幕左 / 打开文件右）新增音轨切换按钮 `GlassButton.iconOnly(Icons.headphones)`
- [ ] **CTRLBAR-02**: 点击弹轨列表（`OverlayEntry` + `ListView.builder`，对称字幕按钮 pattern）
- [ ] **CTRLBAR-03**: `CompositedTransformTarget` + `CompositedTransformFollower` 使弹层跟随按钮窗口移动/resize
- [ ] **CTRLBAR-04**: 仅当 `getAudioTracks().length > 1` 时显示按钮（单轨隐藏）
- [ ] **CTRLBAR-05**: 提取 `TrackPopupMenu` 共享 widget（字幕按钮复用，对称性 + DRY）

## Future Requirements

> 研究标注的 differentiators，推迟至 v4.6+（触发条件见 `research/SUMMARY.md`）。

- **VISUAL-F01**: 视频调节 tab 功能填充（色彩校正、渲染参数）— v4.5 保持 SettingRow 占位
- **VISUAL-F02**: 字幕调节 tab 功能填充（字体、延迟、样式）— v4.5 保持占位
- **PLAY-F01**: 播放偏好 tab 功能填充（默认音轨、播放模式默认值）— v4.5 保持占位
- **AUDIO-F01**: `AudioConfig` ISP 接口（独立于 `SubtitleConfig`，提升音频 tab 内聚）— Stack 研究建议 defer 避免 v3.0 内核基线扰动
- **AUDIO-F02**: 10-band 图形 EQ（v4.5 预设列表 EQ 已足够）
- **AUDIO-F03**: 音频设备 / 输出模块选择器
- **AUDIO-F04**: 默认音频语言偏好接线
- **NAV-F01**: Steamworks SDK FFI 原生手柄轮询（替代 heuristic + toggle，精确输入模式检测）
- **AUDIO-F05**: 实时 EQ 预览 + 控制器快照恢复（若 v4.5 纯延迟应用后用户反馈需要实时听感）

## Out of Scope

| Feature | Reason |
|---------|--------|
| 导入导出设置 | 非核心功能，推迟到 v4.2+ |
| 独立窗口模式 | 当前使用覆盖层架构（居中 Stack sibling，非 `showDialog`） |
| 手柄输入适配层 | Steam Input API 自动映射手柄→键盘，无需 Flutter 侧适配层（PROJECT.md 约束） |
| 内核改动 | v3.0 已完成，v4.5 仅对接现有 `TrackControl`/`VolumeControl`/`SubtitleConfig` 接口 |
| 实时 EQ 预览（无回滚） | 决策定纯延迟应用（AUDIO-06）；实时预览 deferred 到 v4.6+（AUDIO-F05）若用户反馈需要 |
| AudioConfig ISP 重构 | Architecture 研究推荐但 Stack 建议 defer；共识 defer v4.6+ 避免 v3.0 内核基线扰动（AUDIO-F01） |
| Steamworks SDK FFI | PROJECT.md 约束：手柄输入适配层排除；v4.5 用 heuristic + toggle 兜底（NAV-F01 deferred） |

## Traceability

按 `research/SUMMARY.md` 推荐阶段顺序预填；roadmapper 在 Step 10 复核确认。

| Requirement | Phase | Status |
|-------------|-------|--------|
| REFAC-01 | Phase 28 | Pending |
| REFAC-02 | Phase 28 | Pending |
| PAUSE-01 | Phase 29 | Complete |
| PAUSE-02 | Phase 29 | Complete |
| PAUSE-03 | Phase 29 | Complete |
| PAUSE-04 | Phase 29 | Complete |
| LAYOUT-01 | Phase 30 | Pending |
| LAYOUT-02 | Phase 30 | Pending |
| LAYOUT-03 | Phase 30 | Pending |
| LAYOUT-04 | Phase 30 | Pending |
| LAYOUT-05 | Phase 30 | Pending |
| VISUAL-01 | Phase 31 | Satisfied |
| VISUAL-02 | Phase 31 | Satisfied (by-design exempt) |
| VISUAL-03 | Phase 31 | Satisfied |
| VISUAL-04 | Phase 31 | Satisfied (code; human_review pending) |
| VISUAL-05 | Phase 31 | Satisfied (code; human_review pending) |
| NAV-01 | Phase 32 | Pending |
| NAV-02 | Phase 32 | Pending |
| NAV-03 | Phase 32 | Pending |
| NAV-04 | Phase 32 | Pending |
| NAV-05 | Phase 32 | Pending |
| NAV-06 | Phase 32 | Pending |
| NAV-07 | Phase 32 | Pending |
| AUDIO-01 | Phase 33 | Pending |
| AUDIO-02 | Phase 33 | Pending |
| AUDIO-03 | Phase 33 | Pending |
| AUDIO-04 | Phase 33 | Pending |
| AUDIO-05 | Phase 33 | Pending |
| AUDIO-06 | Phase 33 | Pending |
| AUDIO-07 | Phase 33 | Pending |
| CTRLBAR-01 | Phase 34 | Pending |
| CTRLBAR-02 | Phase 34 | Pending |
| CTRLBAR-03 | Phase 34 | Pending |
| CTRLBAR-04 | Phase 34 | Pending |
| CTRLBAR-05 | Phase 34 | Pending |

**Coverage:**
- v1 requirements: 35 total
- Mapped to phases: 35
- Unmapped: 0 ✓

**Phase distribution:**
- Phase 28 (REFAC 重构前置): 2
- Phase 29 (PAUSE 自动暂停): 4
- Phase 30 (LAYOUT 面板布局): 5
- Phase 31 (VISUAL 视觉对齐): 5
- Phase 32 (NAV 导航打磨): 7
- Phase 33 (AUDIO 音频 tab): 7
- Phase 34 (CTRLBAR 控制栏音轨): 5

---
*Requirements defined: 2026-07-25*
*Last updated: 2026-07-25 after Step 9 定义 + 3 PRODUCT 决策固化（REFAC 纳入 / AUDIO 纯延迟 / LAYOUT 16:9 主约束）*
