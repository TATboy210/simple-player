# Roadmap: Control Bar Polish

**Created:** 2026-07-07

## Phase 1: 动画体验优化 (CB-01)

**Goal:** 控制栏 fade 动画更平滑自然
**Estimated:** 30min

- 调整 AutoHideController 动画时长（durationFade: 300→400ms）
- 评估 fade 曲线（Curves.easeOut → 可能换 Curves.easeInOut）
- 测试 idle↔playing 状态切换装饰过渡
- 验证 resize 期间动画行为不变

**Deliverables:**
- tokens.dart: durationFade 更新
- auto_hide_controller.dart: 动画参数调整（如需要）
- 手动验证 fade 平滑度

## Phase 2: 毛玻璃 +15% (CB-02)

**Goal:** 提升毛玻璃模糊质感
**Estimated:** 15min

- tokens.dart: glassBlur 10.0 → 11.5
- 验证 GlassTier.normal 使用新值
- 确认缓存 ImageFilter 正确更新
- 验证 BackdropFilter 跳过逻辑不受影响

**Deliverables:**
- tokens.dart: glassBlur 更新
- 视觉验证模糊效果

## Phase 3: 按钮 hover 优化 (CB-03)

**Goal:** hover 反馈更显眼且区域更紧凑
**Estimated:** 30min

- 调整 Tokens.bgHover 颜色（提升亮度/对比度）
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

## Phase 5: 移除底部辉光 (CB-05)

**Goal:** 删除控制栏底部的 TransmittedLight 效果
**Estimated:** 10min

- 删除 controls_overlay.dart 中 TransmittedLight Positioned 块
- 验证不影响 OSD/ErrorBanner 定位
- 验证不影响控制栏 margin/position

**Deliverables:**
- controls_overlay.dart: 移除 TransmittedLight 代码
- 视觉验证无底部辉光

---
*Roadmap created: 2026-07-07*
