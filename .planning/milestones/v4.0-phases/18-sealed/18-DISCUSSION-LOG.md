# Phase 18: Sealed 错误模型稳化 - Discussion Log

**Date:** 2026-07-19
**Mode:** default (4 areas, 11 questions)

## Area 1: ErrorContext 结构与挂载方式

| # | Question | Options | Selection |
|---|----------|---------|-----------|
| D1 | ErrorContext 怎么挂载到 PlayerError？ | PlayerError 新增可选字段 / 每子类独立字段 / 包装类 EnrichedError | **PlayerError 新增可选字段** |
| D2 | ErrorContext 在哪一层注入？ | 引擎 catch 点注入 / PlaybackController 层注入 | **引擎 catch 点注入** |
| D3 | timestamp 默认 now() 还是必传？ | 默认 now() + 可覆盖 / 必传 timestamp | **默认 now() + 可覆盖** |

## Area 2: 可恢复 vs 致命分类与 ErrorCode 注册表

| # | Question | Options | Selection |
|---|----------|---------|-----------|
| D4 | 可恢复/致命分类怎么实现？ | bool isFatal getter / 独立 sealed 分支 | **bool isFatal getter** |
| D5 | ErrorCode 注册表怎么设计？ | 保持现有枚举 + 内嵌 recoverable / 统一 ErrorCode 枚举 | **保持现有枚举 + 内嵌 recoverable** |
| D6 | 错误码冻结策略？ | 追加-only + doc comment / 其他 | **追加-only + doc comment 注明冻结** |

## Area 3: UI 边界翻译与错误传播链

| # | Question | Options | Selection |
|---|----------|---------|-----------|
| D7 | UI 翻译层怎么设计？ | PlayerError 内嵌 l10nKey / 独立 ErrorInfo DTO / ErrorBanner 内部翻译 | **PlayerError 内嵌 l10nKey** |
| D8 | PlaybackController._onError 签名？ | 签名收窄为 PlayerError / 保持 Object error | **签名收窄为 PlayerError** |

## Area 4: mdk 回调线程封送与 logger 集成

| # | Question | Options | Selection |
|---|----------|---------|-----------|
| D9 | 线程封送策略？ | scheduleMicrotask 封送 / 回调存临时变量 + 轮询 | **scheduleMicrotask 封送** |
| D10 | logger 集成模式？ | 每个 catch 点三步合一 / 提取 _emitError() helper | **每个 catch 点三步合一** |
| D11 | ErrorContext 加 callbackStackTrace？ | 加字段 / 合并到 cause | **加 callbackStackTrace 字段** |

## Decisions Summary

11 decisions across 4 areas. All user-selected (no "Let Claude decide").

## Deferred Ideas

- P19 MemoryMonitor error integration
- P20 NewFvpEngine error handling (same three-step pattern)
- P20 Result.err replacement for silent asserts
- P22 DOC-03 error code bilingual comments
- ERR-F01 Future (openGeneration correlation, RetryPolicy, per-code metrics, l10n key mapping)

---

*Discussion completed: 2026-07-19*
