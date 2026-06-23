# Discussion Log — Phase 2: Widget Unification

**Date:** 2026-05-28
**Mode:** default (interactive)

## Areas Discussed

### 1. Glass Component API
| Question | Options | Answer |
|----------|---------|--------|
| GlassIconButton 关系 | 合并(推荐) / 保留独立 / 只加 barrel | 合并到 GlassButton |
| 旧组件处理 | 废弃标记 / 删除旧文件 / 渐进迁移 | 完整迁移 + 删除旧文件 |
| Barrel file | 单一 barrel(推荐) / 独立 import | 单一 glass_widgets.dart |
| GlassChip | 保持独立(推荐) / 合并 | 保持独立 |

### 2. Hover/press Animation Mixin
| Question | Options | Answer |
|----------|---------|--------|
| 交互反馈策略 | scale 动画 / 分模式 / InkWell | 全部用 InkWell |
| Mixin 提取 | 不需要(推荐) / 提取 | 不需要 mixin |

### 3. ControlsOverlay State Object
| Question | Options | Answer |
|----------|---------|--------|
| 参数封装 | 不可变类 / Record / 保持现状(推荐) | 保持现状 |

### 4. ValueNotifier Rebuild Audit
| Question | Options | Answer |
|----------|---------|--------|
| 审计范围 | player/(推荐) / 全部 ui/ | 全部 ui/ 目录 |
| 审计维度 | child 缓存 / notifier 合并 / 基线 / 不必要监听 | 全部 4 项 |
| 验证方式 | DevTools / 代码分析 / 定性判断(推荐) | 定性判断 + 代码分析 |

### 5. GlassContainer API (extra)
| Question | Options | Answer |
|----------|---------|--------|
| 参数简化 | 保持现状(推荐) / 便捷构造器 / 简化必填 | 保持现状 |

### 6. Barrel File Scope (extra)
| Question | Options | Answer |
|----------|---------|--------|
| 范围 | 仅 glass(推荐) / 全部 shared / 不创建 | 仅 glass 组件 |

### 7. Glass Testing (extra)
| Question | Options | Answer |
|----------|---------|--------|
| 测试策略 | widget 测试(推荐) / 推迟 / 全面+golden | 核心组件 widget 测试 |

### 8. Glass Performance (extra)
| Question | Options | Answer |
|----------|---------|--------|
| 优化方向 | 条件跳过 / 降级模式 / Tier 评估 / 推迟 | 条件跳过 + 降级 + Tier 评估 |

## Deferred Ideas
None

---
*Generated: 2026-05-28*
