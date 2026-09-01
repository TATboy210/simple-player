# Phase 3 Discussion Log

**Date:** 2026-08-30
**Mode:** default(batch 提问 — 用户要求尽量省 token)
**Participants:** user, Claude (orchestrator)

## Areas Discussed

### 多错误呈现策略
| Question | Options | Selection |
|---|---|---|
| 多错误并发到达时卡片如何表现? | 替换+计数徽标(推荐) / 纯替换 / 堆叠列表 | 替换+计数徽标 |
| 严重级差异在卡片上如何体现? | error/fatal 优先(推荐) / 同级展示 | error/fatal 优先 |

### 卡片视觉与展开交互
| Question | Options | Selection |
|---|---|---|
| 卡片视觉风格? | 玻璃拟态+语义色(推荐) / 纯色不透明 | 玻璃拟态+语义色 |
| 折叠/展开的触发方式? | 整卡点击切换(推荐) / 按钮触发 | 整卡点击切换 |

### 挂载层级
| Question | Options | Selection |
|---|---|---|
| 卡片挂载层级与设置 overlay 的关系? | root Stack 顶层(推荐) / 绝对顶层 | root Stack 顶层 |

### 复制反馈与迁移时序
| Question | Options | Selection |
|---|---|---|
| 一键复制的成功/失败反馈方式? | OSD pill 复用(推荐) / 卡片内提示 | OSD pill 复用 |
| MIG-01 等效覆盖验证标准与旧 ErrorBanner 删除时序? | 同 phase 替换+删(推荐) / 分 phase 删 | 同 phase 替换+删 |
| 卡片数据源与 PlayerErrorReportBridge 的关系? | 统一订阅 reporter(推荐) / engine 直连 | 统一订阅 reporter |

## 研究后确认（RESEARCH open questions 用户拍板）

| Question | Options | Selection |
|---|---|---|
| 旧 ErrorBanner 的 reopen/retry 按钮在新卡片中保留吗? | 不保留(推荐) / 保留重开按钮 | 不保留 |
| ① media_kit 全屏期间错误卡片的可见性? | 全屏不显示(研究建议) / 全屏也显示 | **全屏也显示**（用户覆盖研究建议 → D-10，CARD-02 风险抬高） |
| ② 计数徽标轮览的数据源? | 本地快照(推荐) / reporter 新 API | 本地快照 |
| ③ 预挂载错误处理? | 补呈现(接受) / 不补呈现 | 补呈现 |

## Deferred Ideas

None — 未出现范围外提议

## Claude's Discretion Items

计数徽标样式与轮览细节 / warning OSD 节流参数 / 进出动画曲线时长 / 折叠摘要排版与展开段序 / OSD 同屏避让 / 等效覆盖断言集

## Extra Process Notes

- ROADMAP Phase 3 Goal 预防性改写为 User Story 格式(与 Phase 2 同样的 MVP 验证阻塞,格式验证通过后替换,中文原意保留)
- 所有推荐项均被用户采纳,无选项外自定义输入

---
*Phase: 3-播放错误桥与非模态卡片*
