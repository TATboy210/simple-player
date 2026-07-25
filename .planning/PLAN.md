# Obsidian Knowledge-Curator: Floating & Pinned Sidebar 实现计划 (v2 - CSS-First)

## 1. 问题定义

Knowledge-curator 项目已有 CSS snippet 实现 floating/pinned sidebar，但存在功能缺口需要补齐。

**现有实现**:
- `floating-sidebar.css` — 基础 floating sidebar 样式
- `pinned-floating-sidebars.css` — pinned sidebar 样式
- `sidebar-hover-toggle.css` — 悬停触发逻辑
- `floating-tab-group.css` — 浮动标签组样式
- `obsidian-floating-sidebar-toggle` 插件 — toggle 按钮

**功能缺口** (待确认):
- [ ] Floating ↔ Pinned 模式无缝切换
- [ ] Pinned sidebar 宽度拖拽调整
- [ ] 状态持久化 (记住宽度、是否收起)
- [ ] 多面板支持 (同时打开多个 sidebar)
- [ ] 移动端适配

## 2. 设计原则

1. **CSS-First**: 优先使用 CSS snippet 实现，仅在必要时使用 JS 插件
2. **增量迭代**: 基于已有代码扩展，而非重写
3. **主题兼容**: 使用 Obsidian CSS 变量，确保跨主题兼容
4. **性能优先**: 使用 `transform` 和 `opacity` 动画，避免触发 reflow

## 3. Widget 概念设计

### 3.1 Floating Sidebar (已有基础实现)

**核心 CSS 特征**:
```css
.floating-sidebar {
  position: fixed;
  inset: 0;
  z-index: var(--layer-modal);
  display: flex;
  pointer-events: none; /* 默认不拦截点击 */
  opacity: 0;
  transition: opacity 300ms ease-in-out;
}

.floating-sidebar.is-open {
  pointer-events: auto;
  opacity: 1;
}

.floating-sidebar-backdrop {
  flex: 1;
  background: rgba(0,0,0,0.5);
  backdrop-filter: blur(8px);
}

.floating-sidebar-content {
  width: 320px;
  max-width: 90vw;
  background: var(--background-primary);
  transform: translateX(-100%);
  transition: transform 300ms ease-in-out;
}

.floating-sidebar.is-open .floating-sidebar-content {
  transform: translateX(0);
}
```

**改进点**:
- 添加 `pointer-events` 控制，避免未打开时拦截点击
- 使用 `opacity` 动画替代 `visibility`，更平滑
- 添加 `will-change: transform` 提示 GPU 加速

---

### 3.2 Pinned Sidebar (已有基础实现)

**核心 CSS 特征**:
```css
.pinned-sidebar {
  flex-shrink: 0;
  width: 260px;
  background: var(--background-secondary);
  border-right: 1px solid var(--background-modifier-border);
  overflow: hidden;
  transition: width 300ms ease-in-out;
}

.pinned-sidebar.is-collapsed {
  width: 0;
  border-right-width: 0;
}
```

**改进点**:
- 使用 CSS Grid 替代 Flexbox，实现更平滑的宽度动画
- 添加最小宽度约束 (`min-width: 48px` 展开状态)
- 添加拖拽调整宽度的交互区域

---

### 3.3 Floating Tab Group (已有基础实现)

**核心 CSS 特征**:
```css
.floating-tab-group {
  position: absolute;
  z-index: 1000;
  background: rgba(255,255,255,0.95);
  backdrop-filter: blur(20px);
  border-radius: 12px;
  box-shadow: 0 4px 24px rgba(0,0,0,0.12);
  max-width: 50vw;
  max-height: 80vh;
  overflow: auto;
}
```

**改进点**:
- 添加拖拽标题栏
- 添加关闭按钮
- 支持多实例

---

### 3.4 Sidebar Hover Toggle (已有基础实现)

**核心 CSS 特征**:
```css
.hover-toggle-zone {
  position: fixed;
  left: 0;
  top: 0;
  width: 20px;
  height: 100vh;
  z-index: var(--layer-status-bar);
}

.hover-toggle-zone:hover + .pinned-sidebar {
  width: 260px;
  transition-delay: 300ms;
}
```

**改进点**:
- 添加边缘高亮条视觉反馈
- 优化延迟时间 (200ms 显示, 500ms 隐藏)
- 支持右侧 sidebar

---

## 4. 架构设计

### 4.1 CSS Snippet 结构

```
.obsidian/snippets/
├── floating-sidebar.css       # Floating sidebar 样式
├── pinned-sidebar.css         # Pinned sidebar 样式
├── floating-tab-group.css     # 浮动标签组样式
├── sidebar-hover-toggle.css   # 悬停触发样式
├── sidebar-modes.css          # 模式切换逻辑
└── sidebar-responsive.css     # 响应式适配
```

### 4.2 插件结构 (仅用于 JS 交互)

```
.obsidian/plugins/obsidian-floating-sidebar-toggle/
├── main.js                    # 插件入口
├── manifest.json              # 插件清单
└── styles.css                 # 插件专用样式
```

### 4.3 状态管理 (CSS 类名)

| 类名 | 作用 | 触发方式 |
|------|------|----------|
| `.is-open` | Floating sidebar 打开 | JS toggle / 命令 |
| `.is-collapsed` | Pinned sidebar 收起 | JS toggle / 命令 |
| `.is-dragging` | 正在拖拽调整宽度 | JS mousedown |
| `.is-hovering` | 鼠标悬停在热区 | CSS :hover |

### 4.4 Obsidian DOM 选择器

```css
/* Obsidian workspace 结构 */
.workspace-split.mod-root { /* 主内容区 */ }
.workspace-split.mod-left-split { /* 左侧 sidebar */ }
.workspace-split.mod-right-split { /* 右侧 sidebar */ }
.workspace-leaf { /* 单个面板 */ }
.workspace-tab-header-container { /* 标签头 */ }

/* 自定义 sidebar */
.floating-sidebar { /* 浮动 sidebar 容器 */ }
.pinned-sidebar { /* 固定 sidebar 容器 */ }
.floating-tab-group { /* 浮动标签组 */ }
```

---

## 5. 实现任务分解

### T1: 审计现有 CSS snippet [1h]

**输入**: 现有 CSS snippet 文件
**输出**: 功能清单 + 缺口分析

**步骤**:
1. 阅读每个 CSS snippet，记录已实现的功能
2. 测试每个功能的视觉效果和交互行为
3. 识别功能缺口和 bug
4. 更新本文档的功能缺口列表

---

### T2: 修复 Floating Sidebar 动画问题 [2h]

**输入**: `floating-sidebar.css`
**输出**: 修复后的 CSS

**步骤**:
1. 添加 `pointer-events` 控制
2. 优化动画使用 `will-change: transform`
3. 添加 `prefers-reduced-motion` 媒体查询支持
4. 测试动画流畅度

---

### T3: 优化 Pinned Sidebar 宽度动画 [2h]

**输入**: `pinned-floating-sidebars.css`
**输出**: 优化后的 CSS

**步骤**:
1. 测试当前宽度动画的性能
2. 尝试使用 CSS Grid 替代 Flexbox
3. 添加最小宽度约束
4. 测试边界情况 (极小/极大宽度)

---

### T4: 实现 Floating ↔ Pinned 模式切换 [4h]

**输入**: 现有 CSS + 插件代码
**输出**: 模式切换功能

**步骤**:
1. 设计模式切换的 CSS 类名方案
2. 在插件中添加模式切换命令
3. 实现 CSS 过渡动画
4. 测试模式切换的视觉效果
5. 处理边界情况 (快速切换、动画中断)

---

### T5: 实现宽度拖拽调整 [3h]

**输入**: Pinned sidebar CSS + 插件代码
**输出**: 宽度拖拽功能

**步骤**:
1. 添加拖拽手柄元素 (`.resize-handle`)
2. 实现 `mousedown/mousemove/mouseup` 事件处理
3. 添加拖拽时的视觉反馈 (光标、阴影)
4. 添加最小/最大宽度约束
5. 测试拖拽流畅度

---

### T6: 实现状态持久化 [2h]

**输入**: 插件代码 + Obsidian API
**输出**: 状态持久化功能

**步骤**:
1. 使用 `plugin.loadData()` / `plugin.saveData()` 保存状态
2. 保存: sidebar 宽度、是否收起、当前模式
3. 在插件加载时恢复状态
4. 测试状态恢复的准确性

---

### T7: 响应式适配 [2h]

**输入**: 现有 CSS
**输出**: 响应式 CSS

**步骤**:
1. 添加媒体查询 (< 768px, 768-1024px, > 1024px)
2. 小屏幕强制使用 floating 模式
3. 调整 sidebar 宽度 (240px / 280px / 320px)
4. 测试不同屏幕尺寸的效果

---

### T8: 测试与文档 [2h]

**输入**: 所有实现
**输出**: 测试报告 + 使用文档

**步骤**:
1. 跨主题测试 (默认主题、Minimal、AnuPpuccin)
2. 跨平台测试 (Windows、macOS、Linux)
3. 编写使用文档 (命令列表、快捷键、配置项)
4. 截图/录屏演示

---

## 6. 技术决策记录

| 决策 | 选项 | 选择 | 理由 |
|------|------|------|------|
| 实现方式 | CSS Only / CSS + 插件 / 纯插件 | CSS + 插件 | CSS 处理样式和动画，插件处理交互逻辑 |
| 动画实现 | CSS Transition / Web Animations API | CSS Transition | 性能最优，GPU 加载，代码简洁 |
| 宽度调整 | CSS resize / JS 拖拽 / CSS Grid | JS 拖拽 | 更好的控制和视觉反馈 |
| 状态存储 | localStorage / Obsidian API | Obsidian API | 与插件系统集成，支持同步 |
| 响应式 | 媒体查询 / JS 检测 | 媒体查询 | 性能更好，无需 JS |

---

## 7. 风险与缓解

| 风险 | 影响 | 缓解策略 |
|------|------|----------|
| CSS 与主题冲突 | 样式错乱 | 使用高特异性选择器，添加 `!important` 保底 |
| 动画卡顿 | 体验差 | 使用 `transform` 和 `opacity`，避免触发 reflow |
| 状态恢复失败 | 状态丢失 | 添加默认值，处理异常情况 |
| 插件冲突 | 功能异常 | 命名空间隔离，避免全局变量污染 |
| 移动端不可用 | 功能缺失 | 小屏幕强制 floating 模式，增大点击区域 |

---

## 8. 验收标准

### 功能验收

- [ ] Floating sidebar 可通过命令/快捷键打开/关闭
- [ ] Pinned sidebar 可通过命令/快捷键展开/收起
- [ ] Floating ↔ Pinned 模式可无缝切换
- [ ] Pinned sidebar 宽度可拖拽调整
- [ ] 状态可持久化，重启后恢复
- [ ] 响应式适配，小屏幕自动切换模式

### 性能验收

- [ ] 动画流畅，无卡顿 (60fps)
- [ ] 无内存泄漏
- [ ] 无 CSS 选择器性能问题

### 兼容性验收

- [ ] 兼容 Obsidian 默认主题
- [ ] 兼容 Minimal 主题
- [ ] 兼容 AnuPpuccin 主题
- [ ] 兼容 Windows/macOS/Linux

---

## 9. 问题追踪

| 问题 | 状态 | 负责人 | 截止日期 |
|------|------|--------|----------|
| T1: 审计现有 CSS | 待开始 | - | - |
| T2: 修复动画问题 | 待开始 | - | - |
| T3: 优化宽度动画 | 待开始 | - | - |
| T4: 模式切换 | 待开始 | - | - |
| T5: 宽度拖拽 | 待开始 | - | - |
| T6: 状态持久化 | 待开始 | - | - |
| T7: 响应式适配 | 待开始 | - | - |
| T8: 测试与文档 | 待开始 | - | - |
