# Phase 4: 错误反馈设置 - Context

**Gathered:** 2026-08-31
**Status:** Ready for planning

<domain>
## Phase Boundary

设置「通用」tab 实装:错误卡片开关(SET-01,默认开,关闭后只落盘不弹卡)+ 诊断日志输出路径配置(SET-02,可写性校验 + exe 优先/AS 回退链)+ 设置持久化(SET-03,便携 JSON)。后端持续优化不混入本 phase(独立优化轮);错误卡片前端视觉重设计走外部设计 AI 流程(交接文档已在桌面)。

</domain>

<decisions>
## Implementation Decisions

### 设置持久化形态
- **D-01:** 便携 JSON——设置存 exe 旁 `settings.json`(纯文本,Unix 原则 5),与便携日志哲学一致;debug run 时存项目目录旁。读写失败静默回退默认值,不阻断启动。**不**用 shared_preferences(漫游 AppData 与便携哲学分裂;WindowPersistence 先例仅作实现模式参考) — **Reversibility:** reversible — 存储层单点
- **D-02:** D-03(Phase 2)修订落地:默认日志位置 = **exe 根目录 `logs/error.log`**;Application Support **降为回退**(exe 旁不可写时,如 MSIX);旧日志不迁移(零迁移代码,AS 旧文件原地作历史存档,新日志从新位置起写);MSIX 虚拟化重定向**接受差异**,代码不做特殊处理,文档记录即可 — **Reversibility:** reversible — 位置解析函数单点(error_log_location.dart 扩展)
- **D-03:** 日志路径配置 UI = 手输文本框(显示当前有效路径)+ 「浏览」按钮(file_picker 已是依赖,选目录回填);输入即校验(防抖),校验结果行内展示(可写✓/不可写✗/回退中) — **Reversibility:** reversible
- **D-04:** 无效路径回退告知 = 双通道:设置页行内状态文字(当前有效路径 + 回退原因)+ 应用层 OSD pill 提示一次「日志已回退到默认位置」 — **Reversibility:** reversible
- **D-05:** 卡片开关语义 = **立即生效**:关闭 → 已显示卡片立即消失 + 后续错误只落盘不弹卡;开启 → 恢复显示(含队列中错误)。实现接缝在 UI 呈现层(ErrorCardHost/快照过滤),**零 kernel 改动**——ErrorReporter 捕获/落盘/effects 链完全不受开关影响 — **Reversibility:** reversible
- **D-06:** 后端持续优化(用户方向)**不混入**本 phase——SET-01/02/03 之外不做 sink/序列化优化;优化作为独立轮,在设置功能落地后按 profile 驱动细化 — **Reversibility:** n/a(范围决策)

### UAT 后修订决策（2026-09-01，用户拍板）
- **D-07:** **移除日志路径配置功能**(用户实测后判定鸡肋)——通用 tab 不再有路径行/浏览按钮/校验 UI;设置 store 移除 logDirectory 字段(仅保留卡片开关);三层位置链收窄为**双层**(exe 根 logs/ → Application Support logs/),`validateConfiguredDirectory` 保留作内部可写探测(双层回退与设置 store WR-06 回退层复用);`DiagnosticLogTarget` 协调器简化为仅启动激活(无运行时重定向);D-04 双通道回退告知随之作废(无配置即无配置失败告知);SET-02 已按修订语义在 REQUIREMENTS.md 关账 — **Reversibility:** reversible——功能移除,git 可恢复

### Claude's Discretion
- settings.json 的字段命名/结构(建议扁平 key-value + version 字段)
- 「输入即校验」的防抖时长与校验实现(临时目录探测 vs 直接 open/write 探测)
- 浏览按钮回填后是否自动保存(建议:校验通过即保存,失败则行内报错不保存)
- 开关状态与 settings.json 读写时序(启动加载→内存 ValueNotifier→UI 订阅)
- 日志路径变更时 sink 重建的安全接线细节(复用 Phase 2 单写者 drain 语义,不中断写入中记录)
- 通用 tab 内两个设置项的排版(设置行组件已有先例:setting_action_row/setting_slider_row)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 项目规划文档
- `.planning/REQUIREMENTS.md` — SET-01/02/03 需求全文
- `.planning/ROADMAP.md` — Phase 4 Goal(User Story)与 3 条成功标准
- `.planning/PROJECT.md` — Unix 原则 5(纯文本存储)直接约束 D-01
- `.planning/phases/02-trusted-location-file-evidence/02-CONTEXT.md` — D-03(被本 phase 修订)/D-02(单写者即时写契约,SET-02 不得破坏)
- `.planning/phases/02-trusted-location-file-evidence/02-RESEARCH.md` — FileSink/单写者语义与验证架构
- `.planning/phases/03-playback-error-card-bridge/03-CONTEXT.md` — D-01/02(卡片行为,windows 化位置 44.0 供排版参考)

### 代码事实源
- `lib/ui/dialogs/settings/settings_dialog.dart` — 灰显壳(通用 tab 实装的落点;setting_action_row/setting_slider_row 行组件先例)
- `lib/kernel/diagnostics/error_log_location.dart` — sealed Result + provider seam(D-02 修订的扩展点)
- `lib/kernel/diagnostics/error_log_file_sink.dart` — 单写者 sink(SET-02 路径变更时的安全重建对象)
- `lib/kernel/diagnostics/error_reporting_dependencies.dart` — delegating effect + activate(路径切换接线参考)
- `lib/kernel/persistence/window_persistence.dart` — 持久化实现模式参考(注意:D-01 改用便携 JSON,不用 shared_preferences)
- `lib/kernel/diagnostics/error_capture_snapshot.dart` — effects 缝(卡片开关过滤挂点参考)
- `lib/ui/player/error_card_host.dart` — 呈现宿主(开关生效接缝)
- `lib/main.dart` — 启动组装(设置加载时机、sink 初始化顺序)
- `lib/ui/shared/osd_overlay.dart` — OsdService.I.show(回退 OSD 提示)
- `lib/features/player/file_picker_adapters.dart` — file_picker 先例(浏览按钮)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `settings_dialog.dart` 灰显壳 + `_NavEntry` 结构:通用 tab 直接实装
- `setting_action_row.dart` / `setting_slider_row.dart` / `focusable_setting_row.dart`:设置行组件先例(开关行可直接循 setting_action_row + Switch)
- `error_log_location.dart` sealed Result:扩展 exe-root 优先解析的最小改动点
- `error_log_file_sink.dart` 单写者 + drain 语义:路径切换安全重建复用
- `file_picker` 依赖已在:浏览按钮零新增依赖
- `OsdService.I.show`:回退提示出口

### Established Patterns
- ValueNotifier + ValueListenableBuilder(设置状态 = 内存 notifier + JSON 持久化)
- kernel 禁 debugPrint;零 kernel 改动红线对本 phase 放宽为「kernel 只动 error_log_location.dart 的解析扩展 + 必要的 sink 接线,不碰 reporter/单写者语义」
- 中文双语 doc comment、conventional commits、analyze 0 error / test 全绿红线
- 安全基线:Phase 1 SECURITY.md 的 T-01-13/19(FileSink 相关)在本 phase 落地后应一并重审收账

### Integration Points
- `main.dart`:启动时加载 settings.json → 内存 notifier → 卡片开关过滤 + sink 位置解析
- `error_card_host.dart`:开关过滤呈现(D-05 立即生效)
- `error_log_file_sink.dart`:路径变更时 drain→重建→激活(复用 Phase 2 语义)
- 设置对话框:通用 tab 两个设置项 + 行内校验状态

</code_context>

<specifics>
## Specific Ideas

无特殊外部引用——决策集中在存储形态/回退链/UI 交互/开关语义;技术形态全部复用既有 seam 与组件先例

</specifics>

<deferred>
## Deferred Ideas

- **错误卡片前端视觉重设计** — 交接文档已交付(`C:\Users\35490\Desktop\错误弹窗前端设计AI交接文档.md`),设计 AI 产出规范后独立实现流程
- **后端持续优化轮** — sink/序列化/系统占用,设置功能落地后按 profile 驱动独立立项

</deferred>

---

*Phase: 4-错误反馈设置*
*Context gathered: 2026-08-31*
