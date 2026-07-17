# Phase 15 Baseline Audit

> 由 `tool/audit/inventory.sh` 自动生成——数字来自脚本对 LIVE `lib/` 代码的实时扫描，
> 不是任何历史文档的转述（D21：不设第二真相源）。重新运行脚本以获取当前数字。

**Generated at:** 2026-07-16T21:16:34Z
**Script version:** 1.0.0

## package:logger 风格调用统计

| Metric | Value |
|--------|-------|
| Total call sites | 84 |
| Total files | 28 |

### Breakdown by prefix

| Prefix | Call sites |
|--------|-----------|
| log | 64 |
| logEngine | 9 |
| logBridge | 11 |
| logServices | 0 |
| logUi | 0 |

## MemoryMonitor.start()/.snapshot() 生产调用点

**Total call sites:** 2

- lib/kernel/utils/debug_exporter.dart:57
- lib/main.dart:16

## openGeneration 引用

**Total files:** 2

- lib/kernel/engine/fvp_engine.dart
- lib/kernel/services/playback_navigator.dart
