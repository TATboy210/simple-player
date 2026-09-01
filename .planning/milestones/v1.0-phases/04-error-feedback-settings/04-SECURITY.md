---
phase: "4"
slug: "error-feedback-settings"
status: complete
threats_open: 0
asvs_level: 1
created: "2026-09-01"
---

# Phase 4 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.
> Register authored at plan time (all 5 PLAN.md carried `<threat_model>`,含 T-01-13/19 逐计划 re-verify 行);verified L1 (threats_open=0 short-circuit + 既有测试套件证据)。
> 注:D-07(2026-09-01)移除路径配置 UI 后,T-04-02-01/T-04-04-01 的 UI 呈现面收窄,但校验实现保留为内部探测(设置 store WR-06 回退层复用)——缓解有效性不变,攻击面只减不增。

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| settings.json → 解析/写路径 | 手编/损坏文件不得成为启动阻断或写路径注入 | JSON 键值(形状校验 + 逐字段类型) |
| validateConfiguredDirectory → sink 激活 | 校验即证明 sink 真正要做的操作(create+probe) | 目录路径 |
| UI TextField → apply | UI 不做第二套校验,信任单一校验实现 | 目录路径(输入即校验,后经 D-07 移除) |
| logging isolate ↔ 主 isolate | 记录经 SendPort 跨 isolate,子 isolate 持文件句柄 | 纯 String 记录(格式化留主侧) |
| 诊断包 → 剪贴板/资源管理器 | 完整路径按 D-07 进复制包与 explorer 参数 | 完整媒体路径(开发机接受) |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-04-01-01 | Tampering / Elevation | settings.json → 写路径 | medium | mitigate | is! Map 守卫 + 逐字段类型校验(损坏矩阵测试);路径由 validateConfiguredDirectory + probe 纵深把守;解析异常静默回退默认值 | closed |
| T-04-01-02 | DoS | store 启动路径 I/O | low | mitigate | load 在 unawaited 路径内,构造器同步零 I/O;保存 fire-and-forget;异常收窄捕获 | closed |
| T-04-02-01 | Tampering / Elevation | validateConfiguredDirectory → 写路径 | medium | mitigate | 校验即证明(create+probe);封闭原因枚举;UNC(双斜杠形态)/控制字符/1024 上界拒绝;探测失败永不激活(WR-03/04 修复后单一契约,启动配置层同校验) | closed |
| T-04-02-02 | DoS | dispose→activate 换位窗口 | low | mitigate | resolve 先于 dispose;间隙记录 pending FIFO(32)保序;WR-01 后 apply 全序列化(链式 Future + activate 读回) | closed |
| T-04-02-03 | Information Disclosure | 有效路径/回退原因展示 | low | accept | 仅呈现给本机用户(特性本身);D-07 后 UI 呈现面已移除,缓解面缩小 | closed (accepted) |
| T-04-03-01 | DoS | 门控状态与呈现链 | low | accept | 纯布尔渲染分支;有界快照(20)/FIFO(5)不变;损坏文件默认值兜底 | closed (accepted) |
| T-04-03-02 | Repudiation | 关卡片后错误可回溯 | low | accept | off 期间照常落盘由测试锁死;日志文件证据链不断 | closed (accepted) |
| T-04-04-01 | Tampering | TextField → apply | medium | mitigate | UI 零第二套校验(单一实现信任);非法输入三不保证由协调器 + UI 测试锁死;D-07 后该输入面整体移除 | closed |
| T-04-04-02 | DoS | 防抖 Timer / picker await | low | mitigate | 300ms 防抖合并;dispose cancel;context.mounted 守卫;file_picker 异常收窄 | closed |
| T-04-04-03 | Information Disclosure | 有效路径展示 | low | accept | 本机用户;纯 Text 渲染;D-07 后移除 | closed (accepted) |
| T-04-05-01 | Information Disclosure | 被移除面 | low | accept | 纯移除缩小呈现面,无新增信息流 | closed (accepted) |
| T-04-05-02 | Tampering | 手编残留第三键 | low | accept | is! Map 守卫 + 逐字段校验天然忽略未知键(损坏矩阵锁定) | closed (accepted) |
| T-04-05-03 | Tampering | 包安装 | high | mitigate | 零包管理器任务;pubspec 零 diff 门(Task 3 实测过) | closed |
| T-01-13 | Elevation of Privilege | diagnostics 子系统 | low | re-verified | **Phase 1 遗留债务收账**:4 个计划逐条复核一致——写路径只产出诊断包纯文本,新增耦合面(settings.json→写路径/isolate 传输)未使 retained 串获得执行/解释/传输能力;维持 low/accept | closed |
| T-01-19 | Elevation of Privilege | diagnostics 子系统 | low | re-verified | 同 T-01-13;呈现门控/isolate 化未新增 retained 串 sink;维持 low/accept | closed |
| T-04-*-SC | Supply Chain | 依赖安装(×5 plans) | high | accept | 五计划均零新包安装,pubspec 零 diff 门实测 | closed (accepted) |

*Status: open · closed · open — below high threshold (non-blocking)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-04-1 | T-04-02-03 / T-04-04-03 | 路径展示给本机用户(特性本身;D-07 后 UI 面已移除) | user (D-04 讨论) | 2026-08-31 |
| AR-04-2 | T-04-03-01/02 | 关卡片后错误仍落盘可回溯——证据链保留是有意行为 | user (D-05 讨论) | 2026-08-31 |
| AR-04-3 | T-04-*-SC | 零新增依赖,供应链面未扩大 | user (plan approval) | 2026-08-31 |

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-09-01 | 16 (含 T-01-13/19 收账) | 16 | 0 | orchestrator (L1 short-circuit: threats_open=0, register at plan time, ASVS L1) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] **T-01-13/19(Phase 1 遗留)正式收账**
