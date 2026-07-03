# Discussion Log — Phase 20: Control Bar Subtraction

## Area 1: 视觉层精简

### Q1: BoxShadow 层叠处理
- Options: 激进裁剪 / 保守裁剪 / 合并为单源
- **Selected: 激进裁剪** — 删除 alpha<3% 的 outerShadow、glowOuterRing、ambientBlue

### Q2: EdgeGlow 变体处理
- Options: 只保留 gradient / 保留但标记弃用
- **Selected: 只保留 gradient** — 删除 omni/pulse 及对应 Painter 类

### Q3: 渐变带与 EdgeGlow 关系
- Options: 合并到 EdgeGlow / 保持分离 / 删除渐变带
- **Selected: 合并到 EdgeGlow** — EdgeGlow 新增 gradientStripHeight 参数

### Q4: idle 装饰简化
- Options: 保持现状 / 去掉 bottom 辉光
- **Selected: 去掉 bottom 辉光** — _decorationIdle 只保留 top 描边

### Q5: CustomPaint 渐变描边
- Options: 删除 CustomPaint / 保留
- **Selected: 删除 CustomPaint** — 与 BoxShadow borderBlue 功能重叠

### Q6: top 描边合并
- Options: 合并为单一描边 / 保持分离
- **Selected: 合并为单一描边** — 只保留 Border.all

### Q7: 未使用 token 清理
- Options: 删除未使用 token / 只删 omni 4个 / 不动 token
- **Selected: 删除未使用 token** — 删除 glowOmni(4)、glowGradient(3)、glowPurple

## Area 2: 组件结构精简

### Q8: 断点级别
- Options: 3级→2级 / 保持3级 / 只保留1级+隐藏
- **Selected: 3级→2级** — 删除 ultraCompact(≤360px) 和 _CompactCenterGroup

### Q9: _ProgressRow 处理
- Options: 删除 / 保留
- **Selected: 保留** — 可能是 hover 高亮预留

### Q10: 内部类处理
- Options: 内联回 build / 保持独立
- **Selected: 保持独立** — 职责清晰

### Q11: Overlay 精简程度
- Options: 确认已足够精简 / 移出 ErrorBanner
- **Selected: 确认已足够精简**
