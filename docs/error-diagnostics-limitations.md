# 错误诊断系统:边界与降级策略(开发者文档)

> Error Diagnostics: Boundaries and Degradation Strategies (Developer Guide)
>
> 面向开发者自助排障。本里程碑的错误系统覆盖 Dart 层四类捕获源
> (FlutterError.onError / PlatformDispatcher.onError / runZonedGuarded /
> PlayerError 桥接)→ ErrorReporter → 错误卡片 + 纯文本 error.log。
> 本文档说明它**覆盖不到什么、降级时表现如何、以及如何读日志**。

---

## 1. release 源码/符号降级策略

**Release source/symbol degradation policy**

- **机制:** 源码行读取只在 debug/profile 构建生效。`source_line_reader.dart`
  以 `kReleaseMode` 判定 `SourceReadBuildMode.release`,release 构建下
  **不做任何源码文件 I/O**。
- **降级表现(LOC-02):** release 下报告的「位置」信息优雅降级为**仅定位文本**
  ——仍给出调用栈帧里的 `文件:行号`(来自原始栈),但**不附带源码行内容**;
  不报错、不闪退、不中断落盘。debug/profile 才有源码行片段。
- **读数方法:** release 包的卡片「位置」节 / error.log 的 `== Location ==` 节
  显示 frame 文本(`Primary: xxx.dart:123:7` 形态)而无 `Source Lines:` 内容;
  `== Raw Stack ==` 节始终完整(原始栈逐字拷贝,是终局证据)。
- **为什么不符号化:** 定位目标是「项目内哪个文件哪一行」,栈帧文本已满足;
  native 符号化属于原生崩溃域(见 §2/§4)。

**English:** Source-line reading is disabled in release builds
(`SourceReadBuildMode.release` via `kReleaseMode`). Reports degrade
gracefully to location text only (file:line from stack frames, no source
snippet) — never an error, never a crash. The raw stack is always copied
verbatim and remains the terminal evidence.

---

## 2. Dart 钩子边界:不覆盖 libmpv/FFI 原生进程崩溃

**Dart hook boundary: native process crashes are out of scope**

- **覆盖范围:** 三个 Dart 全局钩子
  (`FlutterError.onError`、`PlatformDispatcher.onError`、
  `runZonedGuarded` 启动兜底)只捕获 **Dart 层异常**——框架错误、未捕获
  异步错误、zone 内错误,以及经 `PlayerErrorReportBridge` 上报的播放器
  语义错误。这些全部进入 ErrorReporter → 卡片 + error.log。
- **不覆盖:** libmpv/FFI **原生进程崩溃**——access violation、原生 abort、
  DLL 内部硬崩溃等。此类崩溃发生在 C/C++ 层,进程直接终止,**不会经过
  任何 Dart 钩子**,error.log 不会留下记录,卡片不会出现。
- **兜底归属:** 原生崩溃属 **WER LocalDumps 工具域**(见 §4,零代码兜底)。
  本项目不建远程上报/遥测(REQUIREMENTS Out of Scope 口径:本地纯文本
  日志回溯足够)。
- **判别方法:** 「出错但 error.log 与卡片均无记录」且进程瞬间消失
  → 大概率是原生崩溃;用 §4 的 dump 文件验证。

**English:** The three Dart hooks plus the PlayerError bridge capture only
Dart-layer exceptions. Native process crashes (access violation, native
abort inside libmpv/FFI) terminate the process without passing through any
Dart hook — nothing reaches error.log. They belong to the WER LocalDumps
tooling domain (§4). No remote telemetry is built (per REQUIREMENTS
Out of Scope).

---

## 3. isolate 写盘语义与卡死时间窗读数方法

**Isolate write semantics and how to read the frozen-window from log timestamps**

- **生产写盘链:** ErrorReporter effect → `DelegatingDiagnosticLogEffect` →
  **独立 isolate**(`IsolatedErrorLogSink` + `isolated_error_log_sink_worker`)。
  主 isolate 只投递写请求;worker 按 **append 打开(不存在则创建)→ UTF-8
  写入 → flush** 顺序落盘。写失败**绝不外溢**(不毒化后续写、不抛回
  reporter、不卡 UI)。
- **心跳行:** 主侧默认每 **30 秒**写一条心跳行(`heartbeatInterval`)。
  应用健康时,日志时间戳以 ≤30s 的间隔持续推进。
- **「日志不可用」状态含义:** `logsAvailable` notifier 置 false = 写盘链
  已降级(磁盘 I/O 失败,once-guard:cancel 心跳 → 缓冲重放 → 放行未决
  drain/dispose)。此时卡片「打开日志」按钮给「日志文件不可用」提示;
  捕获链**不受影响**——错误照常入队、照常上卡,只是文件证据暂缺。
- **卡死时间窗读数方法(核心):** 主 isolate 卡死时,心跳 Timer 无法触发,
  心跳行**停写**;恢复后下一条记录(错误或心跳)会接上。因此:
  1. 在 error.log 中找到**最后一条正常心跳行**的时间戳 T1;
  2. 找到其后**第一条记录**的时间戳 T2;
  3. **T1–T2 之间的空档即卡死时间窗**(心跳空档 = 冻结窗口)。
     配合该窗口内是否有 `Message:` 行,可区分「卡死期间出错」与
     「纯卡死后恢复」。
- **日志落点:** 落点解析经 `error_log_location.dart` 的回退链——exe 根
  `logs/error.log` 优先;exe 层不可写(如 MSIX/ACL 保护目录)时**静默回退**
  Application Support `logs/error.log`。卡片「打开日志」按钮直达该文件。

**English:** Durable evidence is written by an isolate worker
(append → UTF-8 → flush; write failures never escape). A heartbeat line is
written every 30s by default. When the main isolate freezes, heartbeats
stop — the gap between the last healthy heartbeat (T1) and the first
following record (T2) is the frozen window. `logsAvailable == false` means
the write chain degraded (capture/presentation continue unaffected). The
log path resolves via the exe-root → Application Support fallback chain in
`error_log_location.dart`.

---

## 4. Windows WER LocalDumps 注册表配置建议(零代码原生崩溃兜底)

**Windows WER LocalDumps registry setup (zero-code native-crash fallback)**

为捕获 §2 所述的原生崩溃,可启用 Windows Error Reporting 的 LocalDumps。
**零代码**:只改注册表,不碰本项目任何代码;与 error.log **互不替代**
(error.log 管 Dart 层可定位错误,dump 管 native 层进程现场)。

**注册表键位(管理员权限):**

```
HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps\simple_player.exe
```

- 全局兜底可省略 `\simple_player.exe` 子键(对所有应用生效);建议建
  per-app 子键只兜本项目。
- 用户级替代:`HKCU\...\LocalDumps` 同结构(HKLM 需管理员,二选一)。

**建议值:**

| 值名称 | 类型 | 建议值 | 说明 |
|--------|------|--------|------|
| `DumpFolder` | REG_EXPAND_SZ | `%LOCALAPPDATA%\CrashDumps` | dump 落点目录(需已存在或 WER 自动创建) |
| `DumpType` | REG_DWORD | `2` | 2 = 完整转储(可符号化分析);1 = minidump(体积小,信息少) |
| `DumpCount` | REG_DWORD | `10` | 最多保留 10 份,自动滚动淘汰最旧 |

**与本项目的配合读数:**

1. 原生崩溃发生后,先查 `DumpFolder` 下是否有新 `simple_player.exe.<pid>.dmp`;
2. 用 WinDbg/VisualStudio 打开 dump,`!analyze -v` 定位崩溃模块
   (预期常落在 libmpv/FFI 相关 DLL);
3. 同时检查 error.log 的最后心跳时间戳(§3 方法)——若最后记录远早于
   崩溃时刻且无错误行,即印证「原生崩溃不经 Dart 钩子」的边界(§2)。

> 本文档仅含公开机制与注册表路径,不含密钥或本机敏感信息。
> This document contains only public mechanisms and registry paths.
