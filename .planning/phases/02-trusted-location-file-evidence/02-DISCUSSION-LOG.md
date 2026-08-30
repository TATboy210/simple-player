# Phase 2 Discussion Log

**Date:** 2026-08-30 | **Mode:** discuss（低消耗压缩式）

| Area | Question | Decision |
|------|----------|----------|
| 源码行读取范围 | debug 下展示行数 | 定位行 ±2 行（共 5 行），信任校验 + 可读性前提，越界降级 |
| 写盘节流 | 即时写 vs 批量 | 即时写（上游 FIFO+去重控洪流） |
| 文件位置 | 默认落点 | ApplicationSupport/logs/error.log，单文件追加 |
| 诊断包格式 | 分段式 vs KV vs JSON | 分段式纯文本，复制=文件同格式 |
| 定位信息内容 | 帧提取策略 | 首个项目帧 + ≤2 次级帧，raw stack 全文保留，失败降级文本 |

**Deferred:** none
**Claude's Discretion:** 源码根界定方式、帧解析兜底、FileSink 组装与限流参数、诊断包段文案
**Note:** 第二轮 AskUserQuestion 选项出现乱码（用户报"乱码毛病又出来了"），改纯文本编号提问完成。下次建议少用内嵌特殊字符。

---
*Phase: 2-可信定位与文件证据*
