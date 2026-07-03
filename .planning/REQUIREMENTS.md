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
