# Phase 17 Discussion Log

**Date:** 2026-07-19
**Phase:** 17 — 零依赖 KernelLogger 门面（替换迁移）

## Area 1: LogSink 注入与接线时机

| # | Question | Options | Selection |
|---|----------|---------|-----------|
| 1 | 84 调用点如何访问 KernelLogger？ | 构造注入 / 静态注册 / 经 DiagnosticsBundle | **静态注册** — KernelLogger.I，迁移最简 |
| 2 | P17 何时激活 bundle 的 logger slot？ | P17 激活 / bundle 全 noop 直到 P20 | **P17 激活** — LOG-04 可插拔需求 |
| 3 | 何时在 player_services.dart 接线？ | P17 接线 / P20 才接线 | **P17 接线** — 范围内闭环 |
| 4 | LogSink 接口形态？ | 6 方法 / 单 log 方法 / 无 LogSink | **单 log 方法 + level 参数** |
| 5 | 旧 log.dart 如何处理？ | 内核替换，app 保留 / 全部替换 | **内核替换，app 保留** |
| 6 | LogSink 接口和实现放哪里？ | 全在 kernel_logger.dart / 拆 3 文件 | **全在 kernel_logger.dart** |
| 7 | KernelLogger 如何获得 LogSink？ | 构造注入 / 静态可变 | **构造注入 LogSink** |
| 8 | KernelLogger.I 生命周期？ | 一次性设置 / 可运行时替换 | **一次性设置，不可替换** |

## Area 2: 迁移策略与 error/fatal 签名扩展

| # | Question | Options | Selection |
|---|----------|---------|-----------|
| 1 | 84 处调用点迁移节奏？ | 一次性批量 / 按级别分批 | **一次性批量替换** |
| 2 | error()/fatal() 是否扩展命名参？ | 扩展 / 不扩展，context 承载 | **扩展 `{Object? error, StackTrace? stackTrace}`** |
| 3 | CI grep 闸门何时启用？ | P17 完成后立即 / 留 P21 | **P17 完成后立即启用** |
| 4 | 84 处调用点替换方式？ | 脚本自动 / 手动逐文件 | **脚本自动替换** |
| 5 | 30 文件 `final log = Logger('...')` 处理？ | 保留 log 变量只改类型 / 全改调用名 | **保留 log 变量，只改类型** |
| 6 | 84 处调用点方法名怎么改？ | 全称化 / 保留快捷方法 | **保留快捷方法** — w()/e()/i()/d()/t()/f() |

## Area 3: sink 分级与 release 门控策略

| # | Question | Options | Selection |
|---|----------|---------|-----------|
| 1 | debug 模式输出？ | debugPrint 一线 / 双 sink / dart:developer 一线 | **debugPrint 一线** |
| 2 | release 构建？ | NullSink + kDebugMode / dart:developer release 仍可用 | **NullSink + kDebugMode 门控** |
| 3 | LogLevel 级别数？ | 6 级 / 3 级简化 | **6 级枚举** |
| 4 | Map context 格式化？ | 追加到消息字符串 / JSON 结构化 | **追加到消息字符串** |

## Area 4: dart:developer 配置与 path 脱敏

| # | Question | Options | Selection |
|---|----------|---------|-----------|
| 1 | dart:developer.log name 参数？ | 'SimplePlayer' / 'Kernel' / 模块名 | **'Kernel'** |
| 2 | 文件路径脱敏？ | 文件名 only / 相对路径 / 不脱敏 | **文件名 only** |

---

*17 questions across 4 areas. All selections by user.*
