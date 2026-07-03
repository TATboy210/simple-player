# Phase 18: Visual Tuning & Validation - Context

**Gathered:** 2026-07-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 17 完成了 AnimatedContainer 过渡动画。Phase 18 聚焦视觉参数的审计、修正和验证：确保所有 token alpha 值在实际视频内容上可见且合理，合并无意义的 blur 区分，编写自动化验证测试。

**成功标准（来自 ROADMAP.md）：**
1. 控制栏外观在 dark/bright/mixed/colorful/letterbox 视频内容上验证通过
2. Idle 边框在所有测试场景中保持可见（alpha >= 15%）
3. glassBlur vs glassBlurThick 区分基于视觉证据确认或合并
4. 无视觉回归：playing 状态外观与 v1.3 baseline 一致

</domain>

<decisions>
## Implementation Decisions

### Token Alpha 审计发现

- **D-01:** controlBarBorderIdle (0x05FFFFFF, alpha=2.0%) — 不可见，需要提升到 >= 15%
- **D-02:** controlBarBorderWhite (0x0AFFFFFF, alpha=3.9%) — 播放状态边框应该比 idle 更明显，当前反转
- **D-03:** glassBorderIdle (0x276482FF, alpha=15.3%) — 唯一通过 SC-2 的边框 token，作为参考基准
- **D-04:** controlBarGradientEdge (0x005082FF, alpha=0%) — 完全透明的死 token，需删除或赋予有意义的 alpha
- **D-05:** glassBlur (10.0) vs glassBlurThick (12.0) — 2px 差异在 BackdropFilter 中不可感知，建议合并为 glassBlur=10.0

### 边框可见性逻辑修正

- **D-06:** Playing 状态边框 alpha 应 > Idle 状态边框 alpha（当前是反转的）
- **D-07:** 所有 border token 的 alpha 应 >= 10%（最低可见阈值），idle 目标 >= 15%

</decisions>

<canonical_refs>
## Canonical References

### 设计系统
- `lib/ui/theme/tokens.dart` — 所有 token 定义，需修正 alpha 值
- `lib/ui/player/control_bar.dart` — 使用 glassBlurThick 的 _blurFilter

### 需求
- `.planning/REQUIREMENTS.md` — UI-06 需求定义

</canonical_refs>
