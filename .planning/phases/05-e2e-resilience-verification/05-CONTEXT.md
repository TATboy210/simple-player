# Phase 5: 端到端韧性验证 - Context

**Gathered:** 2026-09-01
**Status:** Ready for planning

<domain>
## Phase 5 Boundary

验证收尾阶段:把 Phase 1–4 已积累的自动化测试与实机 UAT 证据**正式归档为 VER-01~05 的验收证据**,补齐唯一缺口(四源端到端整合注入用例),产出 VER-05 开发者文档。**不是重验阶段**——已有证据按采信边界归档,避免与既有测试套件重复劳动。

</domain>

<decisions>
## Implementation Decisions

### 证据采信边界
- **D-01:** VER-01/02/03 的已有测试作为**主证据直接归档**(Phase 1:burst/去重/zone/hooks 测试;Phase 3:卡片用例、CARD-04 失败隔离、复制/关闭三不保证;Phase 4:门控/持久化/重定向序列化);仅补**一个**四源整合注入用例(四源各一条 → 各产一份报告+文件证据+卡片呈现断言,锁死端到端);Phase 3/4 的 UAT 实机记录作佐证引用 — **Reversibility:** reversible
- **D-02:** VER-04 Windows 实机冒烟 = **正式归档 Phase 3/4 UAT 已确认内容**(标题拖动/控制/键盘/全屏/复制/打开日志——04-UAT 与 03-UAT 记录在案),不重跑完整清单;规划时盘点是否有移除后未覆盖的点,有则列入实机核对清单(预count:无已知缺口) — **Reversibility:** reversible
- **D-03:** VER-02 爆发压测形态 = **纯自动化**(fake_async/WidgetTester 驱动 100–1000 合成事件),断言:快照 ≤20(设计值)、FIFO ≤5(设计值)、去重合并生效、丢弃有计数、写盘受控(单写者链不断)、测试内 pump 响应不卡;**不加实机轮**(实机注入入口已按 D-07 移除,不为压测重建) — **Reversibility:** reversible
- **D-04:** 爆发通过口径 = **设计值口径**:有界 = 快照 ≤20、FIFO ≤5、丢弃/合并计数可见;无 unhandled error;写盘受控 = 单写者链不断、无并发写冲突。**不另设** profile/内存曲线阈值(那属后端优化轮) — **Reversibility:** reversible
- **D-05:** VER-05 文档 = **开发者文档**(落点 docs/,具体文件名 planner 定),内容:release 源码/符号降级策略、Dart 钩子无法捕获 libmpv/FFI 原生进程崩溃的边界说明、当前 isolate 写盘语义与卡死时间窗读数方法、Windows WER LocalDumps 注册表配置建议(零代码原生崩溃兜底)。中文双语,开发者自助排障向 — **Reversibility:** reversible

### Claude's Discretion
- 四源整合注入用例的落位与命名(建议 test/diagnostics/end_to_end_injection_test.dart)
- 归档清单的组织形式(证据映射表:VER 项 → 测试文件/用例名/UAT 记录引用)
- VER-05 文档的文件名与章节结构
- 「补一用例」若发现既有用例已覆盖四源整合,可降级为「引用既有」(以测试实况为准,不重复造轮子)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 项目规划文档
- `.planning/REQUIREMENTS.md` — VER-01~05 需求全文
- `.planning/ROADMAP.md` — Phase 5 Goal(User Story)与 5 条成功标准
- `.planning/phases/03-playback-error-card-bridge/03-UAT.md` — VER-04 归档证据源(实机确认记录)
- `.planning/phases/04-error-feedback-settings/04-UAT.md` — VER-04 归档证据源(开关/持久化/MSIX/并发)

### 代码事实源
- `test/diagnostics/` 全目录 — VER-01/02/03 主证据(尤其 error_reporter_test 的 burst/去重/限流、global_error_hooks_test 的 zone 一致性、player_error_report_bridge_test 的桥接)
- `test/widget/player/error_card_host_test.dart` — 门控/快照语义
- `test/diagnostics/error_log_file_sink_test.dart` + `isolated_error_log_sink_test.dart` — 写盘受控/顺序/失败隔离
- `lib/kernel/diagnostics/` — 被验证的实现(isolate 写盘、单写者链、去重)
- `tool/audit/kernel_logger_gate.sh` — 结构门禁

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- 既有测试套件即主证据(burst/去重/zone/失败隔离/门控/持久化/重定向——各 phase 已全绿)
- `ErrorReporterImpl` 注入 seam(test hooks)+ fake_engine/fake fixture 惯例:四源整合用例的注入机制
- 03/04 UAT 实机记录:VER-04 归档证据
- `tool/audit/` 脚本:结构门禁可直接引用

### Established Patterns
- 中文双语 doc comment、AAA 测试结构、headless 全绿红线
- 证据引用格式:测试文件#用例名(可 grep 定位)

### Integration Points
- 无新产品代码——本 phase 产出 = 整合测试用例 + 归档文档 + VER-05 开发者文档
- 唯一代码触碰面 = 新测试文件(不改产品实现)

</code_context>

<specifics>
## Specific Ideas

无特殊外部引用

</specifics>

<deferred>
## Deferred Ideas

- **错误卡片前端视觉重设计** — 桌面交接文档,外部设计 AI 流程(milestone 收尾后或并行)
- **后端持续优化轮** — profile 驱动独立立项(Phase 5 后)

</deferred>

---

*Phase: 5-端到端韧性验证*
*Context gathered: 2026-09-01*
