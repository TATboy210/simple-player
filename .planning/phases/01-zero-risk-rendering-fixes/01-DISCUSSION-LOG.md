# Phase 1: Zero-Risk Rendering Fixes - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-23
**Phase:** 1-Zero-Risk Rendering Fixes
**Areas discussed:** fvp parameter format, configuration path, cleanup scope

---

## fvp Parameter Format

| Option | Description | Selected |
|--------|-------------|----------|
| List 格式 | `fvp.registerWith(options: {'video.decoders': ['MFT:d3d=11', 'NVDEC', 'D3D11:shader_resource=1', 'FFmpeg']})`。与 fvp 官方示例一致，最安全。 | ✓ |
| 逗号分隔字符串 | 保持 `join(',')` 逗号分隔字符串，修改 platform_decoders.dart 返回类型。与 MDK 文档的逗号分隔格式一致。 | |
| You decide | 让 Claude 根据 fvp 文档选择最合适的格式 | |

**User's choice:** List 格式 (Recommended)
**Notes:** 与 fvp 官方 README 示例一致，最安全的选择。

---

## Configuration Path

| Option | Description | Selected |
|--------|-------------|----------|
| 全部走 registerWith | shader_resource 嵌入 D3D11 解码器名，log 通过 registerWith options 全局设置。所有配置集中在 main.dart 初始化。 | ✓ |
| 混合模式 | shader_resource 嵌入解码器名，但 log 在 FvpEngine 构造时通过 _player.setProperty('log', 'warning') 设置。保持现有模式。 | |
| You decide | 让 Claude 根据代码结构选择 | |

**User's choice:** 全部走 registerWith (Recommended)
**Notes:** 集中配置，初始化时一次性设置。

---

## Cleanup Scope

| Option | Description | Selected |
|--------|-------------|----------|
| 删文件 + 删目录 | 删除 lib/models/playlist_item.dart + 删除空的 lib/models/ 目录。该目录仅此一个文件，所有导入都指向 lib/kernel/models/playlist_item.dart。 | ✓ |
| 只删文件 | 只删文件，保留空目录以防将来需要。 | |
| 延迟清理 | 这次先不动，等 Phase 5/6 一起清理。 | |

**User's choice:** 删文件 + 删目录 (Recommended)
**Notes:** 目录下只有这一个文件，确认安全删除。

---

## Claude's Discretion

无 — 所有灰色地带用户已明确选择。

## Deferred Ideas

None — discussion stayed within phase scope.
