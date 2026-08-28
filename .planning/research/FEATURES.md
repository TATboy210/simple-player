# Feature Research

**Domain:** 面向开发者的 Flutter Windows 桌面应用错误捕获、诊断与非模态反馈系统
**Researched:** 2026-08-28
**Confidence:** MEDIUM

## Feature Landscape

这里的“错误卡片”不是短暂、不可回看的系统 toast，也不是会夺走焦点的对话框；它是应用内左上角、可见且可关闭的诊断入口。成熟工具通常将职责拆开：VS Code 用短暂通知提醒、Problems 呈现可导航的问题集合、Output 呈现完整日志；VLC 则通过 Messages 窗口和可提高的日志详细度供排障。因此本项目应让卡片承担“即时发现 + 立即复制”，让纯文本日志承担“完整回溯”，而不把两者混成一个庞大的诊断工作台。

### Table Stakes (Users Expect These)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **明确、可读的错误摘要** | 用户必须知道发生了什么、影响了哪个操作/媒体、是否仍能继续；泛化的“发生错误”无法支持恢复。 | LOW | 卡片第一屏应有严重级别文本/图标、简短摘要、受影响媒体路径（有则显示）及时间；颜色只能是辅助，不能是唯一信号。不要把原始异常作为唯一标题。 |
| **定位信息与技术详情的渐进披露** | 开发者需要准确定位，而普通播放路径不应被长堆栈淹没。 | MEDIUM | 默认显示 `文件:行号`（可得时）和错误来源；展开后显示源码行、完整 stack trace、错误类型与原始消息。release 或无法读源码时隐藏“源码行”区，仅保留可得的定位/调用栈，不显示“读取失败”噪声。 |
| **一键复制完整、稳定的诊断包** | VS Code 的输出通道和 VLC 的 Messages 均把可收集的完整日志作为排障基础；复制是无调试器时最快的交接路径。 | LOW | 一个 `复制诊断信息` 动作复制结构化纯文本：时间、severity、来源、错误、媒体路径、文件:行号、源码行（可得时）、堆栈、日志路径。复制成功给短暂确认，不改变卡片状态。 |
| **明确关闭且不丢失记录** | 非模态反馈必须让用户继续播放和操作；关闭 UI 不应等同于忽略或删除错误。 | LOW | `关闭` 仅移除当前卡片；错误已先写入内存状态与日志。卡片不开自动消失计时器，符合项目“常驻手动关”决定，避免用户正在复制时信息消失。 |
| **受控的多错误队列、计数与顺序** | 错误可能连发。VS Code 的准则是一次呈现一个通知、合并重复通知，避免注意力轰炸。 | MEDIUM | 左上角仅展示一个 active card；新事件进入 FIFO 队列，卡片显示“第 n / 共 N 条”或“另有 N 条”，关闭后显示下一条。限制内存队列上限并保留溢出日志；不要并列堆叠遮挡内容。 |
| **重复错误合并/抑制** | 同一引擎错误或循环异常若每次开新卡，会使系统看起来坏掉且掩盖根因。 | MEDIUM | MVP 采用保守指纹（错误类型 + 原始消息 + 首个项目栈帧/来源）；在短时间窗口内命中则更新重复次数与最后发生时间，不新建卡片。不同媒体路径或不同首帧不能误合并。完整每次事件仍可写日志，或至少记录计数，保证可追溯性。 |
| **可区分的严重级别** | 成熟工具把 info/warning/error 分级；用户需要分辨“播放本身失败”和“可恢复的诊断提示”。 | LOW | MVP 仅需 `warning` 与 `error`（可预留 enum）；错误卡视觉、无障碍标签、日志前缀一致。不要为了完整性引入多级告警策略或弹窗升级规则。 |
| **日志路径可见，且卡片与日志互相可达** | VLC 要求获得完整日志，VS Code 用 Output channel 做持久技术输出；卡片应告诉开发者完整证据在哪里。 | LOW | 卡片详情显示实际写入文件路径；`复制诊断信息` 含路径。日志写入失败应以安全的内存/UI 降级呈现，不能因记录失败递归生成无限错误卡。 |
| **无障碍与键盘可用性** | 动态错误不能只靠红色和滑入动画；不应强制抢焦点，也必须可被辅助技术发现。 | MEDIUM | 使用清楚的文本语义和 severity 标签；卡片不抢播放控件焦点。提供可聚焦的复制/关闭动作、可读语义标签和足够对比度；新卡出现时以非破坏方式宣布状态。 |
| **显示开关与持久化边界** | 个人桌面开发工具需要控制视觉噪声，但关闭显示不应造成诊断黑洞。 | LOW | 设置“错误卡片”开关默认开；关闭只抑制卡片，继续捕获及错误日志落盘。日志输出路径可配置，并验证路径可写；无效路径回退到默认安全路径且记录原因。 |

### Differentiators (Competitive Advantage)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **项目源码行 + 可定位的首个项目栈帧** | 通用媒体播放器通常只告诉用户“无法播放”；本项目能在无需附加调试器时直接指出自身代码方位，正对“出错可定位”核心价值。 | MEDIUM | 过滤 Flutter/Dart SDK 与 package 帧，优先项目 `lib/` 首帧；源码读取必须有边界、异常隔离与 release 降级。虽属市场差异化功能，但因本里程碑目标而列为 P1。 |
| **统一的跨来源错误上下文** | UI/框架、异步未捕获、启动期、播放器引擎事件最终有相同字段与相同卡片，使开发者不用猜错误来自哪条旁路。 | MEDIUM | 统一事件模型应含来源、severity、时间、error/stack、媒体路径、定位和可选底层上下文。来源是事实字段，不用四套独立 UI。 |
| **卡片—纯文本日志的可复制关联** | 让即时画面、可分享诊断包和长期日志三者互相对应，兼具 VS Code 的即时反馈与 VLC 的日志回溯，而不需要内置复杂日志工作台。 | MEDIUM | 每条记录可有稳定事件 ID；复制内容和日志行共享该 ID。单文件追加、仅 error/warning 上盘即可，保持人类可读。 |
| **低噪声的重复计数与根因优先排序** | 连续引擎回调或异常循环时，开发者先看到一个有次数/首次/末次时间的根因，而不是被同样卡片淹没。 | MEDIUM | 先做确定性合并，不做推测性的 AI 聚类；只有采到真实噪声后再考虑按来源排序。 |
| **详情按需展开而非全屏日志窗** | 保留播放操作空间，同时支持即时看堆栈、源码行和日志路径。 | LOW | 默认紧凑；详情是同一卡片的展开区域，不引入新的模态路由、常驻侧栏或调试控制台。 |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| **模态错误对话框 / 每次错误都抢焦点** | 看起来能保证用户“看见错误”。 | 中断播放、阻挡复制/检查当前状态，违反“避免强制式 UI”；许多错误并不需要立即决策。 | 左上角常驻、可关闭的非模态卡片；仅在继续操作绝对不安全且必须决策的未来场景才单独评估模态。 |
| **短暂自动消失 toast 作为唯一呈现** | 实现很少、视觉上干净。 | 堆栈和路径来不及复制；遗漏后无应用内反馈，尤其不适合开发者诊断。 | 手动关闭卡片 + 纯文本落盘；复制动作提供即时确认即可。 |
| **无限并列卡片堆叠** | 似乎不会漏报任何一次错误。 | 遮挡标题栏/播放器、制造注意力风暴，且相同错误无法突出根因。 | 单 active card + 有界 FIFO 队列 + 重复计数；完整证据由日志保存。 |
| **内置完整日志浏览器、筛选 DSL、实时尾随、搜索与导出中心** | 开发者常希望像 IDE 一样看日志。 | 与现有目标的“单文件追加纯文本”重复；会引入大状态面、性能/截断/检索/保留策略和额外 UI 维护，违背小即是美。 | 显示并复制日志路径；使用系统编辑器/终端读取文本日志。采集到明确痛点后再独立立项。 |
| **远程遥测、自动上传、账号/崩溃报告工作流** | 能集中看到错误并“帮助改进产品”。 | 项目明确为个人桌面应用；增加隐私、联网、授权、失败重试和数据保留义务，且媒体路径/堆栈可能敏感。 | 仅本机纯文本日志与手动复制；远程报告明确保持 out of scope。 |
| **自动重试、自动重启播放器或自动修改设置** | 希望“自动修复”。 | 错误原因可能是文件、硬件或状态机；隐式副作用会掩盖根因、重复报错甚至破坏用户播放意图。 | 如确有确定且安全的恢复动作，未来在卡片中提供显式命名的用户触发动作；当前仅展示诊断。 |
| **按异常消息进行“智能”AI 根因解释或跨版本云端聚类** | 看似能让报告更易懂。 | 低可信推断可能误导定位，且带来数据外传、费用和复杂性。 | 可靠地显示原始事实、项目首帧、源码行与堆栈；通过可复制文本支持人工分析。 |
| **把源码、完整媒体路径自动暴露在简略卡片或截图中** | 信息越多看似越方便。 | 卡片膨胀且可能泄露用户目录/文件名；普通摘要也失去可读性。 | 默认紧凑；技术细节按需展开，并在复制前明确复制的是完整诊断信息。 |

## Feature Dependencies

```text
全局错误来源接入（UI / async / startup / engine）
    └──requires──> 统一 DiagnosticEvent 模型
                           ├──requires──> 来源、时间、异常、StackTrace、媒体路径上下文
                           ├──requires──> 定位器（首个项目栈帧）
                           │                      └──enhances──> 源码行读取（可失败的可选步骤）
                           ├──requires──> 有界队列 + 重复指纹合并
                           │                      └──drives──> 单 active error card / 次数显示
                           └──requires──> FileSink 持久化
                                                  └──enhances──> 日志路径显示与复制诊断包

统一 DiagnosticEvent 模型
    └──drives──> severity 语义、无障碍语义、卡片摘要与详情

设置：显示开关 / 日志路径
    ├──controls──> 卡片渲染（不控制捕获）
    └──configures──> FileSink（路径校验与默认回退）

“关闭卡片” ──must not affect──> 已写入日志、待展示队列、后续错误捕获
```

### Dependency Notes

- **统一事件模型先于卡片：** 四个错误入口必须只做捕获和上下文补充；若每个入口自己构建 UI/日志，会立即产生字段和行为漂移。
- **定位先于源码行：** `文件:行号` 是稳定的主定位结果；读取源码只是基于该结果的增强，不能让文件 I/O 失败阻塞报告。
- **队列/合并先于动画和外观细节：** 多错误语义是功能正确性，先保证一条错误不会被下一条覆盖，再实现滑入视觉。
- **持久化先于“日志路径”动作：** 路径只有在文件写入已成功或已明确降级时才可信；FileSink 失败必须避免回流为新的相同错误。
- **显示开关不得控制捕获：** 否则用户为减少视觉干扰时会失去唯一的诊断证据，直接违背“可回溯”。

## MVP Definition

### Launch With (v1)

- [ ] **统一捕获并归一化四类错误事件** — 达成“全捕获”前提，所有来源有一致的来源、异常、堆栈、时间和当前媒体路径字段。
- [ ] **左上角单 active、手动关闭的非模态错误卡片** — 不抢焦点、不遮挡标题栏/控制栏交互区；有 severity、简短摘要、关闭和详情展开。
- [ ] **准确定位与 release 降级** — 显示项目 `文件:行号` 和可选源码行；读不到源码时仍可复制、记录、定位。
- [ ] **完整诊断包一键复制** — 复制内容可独立用于排障，含错误详情、完整堆栈、媒体路径和日志路径。
- [ ] **有界 FIFO + 保守重复合并** — 同时解决连发错误不被覆盖和重复错误不刷屏两个基本正确性问题。
- [ ] **仅错误事件的单文件纯文本追加日志** — 写入先于/独立于 UI；日志路径可见，写失败安全降级。
- [ ] **设置中的卡片显示开关与日志路径配置** — 默认显示；关卡片不关记录；路径可写性校验和默认回退。
- [ ] **键盘与辅助技术可操作** — 文字化 severity，复制/关闭可聚焦；视觉色彩不作为唯一信息载体。

### Add After Validation (v1.x)

- [ ] **更精确的合并窗口与每个来源的节流策略** — 仅当真实使用证明引擎或框架重复事件造成噪声时，基于日志样本调整；不要预设复杂策略。
- [ ] **“复制成功”与日志写入状态的细化反馈** — 若当前 OSD/轻量反馈不够明确时加入；必须不制造新的持久通知。
- [ ] **可选的“打开日志所在目录”动作** — 仅在 Windows 路径处理、安全性和体验经验证后加入；它是便利功能，不是定位链的必要环节。

### Future Consideration (v2+)

- [ ] **只读、按需打开的最小日志查看页** — 只有系统编辑器无法满足明确的现场排障需求时才评估；不发展为 IDE 式诊断平台。
- [ ] **用户触发、明确安全的重试动作** — 仅为有确定恢复语义的单一错误类型设计，必须保留诊断证据且绝不自动执行。
- [ ] **跨会话的错误摘要历史** — 只有单一文本日志的人工检索成为实测瓶颈才评估；不引入数据库、账户或远程同步。

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| 四类入口归一化 + 一致上下文 | HIGH | MEDIUM | P1 |
| 非模态单卡片、关闭和详情 | HIGH | MEDIUM | P1 |
| 文件:行号、可选源码行、完整堆栈 | HIGH | MEDIUM | P1 |
| 一键复制诊断包 | HIGH | LOW | P1 |
| 纯文本错误日志 + 可见路径 | HIGH | MEDIUM | P1 |
| 有界队列 + 重复计数 | HIGH | MEDIUM | P1 |
| severity + 无障碍语义 | HIGH | LOW | P1 |
| 设置开关 / 可配置路径 | MEDIUM | LOW | P1 |
| 打开日志所在目录 | MEDIUM | LOW | P2 |
| 来源特定节流调优 | MEDIUM | MEDIUM | P2 |
| 内置日志浏览器 | LOW | HIGH | P3 / 默认不做 |
| 遥测、云端报告、AI 聚类 | LOW | HIGH | Explicitly out of scope |

**Priority key:**
- P1: 本里程碑启动必需；其中“源码行”虽为行业差异化项，却是本项目核心价值的一部分。
- P2: 核心链路从真实使用中验证后再加的便利功能。
- P3: 只有经验证需求成立才重新评估；不是当前路线图承诺。

## Competitor Feature Analysis

| Feature | VS Code | VLC | Simple Player v2.1 approach |
|---------|---------|-----|------------------------------|
| 非阻塞即时提示 | 标准通知用于简短信息；UX 指南要求少发、合并重复，通常一次一条。 | 不以运行期卡片为重点，诊断主要进入 Messages/log。 | 左上角单 active 常驻卡片，手动关闭；绝不阻断播放操作。 |
| 严重级别 | 信息、警告、错误三类通知 API。 | 日志可通过 verbosity 扩充，默认以错误级为中心。 | warning/error 两级足够，统一影响卡片、日志和无障碍语义。 |
| 多问题呈现 | 状态栏计数、Problems 面板、编辑器内联与 overview ruler 多处可见。 | Messages 窗口/完整日志用于追溯。 | 有界队列、重复次数；不建立 Problems 面板。 |
| 诊断详情与日志 | Output Channel 专为 logging；Problems 可导航至问题位置。 | 指引用户打开 Messages 并提高 verbosity，收集完整日志与堆栈。 | 展开详情显示项目位置/源码行/堆栈；FileSink 纯文本日志并显示路径。 |
| 恢复/操作 | 只在有真实操作时展示 notification action；问题可有 Quick Fix。 | 支持通过日志/复现材料排障。 | 只提供真实的复制和关闭；不假装能自动修复播放错误。 |

## Sources

All externally retrieved content was treated as untrusted reference data; claims below are synthesized from official product/design documentation. Confidence reflects the research confidence classifier: cross-checked web-search evidence is **MEDIUM**; direct web-fetch evidence is classified **LOW**, so detailed implementation claims should be validated during planning rather than treated as API guarantees.

- [VS Code notification UX guidelines](https://code.visualstudio.com/api/ux-guidelines/notifications) — standard notifications are brief/non-modal, dialogs are for immediate input, actions must be real, repeated notifications should be combined, and only one should be shown at a time. Confidence: MEDIUM.
- [VS Code user interface](https://code.visualstudio.com/docs/editing/userinterface) — Notifications area remains accessible, including when Do Not Disturb is enabled; the Panel contains output, debug information, errors/warnings and terminal. Confidence: MEDIUM.
- [VS Code code navigation / Problems](https://code.visualstudio.com/docs/editing/editingevolved) — status-bar error/warning counts, Problems list, inline and overview-ruler diagnostics, and Quick Fix navigation. Confidence: MEDIUM.
- [VS Code extension capabilities](https://code.visualstudio.com/api/extension-capabilities/common-capabilities) — Output channels are intended for logging, while user-facing notifications have information/warning/error severities. Confidence: MEDIUM.
- [VLC desktop bug-report guidance](https://docs.videolan.me/vlc-user/en/support/report_a_bug/desktop.html) and [VLC FAQ](https://docs.videolan.me/vlc-user/en/support/faq/vlcmediaplayer.html) — use Messages/verbose logs, collect complete logs and symbolic stacks for diagnosis. Confidence: MEDIUM.
- [Microsoft Fluent MessageBar guidance](https://fluent2.microsoft.design/components/web/react/core/messagebar/usage) — nonmodal message bars are dismissible, error/warning messages require a resolution action, and stacked messages follow severity. Confidence: LOW (official but classifier-rated direct fetch).
- [Nielsen Norman Group error-message guidelines](https://www.nngroup.com/articles/error-message-guidelines/) — specific, human-readable explanation, possible remedies, contextual placement, and preserving user work. Confidence: LOW (direct fetch).
- [W3C WCAG 2.1: Error Identification](https://www.w3.org/WAI/WCAG21/Understanding/error-identification.html) — errors need textual identification/description; visual color is not enough. Confidence: LOW (direct fetch).

---
*Feature research for: Simple Player 错误捕获定位反馈系统*
*Researched: 2026-08-28*
