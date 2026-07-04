# Phase 21: Kernel Engine & Bridge Documentation - Discussion Log

**Date:** 2026-07-04
**Mode:** Default (interactive)

---

## Area 1: MDK/Win32 领域知识深度

**Question:** D3D11 参数（sync.cpu、video.decoders）、FFmpeg 滤镜语法、Win32 API 等领域知识的注释深度？

**Options presented:**
1. 简要说明（what only）— 只解释参数做什么
2. 原理说明（what + why）— 解释参数含义 + 为什么这样配置 ← **Selected**
3. 原理 + 外部引用 — 原理 + @see 链接到 MDK/mpv 文档

**Decision:** what + why 深度。解释参数含义 AND 为什么选择这个值。

---

## Area 2: 注释语言与格式

**Question:** Engine/Bridge 层注释用什么语言？

**Options presented:**
1. 混合：doc 英文 + 行内中文 — 类级 doc comment 英文，行内 why 注释中文 ← **Selected**
2. 全中文 — 所有注释用中文
3. 全英文 — 所有注释用英文

**Decision:** 混合语言。`///` doc comment 用英文，行内 `//` why 注释用中文。

---

## Area 3: 魔法数字处理策略

**Question:** D3D11 参数值、超时时间、缓冲区大小等魔法数字怎么处理？

**Options presented:**
1. 提取为命名常量
2. 保留原值 + why 注释 ← **Selected**
3. 混合：配置常量 + 内联注释

**Decision:** 保留原始值 + 行内 why 注释。例外：同一数字出现 3+ 次则提取为文件级常量。

---

## Area 4: 现有注释质量审计

**Question:** 现有注释质量参差不齐 — 怎么处理已有注释的文件？

**Options presented:**
1. 先审计再动手 — 扫描 16 文件标记质量差距，再分批处理 ← **Selected**
2. 统一重写 — 不看现有注释，统一按标准重写
3. 只补充不改 — 只补充缺失的注释，保留现有注释不动

**Decision:** 先审计再动手。分类：A 类（重写）、B 类（补充）、C 类（跳过）。

---

## Summary

**Decisions captured:** 14 (D-01 through D-14)
**Deferred ideas:** None
**Claude's discretion:** 审计后分批策略、行内注释措辞

---

*Discussion completed: 2026-07-04*
