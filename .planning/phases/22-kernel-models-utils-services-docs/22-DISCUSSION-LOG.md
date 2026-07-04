# Phase 22: Kernel Models, Utils & Services Documentation - Discussion Log

**Date:** 2026-07-05
**Mode:** Default (interactive)

---

## Area 1: app_settings.dart 字段文档粒度

**Question:** app_settings.dart 有 25+ 个字段（volume、lastFile、windowWidth 等），全部没有文档。注释粒度怎么定？

**Options presented:**
1. 每个字段都加 doc comment — 25+ 字段全部加 `///` 注释，说明用途、取值范围、单位 ← **Selected**
2. 分组注释 + 关键字段详细 — 用 `// --` 分组标记，只对非自明字段加 `///`
3. 只注释有歧义的字段 — 只给取值范围/单位不明确的字段加注释

**Decision:** 每个字段都加 doc comment。最完整，确保 IDE hover 提示对所有字段可用。

---

## Area 2: 注释语言规则

**Question:** Phase 21 确立了混合语言规则（/// 英文 + // 中文）。Phase 22 继续沿用还是调整？

**Options presented:**
1. 沿用 Phase 21 规则 — `///` doc comment 英文，行内 `//` why 注释中文 ← **Selected**
2. 全中文
3. 全英文

**Decision:** 沿用 Phase 21 混合语言规则。与 Phase 21 保持一致，`///` 英文（国际化友好），`//` 中文（代码库惯例）。

---

## Area 3: 样板方法文档

**Question:** copyWith()、operator ==、hashCode 等样板方法需要加 doc comment 吗？

**Options presented:**
1. 跳过 — 语义由签名自解释，不加 doc comment ← **Selected**
2. 简短一行 — 每个加一行 `///` doc comment

**Decision:** 跳过样板方法。Phase 21 对类似情况也跳过了，保持一致。

---

## Area 4: 文件路径修正

**Audit 发现：** REQUIREMENTS.md 中 DOC-26~DOC-32 的文件路径有 4 个不正确。

| DOC ID | REQUIREMENTS.md 路径 | 实际路径 |
|--------|---------------------|---------|
| DOC-29 | `lib/kernel/services/startup_coordinator.dart` | `lib/kernel/startup/startup_coordinator.dart` |
| DOC-30 | `lib/kernel/services/startup_state.dart` | `lib/kernel/startup/startup_state.dart` |
| DOC-31 | `lib/kernel/scanner/folder_scanner.dart` | ✓ 正确 |
| DOC-32 | `lib/kernel/services/settings_validator.dart` | `lib/kernel/persistence/settings_validator.dart` |

**Decision:** 使用实际路径，不修改 REQUIREMENTS.md（避免干扰其他流程）。

---

## Area 5: 审计分级结果

**Audit 发现 16 个文件的注释质量分级：**

| 文件 | 分级 | 缺失 |
|------|------|------|
| app_settings.dart | **A** | 25+ 字段零文档，默认值无解释 |
| aspect_ratio_mode.dart | **B** | mdk 特殊常量无行内解释 |
| validation_error.dart | **B** | 2 个字段缺 doc comment |
| player_error.dart | **B** | 3 个字段缺 doc comment |
| perf_monitor.dart | **B** | 2 个魔法数字无解释 |
| locale_service.dart | **B** | 3 个成员缺 doc comment，'zh' 硬编码 |
| startup_coordinator.dart | **B** | 1 个方法缺 doc comment |
| startup_state.dart | **B** | 5 个成员缺 doc comment |
| folder_scanner.dart | **B** | 3 个字段缺 doc comment |
| debug_probe.dart | **C** | 已达标 |
| memory_monitor.dart | **C** | 已达标 |
| debug_exporter.dart | **C** | 已达标 |
| screen_utils.dart | **C** | 已达标 |
| global_hotkey_service.dart | **C** | 已达标 |
| thumbnail_service.dart | **C** | 已达标 |
| settings_validator.dart | **C** | 已达标 |

**Decision:** A 类全面补充，B 类针对性补充，C 类跳过。共 9 个文件需要修改。

---

## Summary

**Decisions captured:** 5 areas
**Deferred ideas:** None
**Claude's discretion:** 具体行内注释措辞、分批策略

---

*Discussion completed: 2026-07-05*
