# Phase 25: Performance Quick Wins - Context

**Gathered:** 2026-07-05
**Status:** Ready for planning

<domain>
## Phase Boundary

消除 4 项 P0 性能/代码质量问题：resize 毛玻璃跳变、decoration 缓存、blur 缓存、魔法数字提取。附带控制栏颜色从白色微光改为淡蓝辉光。

范围：
- PERF-01: Resize 毛玻璃 150ms 渐变淡出/淡入（替代二元跳过）
- PERF-02: ControlBar._decorationPlaying/_decorationIdle 缓存（AnimatedBuilder + DecorationTween）
- PERF-03: GlassContainer ImageFilter.blur 按 GlassTier 缓存
- PERF-04: 18px 魔法数字提取为 Tokens.tapJitterThreshold
- 附带: 控制栏颜色从白色微光改为淡蓝辉光（边框+背景+阴影）

</domain>

<decisions>
## Implementation Decisions

### Decoration 缓存策略

- **D-01:** **AnimatedBuilder + DecorationTween** — 缓存 playing/idle 两个 static final BoxDecoration，用 DecorationTween 显式驱动插值（替代 AnimatedContainer 隐式动画）
- **D-02:** **DecorationTween 折中** — evaluate() 每帧创建 1 个 BoxDecoration（比 getter 每帧创建 2 个好，idle 时 0 个）
- **D-03:** **AnimationController 放在 ControlsOverlay** — ControlsOverlay 是 StatefulWidget 且已有 SingleTickerProviderStateMixin
- **D-04:** **对齐 BoxShadow 结构** — idle 和 playing 都有 4 个 BoxShadow（idle 补齐 outer shadow 和 glow ring），让 Tween 插值更平滑
- **D-05:** **动画时长 150ms + easeOut** — 放入 Tokens 常量，与 resize 渐变时长一致

### Resize 渐变实现

- **D-06:** **复用 GlassContainer.opacity 参数** — GlassContainer 已有 opacity ValueListenable，ControlsOverlay 传入 opacityNotifier 驱动淡入淡出
- **D-07:** **AnimationController + Tween 驱动** — resizing 变 true → reverse()（1.0→0.0），变 false → forward()（0.0→1.0）
- **D-08:** **150ms 时长** — PERF-01 要求，与 Decoration 动画共享时长常量
- **D-09:** **共享 AnimationController** — Decoration 和 Resize 共用一个 controller，resize 优先级高于 decoration（resize 期间 decoration 动画暂停）

### Blur 缓存

- **D-10:** **GlassTier enum + static field** — 在 GlassTier 上新增 static final ImageFilter 实例，每个 tier 一个缓存
- **D-11:** **删除重复缓存** — 删除 ControlBar._blurFilter 和 PlaylistPanel._blurFilter，统一使用 GlassTier.blurFilter
- **D-12:** **thick 与 normal 共用实例** — 两者 sigma 都是 10（有意设计，差异不可感知），缓存后自动共享同一实例

### 魔法数字提取

- **D-13:** **Tokens.tapJitterThreshold = 18.0** — 手指/鼠标点击抖动容差，与 Tokens.iconMd=18.0 语义不同，分别定义
- **D-14:** **注释说明** — "手指/鼠标点击的抖动容差，小于此距离视为点击而非拖拽"

### 控制栏颜色调整（附带）

- **D-15:** **边框+背景+阴影全部调整** — 从白色微光改为淡蓝辉光，与午夜蓝背景融合
- **D-16:** **修改现有 Tokens 常量** — controlBarBorderWhite、controlBarBg、controlBarOuterShadow 等改为淡蓝色调
- **D-17:** **先用近似值，运行后微调** — 具体色值需要在实际显示器上调试
- **D-18:** **两个状态都调整，playing 稍亮** — playing 和 idle 都改为淡蓝辉光，playing 通过亮度/饱和度区分

### Claude's Discretion

- 具体色值由 Claude 先用近似值，用户运行后微调
- AnimationController 的 ticker 管理细节由 Claude 决定
- DecorationTween 的具体实现细节由 Claude 决定

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 需求定义
- `.planning/REQUIREMENTS.md` §v1.6 — PERF-01 ~ PERF-04 需求定义和验收标准
- `.planning/ROADMAP.md` §Phase 25 — 成功标准（6 条）

### 目标文件
- `lib/ui/shared/glass_container.dart` — GlassContainer + GlassTier（blur 缓存 + resize 渐变）
- `lib/ui/player/control_bar.dart` — ControlBar（decoration 缓存 + blur 缓存删除）
- `lib/ui/player/controls_overlay.dart` — ControlsOverlay（AnimationController + 18px 提取）
- `lib/ui/theme/tokens.dart` — Tokens（常量新增/修改）
- `lib/ui/playlist/playlist_panel.dart` — PlaylistPanel（blur 缓存删除）

### 前置阶段
- `.planning/phases/24-features-verification/24-CONTEXT.md` — Phase 24 决策（注释规范继承）

### 代码库约定
- `.planning/codebase/CONVENTIONS.md` — 注释规范
- `.planning/codebase/ARCHITECTURE.md` — 组件职责和层级关系

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **GlassContainer.opacity** — 已有 ValueListenable<double> 参数，可直接复用驱动 resize 渐变
- **GlassContainer.resizing** — 已有 ValueListenable<bool> 参数，当前二元跳过，改为渐变过渡
- **ControlsOverlay._autoHide** — 已有 AutoHideController，可扩展支持 resize 状态
- **Tokens.glassBlur/glassBlurThin** — 已有 blur sigma 常量，直接用于 GlassTier 缓存

### Established Patterns
- **static final 缓存** — ControlBar 已用 static final _blurFilter 缓存 ImageFilter，模式可复制到 GlassTier
- **AnimatedBuilder + ValueListenable** — GlassContainer 已用 AnimatedBuilder 监听 opacity/resizing，模式可复用
- **SingleTickerProviderStateMixin** — ControlsOverlay 已有，可复用 AnimationController

### Integration Points
- **ControlsOverlay → GlassContainer** — 通过 opacity/resizing 参数传递动画状态
- **ControlsOverlay → ControlBar** — 通过 resizing 参数传递 resize 信号
- **Tokens → 所有 UI 文件** — 常量修改影响所有引用处

</code_context>

<specifics>
## Specific Ideas

- 控制栏颜色改为"辉光淡蓝色"，与午夜蓝背景融合，不是纯白微光
- 用户要求"给我选项的同时尽可能将选项的细节功能写的更加清楚"
- 用户要求"改写的代码也要将注释添加上去"

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 25-Performance Quick Wins*
*Context gathered: 2026-07-05*
