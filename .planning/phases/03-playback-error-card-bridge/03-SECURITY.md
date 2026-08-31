---
phase: "3"
slug: "playback-error-card-bridge"
status: complete
threats_open: 0
asvs_level: 1
created: "2026-08-31"
---

# Phase 3 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.
> Register authored at plan time (all 4 PLAN.md carried `<threat_model>`); verified L1 (grep-depth + existing test suite evidence).

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| ErrorReport → 卡片 UI | 捕获侧已脱敏,渲染层是最终防线 | message/mediaPath(脱敏后)/stack |
| 宿主 ↔ 调度器 | build 期同步发布不得直 setState | 内部状态 |
| app builder Stack ↔ Navigator | 挂载层高于全部 route,命中矩形过大将吞全应用点击 | 输入事件 |
| 诊断包 → 系统剪贴板 | 完整路径按 D-07 进入复制包 | 完整媒体路径(开发机接受) |
| 删除操作 ↔ 仓库完整性 | MIG-01 删除牵连三处引用 | 源码结构 |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-03-01 | Information Disclosure | ErrorCard 渲染 | high | mitigate | 只渲染 reporter 已脱敏字段;CARD-03 测试断言脱敏边界;review 对抗检查通过 | closed |
| T-03-02 | Tampering | 错误文本渲染 | medium | mitigate | 纯 `Text` 渲染,intake 限界 4096 | closed |
| T-03-03 | Denial of Service | ErrorCardHost 调度 | high | mitigate | SchedulerPhase 守卫 + post-frame 重读;CARD-05 故障注入测试锁死 | closed |
| T-03-04 | Denial of Service | 挂载层 hit-test | high | mitigate | 内在尺寸 Positioned;穿透测试锁死;CR-01 约束修复后生产挂载方式回归测试(宽≤420/外点穿透) | closed |
| T-03-05 | Information Disclosure | 展开区渲染 | high | mitigate | 可见树不渲染完整媒体路径;widget 测试锁死;review 对抗检查通过 | closed |
| T-03-06 | Denial of Service | 命中边界 | high | mitigate | 双向 hit-test 测试 + VER-04 实机复测用户确认(2026-08-31 Test 2 pass) | closed |
| T-03-07 | Denial of Service | 焦点抢占 | medium | mitigate | ExcludeFocus + primaryFocus 不变断言;CR-02/焦点用例全绿 | closed |
| T-03-08 | Information Disclosure | 剪贴板诊断包 | medium | accept | D-07 批准开发机本地证据含完整路径;单用户本机场景 | closed (accepted) |
| T-03-09 | Denial of Service | warning 分流 | medium | mitigate | 恰好一次 dismiss + 防重建循环测试 | closed |
| T-03-10 | Tampering | 轮览/队列状态混淆 | medium | mitigate | 轮览为纯视图偏移;调用计数断言;WR-01 收敛一致性测试 | closed |
| T-03-11 | Denial of Service | 复制异常外溢 | medium | mitigate | typed catch;WR-02 补 isInitialized 守卫防 catch 内二次抛出 | closed |
| T-03-12 | Tampering | 等效判定 | high | mitigate | 断言 helper 双路径共用;删除前 6/6 双路径全绿硬门(372b10a9) | closed |
| T-03-13 | Denial of Service | 删除残留引用 | high | mitigate | grep 门零匹配 + widget 全目录 + analyze 三重收尾(0805618b) | closed |
| T-03-14 | Repudiation | 迁移决策留痕 | low | mitigate | 等效测试头注释 + 独立 commit 留 diff 审阅 | closed |
| T-03-SC | Tampering | 依赖供应链(×4 plans) | low | accept | 四计划均零新增依赖 | closed (accepted) |

*Status: open · closed · open — below high threshold (non-blocking)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-03-1 | T-03-08 | 诊断包含完整媒体路径进剪贴板——开发机单用户场景,D-07 用户拍板 | user (D-07) | 2026-08-30 |
| AR-03-2 | T-03-SC | 零新增依赖,供应链面未扩大 | user (plan approval) | 2026-08-30 |

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-08-31 | 14 | 14 | 0 | orchestrator (L1 short-circuit: threats_open=0, register at plan time, ASVS L1) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
