# Discussion Log: Phase 27 — Responsive Scaling & Polish

**Date:** 2026-07-25
**Mode:** Interactive (default)

## Areas Discussed

### 1. Tab Bar 适配

**Q1:** 400px 宽度下，7 个 tab 如何排列？
- Options: 保持等宽均分+省略号 / 可水平滚动 / 图标+tooltip 模式 / 自适应压缩字体/间距
- **Selection:** 自适应压缩字体/间距

**Q2:** 压缩模式的切换策略？
- Options: 800px 断点切换 / 线性渐变缩放 / 三档断点
- **Selection:** 800px 断点切换 (Recommended)

**Q3:** 压缩模式的具体字体/间距数值？
- Options: 14px→12px / 14px→11px / 由 Tokens 定义
- **Selection:** 14px→12px 字体 (Recommended)

**Q4:** 面板整体宽度策略？
- Options: 连续比例缩放 / 两档固定宽度 / 纯比例无限制
- **Selection:** 连续比例缩放 (Recommended)

**More questions check:** "进入动效完善"

### 2. 动效完善

**Q1:** 打开/关闭动画如何实现？
- Options: 保持现有+性能优化 / SpringSimulation / 新增内容区滑入 / 不做额外优化
- **Selection:** 保持现有+性能优化 (Recommended)

**Q2:** 60fps 性能优化具体策略？
- Options: RepaintBoundary 隔离 / 动画期降低视频质量 / RepaintBoundary+曲线优化 / 先 profiling
- **Selection:** RepaintBoundary 隔离 (Recommended)

**Q3:** 动画期间 BackdropFilter 如何处理？
- Options: 保持模糊 / 临时禁用模糊 / 降低模糊强度
- **Selection:** 动画期间保持模糊 (Recommended)

**Q4:** 窗口跨越断点时是否有过渡动画？
- Options: 无过渡动画 / 200ms 过渡 / AnimatedContainer
- **Selection:** 无过渡动画 (Recommended)

**More questions check:** "准备生成 Context"

## Decisions Summary

| # | Decision | Area |
|---|----------|------|
| D-01 | 800px 断点切换 | Tab Bar |
| D-02 | 正常模式 14px+16px 间距 | Tab Bar |
| D-03 | 压缩模式 12px+8px 间距 | Tab Bar |
| D-04 | 面板宽度 clamp(w*0.8, 400, 600) | Tab Bar |
| D-05 | Tokens 新增 responsive 常量 | Tab Bar |
| D-06 | 保持 Phase 23 动画基础 | 动效 |
| D-07 | RepaintBoundary 隔离 | 动效 |
| D-08 | 动画期保持 BackdropFilter 模糊 | 动效 |
| D-09 | 断点切换无过渡动画 | 动效 |

## Deferred Ideas

None — discussion stayed within phase scope.

---

*Log generated: 2026-07-25*
