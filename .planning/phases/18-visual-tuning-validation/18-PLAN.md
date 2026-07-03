# Phase 18: Visual Tuning & Validation — PLAN

> **Goal:** 修正 token alpha 值的可见性问题，合并无意义的 blur 区分，编写自动化验证测试。
>
> **Requirements:** UI-06
>
> **Decisions:** D-01~D-07 (see 18-CONTEXT.md)

---

## Task 01: 修正 border token alpha 值

**Why:** 当前边框 token 存在"可见性反转"——idle 边框 (15.3%) 比 playing 边框 (3.9%/12.2%) 更明显，逻辑反了。且多个边框 alpha < 10%，在视频上几乎不可见。

**File:** `lib/ui/theme/tokens.dart`

**Changes:**

| Token | 当前值 | 当前 alpha | 新值 | 新 alpha | 理由 |
|-------|--------|-----------|------|---------|------|
| controlBarBorderWhite | 0x0AFFFFFF | 3.9% | 0x1AFFFFFF | 10.2% | 播放状态边框应明显 |
| controlBarBorderIdle | 0x05FFFFFF | 2.0% | 0x0DFFFFFF | 5.2% | idle 白色边框比 playing 淡 |
| glassBorder | 0x146482FF | 7.8% | 0x1A6482FF | 10.2% | 最低可见阈值 |

**保持不变：**
- glassBorderIdle (0x276482FF, 15.3%) — 已达标，不动

**逻辑约束验证：**
- Playing: controlBarBorderWhite (10.2%) > Idle: controlBarBorderIdle (5.2%) ✅
- Idle 蓝色描边: glassBorderIdle (15.3%) >= 15% ✅ (SC-2)

**删除死 token:**
- controlBarGradientEdge (0x005082FF) — alpha=0 完全透明

**Verify:** `flutter analyze` passes.

---

## Task 02: 合并 glassBlurThick → glassBlur

**Why:** glassBlur (10.0) vs glassBlurThick (12.0) 的 2px 差异在 BackdropFilter 中不可感知。

**File:** `lib/ui/theme/tokens.dart`
- 删除 `glassBlurThick = 12.0`
- 保留 `glassBlur = 10.0` 和 `glassBlurThin = 4.0`

**File:** `lib/ui/player/control_bar.dart`
- `_blurFilter` 中 `Tokens.glassBlurThick` → `Tokens.glassBlur`

**Verify:** Grep `glassBlurThick` 确保无残留引用。`flutter analyze` + `flutter test` passes.

---

## Task 03: 清理 controlBarGradientEdge 引用

**Why:** 删除死 token 后需清理使用处。

**File:** `lib/ui/player/control_bar.dart`
- EdgeGlow 渐变中的 `Tokens.controlBarGradientEdge` → `Colors.transparent`

**Verify:** `flutter analyze` passes.

---

## Task 04: Token alpha 范围验证测试

**Why:** 自动化防止未来 token 回归到不可见的 alpha 值。

**File:** `test/widget/tokens_test.dart`（新建）

**Tests:**
1. `test('idle blue border alpha >= 15%')` — glassBorderIdle alpha >= 38
2. `test('playing border alpha > idle border alpha')` — controlBarBorderWhite > controlBarBorderIdle
3. `test('glassBlur > glassBlurThin')` — blur 层级逻辑
4. `test('no zero-alpha tokens in control bar set')` — 所有 controlBar* token alpha > 0
5. `test('all border tokens alpha >= 5%')` — 最低感知阈值

---

## Task 05: Golden test 更新

**Why:** alpha 值变更后 golden 截图需要更新。

**Changes:**
- `flutter test --update-goldens test/golden/`
- 对比确认 playing 状态几乎不变，idle 边框更明显

---

## Task 06: 视觉验证清单（手动）

**Why:** SC-1 要求在 5+ 视频类型上验证。

| # | 视频类型 | 验证点 | 预期 |
|---|---------|--------|------|
| 1 | 暗色视频 | idle 边框可见性 | 蓝色描边可辨识 |
| 2 | 亮色视频 | 控制栏文字可读性 | 文字不被吞没 |
| 3 | 混合视频 | idle↔playing 过渡 | 150ms 平滑无闪烁 |
| 4 | 彩色视频 | 控制栏与视频隔离 | 毛玻璃层有效 |
| 5 | 字幕/letterbox | 黑条区域边框 | 边框清晰 |
| 6 | 无视频 Aurora | idle 装饰融合 | 与 Aurora 协调 |

---

## Execution Order

```
T01 (alpha fix) → T02 (blur merge) → T03 (dead token cleanup)
                                              ↓
                               T04 (validation tests) → T05 (golden update)
                                              ↓
                               T06 (visual verification checklist)
```

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|-------------|
| SC-1 | 控制栏在 5+ 视频类型上验证 | T06 手动清单 |
| SC-2 | Idle 边框 alpha >= 15% | T04 自动测试 |
| SC-3 | glassBlur 区分确认或合并 | T02 合并为 2-tier |
| SC-4 | 无视觉回归 | T05 golden 对比 |

## Out of Scope

- 自适应渐变强度（v2+）
- 视频主色提取（v2+）
- FragmentShader 模糊（Impeller 迁移后）
