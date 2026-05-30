# Phase 12: Debug Tooling - Discussion Log

**Date:** 2026-05-30
**Mode:** discuss

## Area 1: JSON 日志格式
- **Options:** JsonPrinter 直接用 / 自定义 + module 字段 / 紧凑单行 JSON
- **Selection:** JsonPrinter 直接用 (Recommended)
- **Notes:** 零额外代码，logger 包自带

## Area 2: 命名 Logger 规范
- **Options:** 模块名直接命名 / 带包名前缀 / 保留全局变量
- **Selection:** 模块名直接命名 (Recommended)
- **Notes:** Logger('engine'), Logger('bridge'), Logger('services'), Logger('ui')

## Area 3: Timeline 追踪方法
- **Options:** open / seek / fullscreen / thumbnail (multiSelect)
- **Selection:** open, seek, fullscreen (3 methods)
- **Notes:** 使用 dart:developer.Timeline.startSync/finishSync

## Area 4: 日志级别策略
- **Options:** Release 仅 warning+ / Release 仅 info+ / 保持现状
- **Selection:** Release 仅 warning+ (Recommended)
- **Notes:** Debug 模式全部输出，Release 仅 warning 以上写文件

## Decisions Summary
- D-01~03: JsonPrinter 直接用，无自定义字段
- D-04~07: 模块命名 logger，保留全局 log 向后兼容
- D-08~11: Timeline 追踪 open/seek/fullscreen
- D-12~14: Release 仅 warning+，文件保留 PrettyPrinter

## Deferred Ideas
None
