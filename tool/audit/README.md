# tool/audit/

Phase 15（契约固化与基线盘点）产出的可重跑静态审计脚本集合。

## 设计原则（D21/D23）

- **只读 LIVE 代码，从不硬编码计数。** 任何审计目标（logger 调用点、
  `MemoryMonitor` 调用点、`openGeneration` 引用）的具体数字都来自脚本对
  `lib/` 的实时扫描，不来自任何历史文档的转述。历史数字会漂移（例如
  `package:logger` 调用点历史记录为 121 处/30 文件，LIVE 实测为 84 处/28
  文件），这正是"脚本读 LIVE code"设计要防范并捕获的现象，不是 bug。
- **统计逻辑与输出逻辑分离。** 每个脚本内部的 `count_*` 函数只做计数、
  不 print、不 exit；`format_json`/`format_markdown` 只读计数结果、不重新
  计数。这样"是否失败退出"的判断可以在不改动计数逻辑的前提下独立演进
  （见下方 `--enforce` 一节）。
- **可复现性优先于便利性。** 所有进入输出的 locations / 文件列表数组，
  在序列化前都先 `sort`，保证同一次代码状态下重复运行输出字节级一致
  （`generated_at` 时间戳除外）。

## 脚本清单

### `inventory.sh` — BASE-02 调用点盘点

```bash
bash tool/audit/inventory.sh            # 写入 15-BASELINE-AUDIT.json + .md
bash tool/audit/inventory.sh --stdout   # 打印到 stdout，不写文件（用于可复现性对比）
```

审计三个目标：

1. `package:logger` 风格调用（`log`/`logEngine`/`logBridge`/`logServices`/`logUi` 前缀）
2. `MemoryMonitor.start()`/`.snapshot()` 生产调用点（排除 `memory_monitor.dart`
   自身的 doc-comment 使用示例，避免自引用误报）
3. `openGeneration`/`_openGeneration` 引用（递归扫描整个 `lib/`，不假设只存在
   于某一个已知文件——实际分布在 `fvp_engine.dart` 与 `playback_navigator.dart`
   两处）

输出双格式：`15-BASELINE-AUDIT.json`（机器可读，供下游脚本/规划直接消费）与
`15-BASELINE-AUDIT.md`（人类可读表格视图）。

**验证可复现性：**

```bash
diff <(bash tool/audit/inventory.sh --stdout | grep -v '"generated_at"') \
     <(bash tool/audit/inventory.sh --stdout | grep -v '"generated_at"')
# 期望：空 diff，退出码 0
```

### `contract_completeness.sh` — BASE-01 契约完整性检查

```bash
bash tool/audit/contract_completeness.sh
```

对 `lib/kernel/engine/` 下 7 个 ISP 接口文件动态提取每个公开成员（getter/方法）
签名，检查其上方 `///` 文档块是否含至少一个契约标签行
（`requires:`/`ensures:`/`states:`/`modifies:`/`throws:`），或该接口顶部存在
类级组契约块（`EngineStateView` 等只读接口适用）。

成员数量为脚本动态提取，不依赖任何文档中写死的数字（例如 CONTEXT.md 曾写
`EngineStateView` 有"12 个"getter，但 LIVE 代码实际是 13 个 `ValueNotifier`
getter + 1 个 `mediaInfo` getter + `dispose()` = 15 个成员——脚本以此为准）。

Phase 15 阶段（契约文档尚未撰写）运行此脚本，6 个控制类接口会报告"缺失契约
标签"——这是预期结果，不是失败。Plan 02 撰写契约后，此脚本成为自动化验收
工具，替代人工逐个核对成员是否有契约。

## `--enforce` 演进路径（占位，语义留 Phase 17 填充）

D23 锁定的设计是：同一套统计脚本未来只需新增一个 `--enforce` flag 分支，
调用现有的 `count_*` 函数、把返回值与某个阈值比较，达标则正常退出、超标则
非零退出——不需要重写任何计数逻辑本身。

Phase 15 不实现 `--enforce` 本身（语义、阈值、CI 集成方式留给 Phase 17
LOG-01 决定），但脚本结构已经满足这一演进路径的前提条件：计数函数与
格式化/输出函数是分离的独立函数，计数结果以 shell 变量形式返回，可以被
未来新增的 `--enforce` 分支直接复用而不触碰 `count_*` 函数体。

## 环境依赖

脚本优先使用 `ripgrep`（`rg`）；若当前 shell 环境未安装 `rg` 二进制（例如
部分 Windows Git Bash 终端只带有 GNU `grep`），脚本会自动降级为
`grep -P`（PCRE 模式）等价实现，产出的计数结果与 `rg` 后端完全一致——两种
后端已在本次 Phase 15 执行中交叉验证过（`grep -P` 版本产出的 84/28/2/2 与
`rg` 版本一致）。日常开发建议安装 `rg` 以获得更快的执行速度，但脚本本身
不强制要求。
