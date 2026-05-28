# Phase 3 Discussion Log

**Date:** 2026-05-29
**Mode:** default (interactive)

## Areas Discussed

### 1. Control Bar Root Cause (19 questions)
- Strategy: Profile-first → User chose "先 Profile 再修复"
- Tool: Flutter DevTools → User chose DevTools frame timeline
- Threshold: 16.6ms (60fps) → User chose standard 60fps
- Scenarios: Control bar + 4K + progress bar seek → User chose all + separate progress bar
- Phase 2 handling: Verify first → User chose "先验证 Phase 2 优化效果"
- Fix strategy: Comprehensive → User chose "全面优化，预防为主"
- Isolation: blurEnabled comparison → User chose blurEnabled true/false test
- Profile mode: Profile mode → User chose --profile
- PerfMonitor: Clean up → User chose "清理死代码 + 修复无界列表"
- Window modes: Both → User chose "两种模式都测"
- queryFence: Research first → User chose "先研究再决定"
- Fix layer: Widget + fvp → User chose "Widget 层 + fvp 参数"
- Subtitles: Test with → User chose "开启字幕测试"
- Performance overlay: Not needed → User chose "DevTools 够用"
- Regression: Test + DevTools → User chose "测试套件 + DevTools 验证"
- Documentation: Both → User chose "计划文档和CONCERNS.md都更新"
- Benchmark: DevTools script → User chose "自动化 DevTools 脚本"
- Test videos: Existing → User chose "用现有视频"
- Progress bar: Separate profile → User chose "单独 Profile 进度条"

### 2. D3D11 Tuning Scope (21 questions)
- Scope: Multiple params → User chose "多个 fvp 参数"
- Parameters: All perf → User chose "所有性能参数"
- Method: Single then combo → User chose "先单变量后组合"
- Documentation: Plan docs → User chose "记录在计划文档中"
- queryFence: Include → User chose "纳入测试范围"
- Hardware: Low-end first → User chose "低端硬件优先"
- Reference: Both → User chose "两者都参考"
- Config: Hardcoded + interface → User chose "硬编码 + 预留接口"
- Timing: Init + runtime → User chose "初始化 + 运行时可调"
- Scope: Rendering first → User chose "先 D3D11 后 MDK"
- Verification: Test + DevTools → User chose "测试套件 + DevTools"
- Hardware test: Low-end only → User chose "只测低端硬件"
- Parameter scope: Rendering + decoding → User chose "渲染 + 解码参数"
- Source: Source code first → User chose "源码优先"
- Validation: Multi-dimension → User chose "多维度评估"
- Order: D3D11 first → User chose "先 D3D11 后控制栏"
- Parallel: Can be parallel → User chose "可以并行"
- Hardware priority: Low-end first → User chose "低端硬件优先" (repeated)

### 3. Measurement Approach (11 questions)
- Tool: DevTools → User chose "DevTools frame timeline"
- Metrics: Multi-dimension → User chose "多维度指标"
- Targets: Both → User chose "两者都作为目标"
- Aggregation: Average → User chose "所有场景取平均"
- Baseline: Measure first → User chose "先测基线后优化"
- Frequency: Every point → User chose "每个优化点都测量"
- Automation: DevTools script → User chose "自动化 DevTools 脚本"
- Recording: Independent report → User chose "独立性能报告"
- Validation: Multi-dimension → User chose "多维度指标" (repeated)

### 4. Additional Areas (9 questions)
- Error handling: Check as part of Phase 3 → "顺便检查"
- PerfMonitor: Clean dead code + fix lists → "清理死代码 + 修复无界列表"
- queryFence: Automate → "自动化 patch 应用"
- Phase 2 extension: Data-driven → "根据数据决定"
- Performance tests: Add benchmark → "添加性能基准测试"
- Test regression: Every optimization → "每次优化后跑测试"
- Priority: D3D11 first → "先 D3D11 后控制栏"
- Test data: Prepare videos → "准备测试视频"
- Build config: Data-driven → "根据数据决定"
- User interface: Add options → "添加性能选项"
- fvp version: Research first → "先研究再决定"
- New deps: Data-driven → "根据数据决定"
- C++ mods: Data-driven → "根据数据决定"

## Deferred Ideas
- Triple buffering (v2, requires fvp fork)
- Impeller FragmentShader (v2, requires Impeller stable)
- Golden tests (Phase 4)

## Decisions Summary
Total decisions captured: 41
Key themes: Profile-first, low-end hardware baseline, comprehensive optimization, data-driven decisions
