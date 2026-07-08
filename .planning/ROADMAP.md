# Roadmap: Control Bar Polish

**Created:** 2026-07-07

## Phase 1: 动画体验优化 (CB-01)

**Goal:** 控制栏 fade 动画更平滑自然
**Estimated:** 30min
**Plans:** 1 plan

Plans:
- [x] 01-01-PLAN.md — Fade动画参数(400ms+easeInOut) + 底部触发区域 + 点击立即隐藏 ✅ 2026-07-08

- 调整 AutoHideController 动画时长（durationFade: 300→400ms）
- 评估 fade 曲线（Curves.easeOut → 可能换 Curves.easeInOut）
- 测试 idle↔playing 状态切换装饰过渡
- 验证 resize 期间动画行为不变

**Deliverables:**
- tokens.dart: durationFade 400 + bottomTriggerZoneHeight 150 ✅
- auto_hide_controller.dart: Curves.easeInOut ✅
- controls_overlay.dart: 底部触发 + 点击立即隐藏 ✅
- 手动验证 fade 平滑度（待运行应用验证）

## Phase 2: 毛玻璃 +15% (CB-02) ✅ 2026-07-08

**Goal:** 提升毛玻璃模糊质感
**Estimated:** 15min

- tokens.dart: glassBlur 10.0 → 11.5 ✅
- 验证 GlassTier.normal 使用新值
- 确认缓存 ImageFilter 正确更新
- 验证 BackdropFilter 跳过逻辑不受影响

**Deliverables:**
- tokens.dart: glassBlur 更新
- 视觉验证模糊效果

## Phase 3: 按钮 hover 优化 (CB-03) ✅ 2026-07-08

**Goal:** hover 反馈更显眼且区域更紧凑
**Estimated:** 30min

- 调整 Tokens.bgHover 颜色（提升亮度/对比度） ✅ 0xFF1E2232→0xFF283045
- 检查 InkWell borderRadius 是否导致高亮溢出到控制栏边框
- 测试 idle/playing 两种状态下的 hover 效果

**Deliverables:**
- tokens.dart: bgHover 颜色调整
- glass_container.dart: InkWell 参数微调（如需要）
- 视觉验证 hover 效果

## Phase 4: 布局压缩评估 (CB-04)

**Goal:** 评估并实施控制栏高度压缩
**Estimated:** 30min

- 分析 3 行当前 flex 比例（1:1:1）和实际内容高度需求
- 确定最小可行高度
- 如可压缩：调整 flex 比例或 controlBarHeight
- 确保按钮不溢出、进度条可交互

**Deliverables:**
- control_bar.dart: Column flex 比例调整
- tokens.dart: controlBarHeight 调整（如适用）
- 响应式断点验证

## Phase 5: 移除底部辉光 (CB-05) ✅ 2026-07-08

**Goal:** 删除控制栏底部的 TransmittedLight 效果
**Estimated:** 10min

- 删除 controls_overlay.dart 中 TransmittedLight Positioned 块 ✅
- 移除未使用的 transmitted_light.dart import ✅
- 验证不影响 OSD/ErrorBanner 定位 ✅ (16/16 测试通过)
- flutter analyze: 22 issues (全部 pre-existing) ✅
- 验证不影响控制栏 margin/position

**Deliverables:**
- controls_overlay.dart: 移除 TransmittedLight 代码
- 视觉验证无底部辉光

## Phase 6: Resize 接线修复 (CB-06)

**Goal:** 修复 resize 信号断路 — ControlBar→ProgressBar 透传 + AutoHideController 同步
**Estimated:** 15min
**Priority:** P0（性能 + 体验 bug）

### 改动清单（2 文件 7+2 处）

**A — ControlBar 传递 resizing（control_bar.dart）:**
- [ ] A1: 新增 `final ValueListenable<bool>? resizing;` 字段
- [ ] A2: 构造函数新增 `this.resizing`
- [ ] A3: ProgressBar 调用处传 `resizing: resizing`

**B — Overlay 同步 AutoHideController（controls_overlay.dart）:**
- [ ] B1: `_onResizeChanged()` 开头加 `_autoHide.resizing = resizing;`
- [ ] B2: `initState` 加防御性同步
- [ ] B3: `didUpdateWidget` 切换 listener 后同步当前值

**C — Overlay 传递 resizing 给 ControlBar:**
- [ ] C1: ControlBar 构造处加 `resizing: widget.resizing`

**D — 注释优化（P1）:**
- [ ] D1: `_cachedCustomPaint` 加 doc comment
- [ ] D2: `_handleTap` 空回调加注释

### 验收清单
- [ ] 拖窗 5-10s：不抖动、不闪隐
- [ ] 自动隐藏 windowed ~5s / fullscreen ~3s 正常
- [ ] resize 期间冻结隐藏计时器
- [ ] 进度条/音量/倍速/双击全屏回归正常

---
*Roadmap created: 2026-07-07*
