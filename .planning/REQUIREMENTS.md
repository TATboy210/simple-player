# Requirements — v1.3 控制栏视觉协调与玻璃质感优化

**Milestone:** v1.3
**Goal:** 控制栏颜色/亮度与背景融合，减少视觉突兀感
**Created:** 2026-07-02

## v1 Requirements

### Token Foundation

- [x] **UI-01**: 添加 6 个空状态 Tokens 到 tokens.dart
  - controlBarBgIdle: 空状态控制栏背景色
  - controlBarBorderIdle: 空状态控制栏边框色
  - glassBorderIdle: 空状态玻璃边框色
  - controlBarTextPrimaryIdle: 空状态主文本色
  - controlBarTextSecondaryIdle: 空状态次文本色
  - controlBarIconIdle: 空状态图标色
  - 所有值为 compile-time const

### Control Bar Adaptation

- [x] **UI-02**: GlassContainer 添加可选 backgroundColor 参数
  - 类型: Color?，默认值 Tokens.bgGlass
  - 向后兼容，现有调用者无需修改
  - 用于空状态时传入更淡的背景色

- [x] **UI-03**: ControlBar 状态感知 decoration（AnimatedContainer + getter）
  - _decorationIdle / _decorationPlaying 已改为 getter（非 static final）
  - AnimatedContainer 自动对 color + border 做隐式插值（150ms easeInOut）
  - 空状态: 使用 UI-01 的 idle tokens
  - 播放状态: 保持现有 tokens 不变

### Polish

- [x] **UI-04**: EdgeGlow 可选 glowIntensity 参数
  - 类型: double?，默认值 null (保持现有行为)
  - 空状态时传入较低值减弱发光
  - 避免与 AuroraBackground 竞争视觉焦点

- [x] **UI-05**: textSecondary WCAG AA 对比度修复
  - 当前 alpha 45% (0x73FFFFFF) → 对比度 4.30:1
  - 修改为 50% (0x80FFFFFF) → 对比度 ~5.3:1
  - 满足 WCAG SC 1.4.3 (4.5:1 最低要求)

- [x] **UI-06**: 视觉调优 — alpha/sigma 具体值迭代
  - Token alpha 审计：修复可见性反转（playing border 3.9%→10.2%, idle border 2.0%→5.2%）
  - glassBlur vs glassBlurThick 合并为 2-tier（10 vs 12px 不可感知）
  - 删除死 token controlBarGradientEdge（alpha=0）
  - 自动化验证测试：5 个 token alpha 范围检查
  - 视觉验证清单待用户手动执行

## Future Requirements

- 渐变过渡带 (控制栏上方透明→黑色渐变) — defer to v1.4
- 自适应渐变强度 (基于视频帧颜色) — defer to v2+
- 控制栏背景色从视频主色提取 — defer to v2+

## Out of Scope

- palette_generator / flutter_color_extractor — 过度工程
- dynamic_color (Material You) — 不适合媒体播放器
- FragmentShader — Impeller 迁移中，避免使用

## v1.4 Requirements

### Technical Debt

- [ ] **TECH-01**: 修复 PlayerServices.create() undefined method 错误
  - 添加静态 `create()` 工厂方法到 PlayerServices
  - PlayerViewModel.init() 调用点无需修改

- [ ] **TECH-02**: 迁移弃用 Color API (18 issues)
  - `color.value` → `color.toARGB32()`
  - `color.alpha` → `(color.a * 255).round()`
  - `color.red/green/blue` → `(color.r/g/b * 255).round()`
  - 涉及 tokens.dart, contrast_test.dart, tokens_test.dart

- [ ] **TECH-03**: 修复 external subtitle 测试失败 (6 tests)
  - 添加 path_provider mock 到测试环境
  - 修复 PlaylistStore.dispose() 的 MissingPluginException

- [ ] **TECH-04**: 代码质量清理 (100 info issues)
  - 添加 @override 注解 (31 issues)
  - 修复 overridden_fields (24 issues)
  - 删除 unnecessary_import (12 issues)
  - 补全 const 构造函数 (4 issues)
  - 修复其他 lint issues (29 issues)

## Traceability

| REQ | Phase | Status |
|-----|-------|--------|
| UI-01 | Phase 16 | Complete |
| UI-02 | Phase 17 | Complete |
| UI-03 | Phase 17 | Complete |
| UI-04 | Phase 16 | Complete |
| UI-05 | Phase 16 | Complete |
| UI-06 | Phase 18 | Complete |
| TECH-01 | Phase 20 | Pending |
| TECH-02 | Phase 20 | Pending |
| TECH-03 | Phase 20 | Pending |
| TECH-04 | Phase 20 | Pending |

---
*Created: 2026-07-02 via /gsd-new-milestone*
*Traceability updated: 2026-07-02 via roadmap creation*

---

# Requirements — v1.5 代码注释补全

**Milestone:** v1.5
**Goal:** 为所有重要组件、程序和代码添加/完善注释，提升代码可读性和可维护性
**Created:** 2026-07-04

**审计结果:** 135 个 .dart 文件中 ~115 个已有良好注释，~20 个需要针对性改进

## v1 Requirements

### Kernel Engine 层

- [ ] **DOC-01**: `d3d11_configurator.dart` — D3D11 参数含义、sync.cpu 作用、为什么需要这些配置
- [ ] **DOC-02**: `subtitle_configurator.dart` — 字幕延迟参数、文件格式检测逻辑
- [ ] **DOC-03**: `volume_controller.dart` — 音量曲线、对数/线性映射选择原因
- [ ] **DOC-04**: `track_manager.dart` — 音轨/字幕轨管理策略、选择算法
- [ ] **DOC-05**: `fvp_callback_handler.dart` — 回调事件类型、状态转换时机
- [ ] **DOC-06**: `video_effect_controller.dart` — 视频特效参数、MDK effect API 说明
- [ ] **DOC-07**: `engine_prewarm.dart` — 预热策略、超时设置、为什么需要预热
- [ ] **DOC-08**: `network_configurator.dart` — 网络缓冲参数、协议配置
- [ ] **DOC-09**: `renderer_config.dart` — 渲染器参数、D3D11 vs OpenGL 选择
- [ ] **DOC-10**: `track_control.dart` — 音轨/字幕轨控制接口
- [ ] **DOC-11**: `video_effects.dart` — 视频特效枚举和参数
- [ ] **DOC-12**: `open_result.dart` — 打开结果数据结构

### Kernel Bridge 层

- [ ] **DOC-13**: `display_config.dart` — 显示器配置参数、多显示器逻辑
- [ ] **DOC-14**: `window_persistence.dart` — 窗口状态持久化策略
- [ ] **DOC-15**: `display_enumerator.dart` — 显示器枚举接口
- [ ] **DOC-16**: `win32_display_enumerator.dart` — Win32 EnumDisplayMonitors 回调逻辑

### Kernel Models & Utils

- [ ] **DOC-17**: `aspect_ratio_mode.dart` — 宽高比模式枚举含义
- [ ] **DOC-18**: `validation_error.dart` — 验证错误类型和处理策略
- [ ] **DOC-19**: `app_settings.dart` — 设置项默认值和约束
- [ ] **DOC-20**: `player_error.dart` — 错误类型分类和恢复策略
- [ ] **DOC-21**: `perf_monitor.dart` — 性能指标含义、阈值设置
- [ ] **DOC-22**: `debug_probe.dart` — 调试探针工作原理
- [ ] **DOC-23**: `memory_monitor.dart` — 内存监控策略、告警阈值
- [ ] **DOC-24**: `debug_exporter.dart` — 调试导出格式和用途
- [ ] **DOC-25**: `screen_utils.dart` — 屏幕工具函数、DPI 处理

### Kernel Services & Others

- [ ] **DOC-26**: `global_hotkey_service.dart` — 全局热键注册机制、平台差异
- [ ] **DOC-27**: `locale_service.dart` — 国际化服务、语言回退策略
- [ ] **DOC-28**: `thumbnail_service.dart` — 缩略图生成策略、LRU 缓存
- [ ] **DOC-29**: `startup_coordinator.dart` — 启动协调器、依赖顺序
- [ ] **DOC-30**: `startup_state.dart` — 启动状态机、状态转换
- [ ] **DOC-31**: `folder_scanner.dart` — 文件夹扫描策略、过滤规则
- [ ] **DOC-32**: `settings_validator.dart` — 设置验证规则

### UI Dialogs 层

- [ ] **DOC-33**: `equalizer_tab.dart` — FFmpeg 滤镜语法解释、预设值含义
- [ ] **DOC-34**: `audio_tab.dart` — 音频设置参数说明
- [ ] **DOC-35**: `video_tab.dart` — 视频设置参数说明
- [ ] **DOC-36**: `settings_tab_performance.dart` — 性能设置参数说明
- [ ] **DOC-37**: `media_info_dialog.dart` — 媒体信息字段含义

### UI Player 层

- [ ] **DOC-38**: `drop_handler.dart` — 拖放处理逻辑、文件类型过滤
- [ ] **DOC-39**: `player_actions.dart` — 播放器动作定义和分发
- [ ] **DOC-40**: `error_banner.dart` — 错误横幅显示策略
- [ ] **DOC-41**: `time_range_display.dart` — 时间范围显示逻辑

### UI Shared 层

- [ ] **DOC-42**: `app_dialog.dart` — 对话框基类、通用模式
- [ ] **DOC-43**: `context_menu_row.dart` — 右键菜单行组件
- [ ] **DOC-44**: `merged_listenable.dart` — 多 ValueNotifier 合并原理
- [ ] **DOC-45**: `splash_screen.dart` — 启动画面逻辑、动画

### Features 层

- [ ] **DOC-46**: `deferred_player_feature.dart` — 延迟加载特性模式
- [ ] **DOC-47**: `state_monitor.dart` — 状态监控服务
- [ ] **DOC-48**: `auto_advance_policy.dart` — 自动跳转策略
- [ ] **DOC-49**: `player_error_bus.dart` — 错误总线模式
- [ ] **DOC-50**: `playback_contract.dart` — 播放契约接口

## Out of Scope

| Feature | Reason |
|---------|--------|
| 已有良好注释的文件（~115个） | 审计显示已达标，无需改动 |
| test/ 目录 | 测试文件注释优先级低，不在本里程碑范围 |
| barrel export 文件 | 仅一行导出，无需额外注释 |
| 重构代码逻辑 | 本里程碑只添加注释，不改变行为 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| DOC-01 ~ DOC-12 | Phase 1: Kernel Engine | Pending |
| DOC-13 ~ DOC-16 | Phase 1: Kernel Bridge | Pending |
| DOC-17 ~ DOC-32 | Phase 2: Kernel Models/Utils/Services | Pending |
| DOC-33 ~ DOC-45 | Phase 3: UI Layer | Pending |
| DOC-46 ~ DOC-50 | Phase 4: Features & Verification | Pending |

**Coverage:**
- v1 requirements: 50 total
- Mapped to phases: 50
- Unmapped: 0 ✓

---
*Requirements defined: 2026-07-04*
*Last updated: 2026-07-04 after initialization*
