# Requirements: v1.6 控制栏质量优化与测试补全

**Milestone:** v1.6
**Goal:** 消除控制栏 P0-P1 技术债务，修复窗口拉伸时毛玻璃突兀跳变，建立控制栏测试基础
**Created:** 2026-07-05

## User Stories

**US-01:** 作为用户，窗口拉伸时控制栏毛玻璃效果应平滑过渡，不应突然消失或闪烁
**US-02:** 作为用户，拖动音量滑块时不应看到大量 OSD 弹窗堆积
**US-03:** 作为开发者，控制栏组件应有完整测试覆盖，确保重构安全

## Acceptance Criteria

### AC-01: Resize 毛玻璃平滑过渡
- 窗口 resize 开始时，毛玻璃效果以 150ms 渐变淡出（而非立即消失）
- 窗口 resize 结束时，毛玻璃效果以 150ms 渐变淡入（而非立即出现）
- resize 期间控制栏保持可交互状态
- 视觉上无明显跳变或闪烁

### AC-02: Decoration 缓存
- `_decorationPlaying` 和 `_decorationIdle` 不在每次 build() 时重新创建
- AnimatedContainer 的 idle↔playing 插值动画仍正常工作
- 每帧减少 2 个 BoxDecoration + 8 个 BoxShadow 对象创建

### AC-03: ImageFilter.blur 缓存
- GlassContainer 的 `ImageFilter.blur` 不在每次 `_buildBlurContent()` 时重新创建
- 3 个 GlassTier (thin/normal/thick) 各自缓存一个 blur filter 实例
- 无功能回归

### AC-04: 魔法数字提取
- `controls_overlay.dart` 中的 18px 提取为命名常量
- 常量放入 `Tokens` 或文件级 `static const`
- 行为不变

### AC-05: VolumeSlider debounce
- 拖拽期间 OSD 调用频率从 60+/秒降至 ≤10/秒
- 引擎 setVolume 调用频率同步降低
- 拖拽结束时立即同步最终值（无延迟）

### AC-06: 测试覆盖
- AutoHideController: 单元测试覆盖状态机转换（idle→playing→hidden→paused）、hover 节流、resize 冻结
- ProgressBar: Widget 测试覆盖拖拽阈值、seek 节流、hover tooltip
- VolumeButton: Widget 测试覆盖静音切换、音量保存/恢复、滑块联动
- SpeedButton: Widget 测试覆盖双击重置、滚轮切换、OSD 反馈

## Requirements Table

| ID | Description | Source | Priority |
|----|-------------|--------|----------|
| PERF-01 | Resize 毛玻璃渐变过渡 | 用户反馈 + 分析报告 P0 | Must |
| PERF-02 | Decoration 缓存 | 分析报告 P0 | Must |
| PERF-03 | ImageFilter.blur 缓存 | 分析报告 P0 | Must |
| PERF-04 | 魔法数字 18px 提取 | 分析报告 P0 | Must |
| PERF-05 | VolumeSlider debounce | 分析报告 P1 | Should |
| TEST-01 | AutoHideController 测试 | 分析报告测试缺口 | Must |
| TEST-02 | ProgressBar 测试 | 分析报告测试缺口 | Should |
| TEST-03 | VolumeButton 测试 | 分析报告测试缺口 | Should |
| TEST-04 | SpeedButton 测试 | 分析报告测试缺口 | Should |
