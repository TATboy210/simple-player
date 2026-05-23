# Phase 1: Zero-Risk Rendering Fixes - Context

**Gathered:** 2026-05-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Apply zero-risk fvp configuration fixes that eliminate known rendering inefficiencies (D3D9→D3D11 surface copy, CPU-side YUV decoding, debug string overhead) and remove dead code. No profiling needed — these are safe, verifiable changes.

</domain>

<decisions>
## Implementation Decisions

### fvp Parameter Format
- **D-01:** `video.decoders` 改为 **List 格式**（与 fvp 官方示例一致），替代当前错误的 `join(':')` 冒号分隔字符串
- **D-02:** `shader_resource=1` 嵌入解码器名：`D3D11:shader_resource=1`（MDK API 支持 `name:key=val` 格式）

### Configuration Path
- **D-03:** 所有 fvp 渲染配置集中在 `registerWith(options:)` 全局设置，不走 `_player.setProperty()` 逐实例路径
- **D-04:** `log=warning` 作为 `registerWith` options 的全局属性（MDK 全局日志级别）

### Dead Code Cleanup
- **D-05:** 删除 `lib/models/playlist_item.dart`（26 行，零导入）+ 删除空的 `lib/models/` 目录
- **D-06:** 所有活跃导入已指向 `lib/kernel/models/playlist_item.dart`（6 个文件确认）

### Claude's Discretion
无 — 所有灰色地带用户已明确选择。

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### fvp Configuration
- `.planning/research/STACK.md` — fvp 配置优化详情、D3D11 管线、DevTools profiling
- `.planning/research/PITFALLS.md` — #3 d3d11.sync.cpu 撕裂风险（Phase 3 范围）
- `reference_fvp_optimization_plan.md`（memory）— 3 层优化方案、Tier 1 应用层代码示例
- `reference_fvp_source_structure.md`（memory）— MDK API 完整属性表、decoder 格式 `name1,name2:key=val`

### Dead Code
- `.planning/codebase/CONCERNS.md` — ThumbnailService 静态单例、silent exception swallowing（Phase 6 范围）

### fvp API Documentation
- Context7: `/wang-bin/fvp` — registerWith options、video.decoders List 格式

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/kernel/utils/platform_decoders.dart` — 解码器配置函数，需要修改 MFT:d3d=1→11 和 List 格式
- `lib/main.dart` — fvp 初始化入口，需要扩展 registerWith options
- `lib/kernel/engine/fvp_engine.dart` — 已有 `_player.setProperty()` 模式可参考（但本次不需要改）

### Established Patterns
- `fvp.registerWith(options: {'video.decoders': ...})` — 当前初始化模式，扩展 options map 即可
- `getOptimalDecoders()` 返回 `List<String>?` — 返回类型已经是 List，只需改 join(':') 调用

### Integration Points
- `main.dart:14` — `fvp.registerWith()` 调用点，所有配置变更集中在此
- `platform_decoders.dart:12` — Windows 解码器列表，MFT:d3d=1 需改为 d3d=11

</code_context>

<specifics>
## Specific Ideas

- fvp 文档明确 `video.decoders` 接受 List，当前 `join(':')` 是格式错误
- `D3D11:shader_resource=1` 是 MDK 解码器属性语法，嵌入解码器名即可
- `log=warning` 是 MDK 全局属性，应通过 registerWith options 设置

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 1-Zero-Risk Rendering Fixes*
*Context gathered: 2026-05-23*
