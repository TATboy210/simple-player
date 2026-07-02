# Requirements — v1.3 控制栏视觉协调与玻璃质感优化

**Milestone:** v1.3
**Goal:** 控制栏颜色/亮度与背景融合，减少视觉突兀感
**Created:** 2026-07-02

## v1 Requirements

### Token Foundation

- [ ] **UI-01**: 添加 6 个空状态 Tokens 到 tokens.dart
  - controlBarBgIdle: 空状态控制栏背景色
  - controlBarBorderIdle: 空状态控制栏边框色
  - glassBorderIdle: 空状态玻璃边框色
  - controlBarTextPrimaryIdle: 空状态主文本色
  - controlBarTextSecondaryIdle: 空状态次文本色
  - controlBarIconIdle: 空状态图标色
  - 所有值为 compile-time const

### Control Bar Adaptation

- [ ] **UI-02**: GlassContainer 添加可选 backgroundColor 参数
  - 类型: Color?，默认值 Tokens.bgGlass
  - 向后兼容，现有调用者无需修改
  - 用于空状态时传入更淡的背景色

- [ ] **UI-03**: ControlBar 状态感知 _buildDecoration 方法
  - 替换 static final _decoration 为 _buildDecoration(isIdle) 方法
  - 使用现有 isIdle boolean (来自 engine.state)
  - 空状态: 使用 UI-01 的 idle tokens
  - 播放状态: 保持现有 tokens 不变

### Polish

- [ ] **UI-04**: EdgeGlow 可选 glowIntensity 参数
  - 类型: double?，默认值 null (保持现有行为)
  - 空状态时传入较低值减弱发光
  - 避免与 AuroraBackground 竞争视觉焦点

- [ ] **UI-05**: textSecondary WCAG AA 对比度修复
  - 当前 alpha 45% (0x73FFFFFF) → 对比度 4.30:1
  - 修改为 50% (0x80FFFFFF) → 对比度 ~5.3:1
  - 满足 WCAG SC 1.4.3 (4.5:1 最低要求)

- [ ] **UI-06**: 视觉调优 — alpha/sigma 具体值迭代
  - 测试 5+ 视频类型: dark, bright, mixed, colorful, letterbox
  - 确认 glassBlur vs glassBlurThick 是否需要区分 (当前都是 18.0)
  - 验证空状态边框可见性 (alpha >= 15%)

## Future Requirements

- 渐变过渡带 (控制栏上方透明→黑色渐变) — defer to v1.4
- 自适应渐变强度 (基于视频帧颜色) — defer to v2+
- 控制栏背景色从视频主色提取 — defer to v2+

## Out of Scope

- palette_generator / flutter_color_extractor — 过度工程
- dynamic_color (Material You) — 不适合媒体播放器
- FragmentShader — Impeller 迁移中，避免使用

## Traceability

| REQ | Phase | Status |
|-----|-------|--------|
| UI-01 | Phase 16 | Pending |
| UI-02 | Phase 17 | Pending |
| UI-03 | Phase 17 | Pending |
| UI-04 | Phase 16 | Pending |
| UI-05 | Phase 16 | Pending |
| UI-06 | Phase 18 | Pending |

---
*Created: 2026-07-02 via /gsd-new-milestone*
*Traceability updated: 2026-07-02 via roadmap creation*
