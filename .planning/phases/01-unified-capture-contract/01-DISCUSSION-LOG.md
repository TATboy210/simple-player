# Phase 1 讨论记录

**Phase:** 1 统一捕获与报告契约
**Date:** 2026-08-28
**Mode:** default（interactive）

## Areas Discussed

### 启动期错误补显
- **Options:** 挂载后自动补显（flush）/ 只落盘不补显 / 补显仅最新一条
- **Decision:** 挂载后自动补显 — pre-runApp 错误由 reporter 记录，UI 挂载后 flush 到卡片
- **Notes:** 用户选研究推荐项

### 队列与去重参数
- **Options:** 容量 3/5/10；时间窗合并 / 永久合并
- **Decision:** FIFO 容量 5 条；时间窗合并（超窗视为新错误）
- **Notes:** 窗口时长留给 planner 依研究定（产品语义锁定为时间窗）

### 双 binding 启动组装
- **Options:** 全包 main 体 / 只包 runApp / 仅 release 全包
- **Decision:** 全包 main 体 — binding 初始化（Marionette/Widgets 两分支）、初始化链、钩子、runApp 同 zone
- **Notes:** 符合 Flutter same-zone 要求（官方 breaking change 文档）

### Reporter 装配位置
- **Options:** kernel 单例 / PlayerServices 注入 / App widget 持有
- **Decision:** kernel 静态单例（ErrorReporterImpl.I，仿 KernelLoggerImpl.I 惯例），main 最早初始化；player_services 重复 init 收敛到 main
- **Notes:** 启动期错误必须能进 reporter 是决定性约束

## Claude's Discretion Items
- 指纹字段构成、严重级枚举命名、init 收敛实现、呈现状态 notifier 形态

## Deferred Ideas
None — discussion stayed within phase scope
