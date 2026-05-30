# Phase 12: Debug Tooling - Context

**Gathered:** 2026-05-30
**Status:** Ready for planning

<domain>
## Phase Boundary

Debug 工具和诊断改进：结构化 JSON 日志输出、按模块命名的 logger 实例、关键性能路径的 dart:developer Timeline 事件。仅限 Windows 桌面端本地播放器。

</domain>

<decisions>
## Implementation Decisions

### JSON 日志格式
- **D-01:** 使用 `logger` 包自带 `JsonPrinter`，零额外自定义代码。**注意：** D-14 指定默认输出为 PrettyPrinter（人类可读）。JsonPrinter 作为已配置选项导出（`jsonPrinter`），供日志聚合工具按需使用。默认输出不使用 JsonPrinter。
- **D-02:** 字段由 JsonPrinter 默认提供：level, message, time, error, stackTrace
- **D-03:** 不添加自定义 module 字段到 JSON（命名 logger 的 prefix 已区分来源）

### 命名 Logger 规范
- **D-04:** 按模块创建命名 logger：`Logger('engine')`, `Logger('bridge')`, `Logger('services')`, `Logger('ui')`
- **D-05:** 保留全局 `log` 变量作为默认 logger（向后兼容），新代码使用模块 logger
- **D-06:** 工厂方式：直接 `Logger(filter: ..., printer: ..., output: ...)` 构造，不需额外工厂类
- **D-07:** 模块 logger 与全局 log 共享相同的 printer 和 output 配置（由 initLog 统一设置）

### Timeline 追踪方法
- **D-08:** 追踪 `FvpEngine.open()` — 媒体打开延迟
- **D-09:** 追踪 `FvpEngine.seek()` — 跳转响应速度
- **D-10:** 追踪 `WindowService.enterFullscreen()` / `exitFullscreen()` — 全屏切换
- **D-11:** 使用 `dart:developer.Timeline.startSync()` / `finishSync()` 包裹关键方法

### 日志级别策略
- **D-12:** Debug 模式：全部级别输出到 console（当前行为不变）
- **D-13:** Release 模式：仅 warning 及以上写入文件（当前 ProductionFilter 改为 Level.warning）
- **D-14:** 文件输出保持 PrettyPrinter 格式（非 JSON），console 输出在 debug 模式保持 PrettyPrinter

### Claude's Discretion
- logger 包版本升级策略（如有新版本）
- Timeline 事件的 category 命名规范
- 测试策略（mock Logger 还是验证输出格式）

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 当前实现
- `lib/kernel/utils/log.dart` — 当前日志实现（136 行），包含 PrettyPrinter 配置、initLog、_RotatingFileOutput
- `lib/main.dart` — initLog() 调用位置

### 依赖文档
- `pubspec.lock` — logger 包当前版本
- `CLAUDE.md` — 项目规范（debugPrint 约定、3 层架构）

### 需求
- `.planning/REQUIREMENTS.md` — DBG-01 需求定义

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `_RotatingFileOutput` — 文件轮转逻辑已实现，可直接复用
- `initLog()` — release 模式文件输出初始化，需要修改以支持模块 logger
- `ProductionFilter` — logger 包自带，可自定义级别阈值

### Established Patterns
- 19 个文件使用 `log.` 调用 — 需要逐步迁移到模块 logger
- `debugPrint()` 在 CLAUDE.md 中约定用于调试输出
- `kDebugMode` 用于条件判断

### Integration Points
- `main.dart` → `initLog()` 调用点
- `fvp_engine.dart` → engine 模块 logger
- `window_service.dart` → bridge 模块 logger
- `playback_controller.dart`, `thumbnail_service.dart` → services 模块 logger
- `player_screen.dart`, `controls_overlay.dart` → ui 模块 logger

</code_context>

<specifics>
## Specific Ideas

- Timeline 事件在 DevTools Performance 面板中可见，用于分析启动和操作延迟
- 模块 logger 的 prefix 在日志聚合工具中可作为过滤维度
- 文件输出保留 PrettyPrinter（人类可读），console 在 release 模式用 JsonPrinter（机器可解析）

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 12-Debug Tooling*
*Context gathered: 2026-05-30*
