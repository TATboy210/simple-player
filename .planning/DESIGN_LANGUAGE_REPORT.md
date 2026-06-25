# Simple Player — 设计语言分析报告

> 源文件：`design-elements-extracted-2.html`
> 分析日期：2026-06-25

---

## 一、设计语言总览

Simple Player 的设计语言围绕 **"暗夜辉光"** 主题，核心视觉特征：

| 特征 | 描述 |
|------|------|
| **深色基底** | 4 层深蓝灰阶梯（Deep → Mid → Surface → Elevated） |
| **毛玻璃** | `backdrop-filter: blur()` + 半透明底色 + 微光边框 |
| **蓝色辉光** | 统一的蓝色辉光系统（`#4a8eff` 为主色） |
| **边缘微光** | 三层辉光结构：内层高光 → 中层扩散 → 外层环境 |
| **透射光效** | 光从界面下方/背后渗出，营造深度感 |

**设计标签：** `frosted glass` · `edge glow` · `transmission` · `dark ui`

### 字体系统

| 类型 | 字体栈 | 用途 |
|------|--------|------|
| **主字体** | `SF Pro Display, -apple-system, Segoe UI, system-ui, sans-serif` | 标题、正文、按钮 |
| **等宽字体** | `SF Mono, Cascadia Code, JetBrains Mono, monospace` | 标签、时间码、代码块、编号 |

等宽字体仅用于：标签（11px）、时间码（12px）、代码块（12px）、section 编号（11px）

### 圆角系统（4 级）

| Token | 值 | 用途 |
|-------|-----|------|
| `--radius-sm` | `8px` | 按钮、speed 标签 |
| `--radius-md` | `14px` | 色板方块、透射卡片图标 |
| `--radius-lg` | `22px` | 边缘微光卡片、glass-panel、player-controls 底部、透射卡片、hover 区域 |
| `--radius-xl` | `32px` | glass-demo-area、player-reconstruction 外框 |

### 文字色阶完整映射

| 层级 | 色值 | 用途 | 出现位置 |
|------|------|------|---------|
| **Primary** | `rgba(255,255,255,0.92)` | 标题、主文字 | h1、section-title、glass-text-primary |
| **Secondary** | `rgba(255,255,255,0.45)` | 副文字、描述 | subtitle、section-desc、ctrl-time |
| **Muted** | `rgba(255,255,255,0.22)` | 标签、编号、占位 | section-label、tag、ctrl-label、hint |

### 全局环境光（body::before）

`position: fixed; inset: 0; z-index: 0` 三层径向渐变，营造深邃环境光场：

| 层 | 形状 | 位置 | 颜色 | 扩散 |
|----|------|------|------|------|
| 1 | `ellipse 60%×40%` | `50% 45%` | `rgba(40,70,160,0.06)` | 70% |
| 2 | `ellipse 40%×30%` | `30% 60%` | `rgba(60,40,140,0.04)` | 60% |
| 3 | `ellipse 35%×25%` | `70% 55%` | `rgba(30,80,180,0.03)` | 55% |

所有前景元素都在这个光场中渲染。

---

## 二、7 个设计模块详细分析

### 01 — 边缘微光 Edge Glow

从图标边框和控制栏边缘提取的 **三层辉光结构**。

| 层级 | CSS 实现 | 效果 |
|------|---------|------|
| **内层高光** | `inset 0 1px 0 rgba(255,255,255,0.03)` | 顶部内高光描边 |
| **中层扩散** | `0 0 20px rgba(80,130,255,0.04)` | 蓝色柔光扩散 |
| **外层环境** | `0 0 50px rgba(60,100,220,0.02)` | 远距环境辉光 |

#### 变体 A — 渐变描边（角度衰减）

**完整 box-shadow（5 层）：**

| # | 值 | 作用 |
|---|-----|------|
| 1 | `inset 0 1px 0 rgba(255,255,255,0.03)` | 顶部内高光 |
| 2 | `0 0 0 1px rgba(80,120,255,0.06)` | 实线描边 |
| 3 | `0 0 20px rgba(80,120,255,0.04)` | 中层扩散 |
| 4 | `0 0 50px rgba(60,100,220,0.02)` | 外层环境 |
| 5 | `border: 1px solid rgba(80,120,255,0.12)` | CSS border（非 shadow） |

**渐变描边 `::after` 精确参数：**

- `inset: -1px`, `padding: 1px` → 实际描边宽度 1px
- 渐变角度 `135°`（左上→右下）
- 四色断点：`rgba(100,160,255,0.18)` → `transparent 30%` → `transparent 70%` → `rgba(80,120,255,0.08)`
- 中间 40% 完全透明，**只在两个对角角点发光**
- `mask-composite: exclude` + `-webkit-mask-composite: xor`

#### 变体 B — 全向柔光（锥形渐变）

**`::before` 精确参数：**

- `inset: -2px`, `filter: blur(6px)`, `z-index: -1`（在卡片下方）
- `conic-gradient(from 180deg, ...)` — 四色循环
- 颜色循环：**蓝 → 暗蓝 → 紫 → 暗蓝 → 蓝**（对称分布）

#### 变体 C — 脉冲呼吸（动态强度）

**关键帧精确数值：**

| 属性 | 0%/100% | 50% | 变化倍率 |
|------|---------|-----|---------|
| 描边透明度 | `0.08` | `0.18` | ×2.25 |
| 中层辉光扩散 | `20px` | `30px` | ×1.5 |
| 中层辉光透明度 | `0.03` | `0.08` | ×2.67 |
| 外层辉光 | 无 | `60px 0.04` | 新增 |

动画：`@keyframes pulse-border` 3s ease-in-out infinite

---

### 02 — 毛玻璃辉光 Frosted Glass Glow

控制栏核心效果，多层叠加：

```
背景色彩 → 半透明底色 → backdrop-filter 模糊 → 内外双层微光边框
```

**核心 CSS 参数：**

| Token | 值 | 用途 |
|-------|-----|------|
| `glass-bg` | `rgba(18, 22, 40, 0.55)` | 半透明底色 |
| `glass-blur` | `20px` | 模糊强度 |
| `glass-border` | `rgba(100, 130, 255, 0.08)` | 蓝色微光边框 |

**glass-demo-area 背景三层精确参数：**

| 层级 | 形状 | 中心位置 | 颜色 | 扩散 |
|------|------|---------|------|------|
| 1 | `ellipse 50%×60%` | `40% 50%` | `rgba(40,80,180,0.12)` | 70% |
| 2 | `ellipse 40%×50%` | `65% 45%` | `rgba(80,50,160,0.08)` | 65% |
| 3 | 底色 | — | `var(--bg-mid)` | — |

**glass-panel 完整 box-shadow（5 层）：**

| # | 值 | 作用 |
|---|-----|------|
| 1 | `inset 0 1px 0 rgba(255,255,255,0.04)` | 顶部内高光 |
| 2 | `inset 0 -1px 0 rgba(0,0,0,0.1)` | 底部内阴影 |
| 3 | `0 8px 32px rgba(0,0,0,0.25)` | 外层投影 |
| 4 | `0 0 0 1px rgba(80,130,255,0.04)` | 蓝色外环 |
| 5 | `border: 1px solid rgba(100,130,255,0.08)` | 实际边框 |

**glass-icon-btn 状态链（3 态）：**

| 状态 | background | border | box-shadow | 过渡 |
|------|-----------|--------|------------|------|
| **默认** | `rgba(255,255,255,0.04)` | `1px solid rgba(255,255,255,0.06)` | 无 | — |
| **Hover** | `rgba(255,255,255,0.08)` | `rgba(80,130,255,0.15)` | `0 0 12px rgba(80,130,255,0.08)` | — |
| **过渡** | — | — | — | `all 0.2s ease` |

**进度条辉光（glow-track-fill）完整参数：**

- 背景：`linear-gradient(90deg, #4a8eff, rgba(100,160,255,0.9))`
- 双层辉光：`0 0 8px rgba(74,142,255,0.4)` + `0 0 20px rgba(74,142,255,0.15)`
- 拖拽手柄 `::after`：`10×10px` 圆，`#4a8eff` 实色 + `0 0 6px rgba(74,142,255,0.6)` + `0 0 16px rgba(74,142,255,0.3)`
- 轨道：`height: 3px`, `rgba(255,255,255,0.06)`

---

### 03 — 透射光效 Light Transmission

光从表面下方或背后渗出的效果。

#### 底部透射（trans-a）完整几何

- **`::before`**：`bottom: -40px`, `left: 50%; transform: translateX(-50%)`, `width: 120%`, `height: 120px`
- 渐变：`radial-gradient(ellipse at center, rgba(74,142,255,0.15), transparent 70%)`
- 模糊：`filter: blur(30px)`
- **`::after` 覆盖层**：`height: 60%`, `linear-gradient(180deg, transparent, rgba(74,142,255,0.03))` — 模拟光线从下往上衰减

#### 中心透射（trans-b）完整几何

- **`::before`**：`top: 50%; left: 50%; transform: translate(-50%,-50%)`, `160×160px` 正圆
- 渐变：`radial-gradient(circle, rgba(120,100,220,0.12), transparent 70%)`
- 模糊：`filter: blur(25px)`

#### 透射卡片容器参数

- `border-radius: var(--radius-lg)` (22px)
- `min-height: 200px`
- 图标：`48×48px`, `border-radius: var(--radius-md)` (14px), `rgba(255,255,255,0.03)` 背景 + `rgba(255,255,255,0.05)` 边框
- 所有内容元素加 `position: relative; z-index: 1` 避免被透射层遮挡

---

### 04 — 交互辉光 Hover Glow

鼠标悬停时的光晕追踪效果，完整参数：

- **光晕元素**：`200×200px` 圆，`radial-gradient(circle, rgba(80,130,255,0.08), transparent 70%)`
- **初始**：`opacity: 0`，hover 容器时 `opacity: 1`
- **定位**：`transform: translate(-50%, -50%)` 居中于光标
- **过渡**：`opacity 0.3s`（淡入淡出）
- **容器**：`cursor: crosshair`, `min-height: 160px`
- **JS**：`mousemove` 追踪 `clientX/Y` 减去 `getBoundingClientRect()` 偏移

---

### 05 — 完整控制栏 Reconstruction

#### 两套毛璃对比（demo vs 实际控制栏）

| 属性 | glass-demo-area | player-controls |
|------|----------------|-----------------|
| 背景色 | `rgba(18,22,40,0.55)` | `rgba(14,17,30,0.6)` |
| blur | `20px` | `24px` |
| saturate | `1.2` | `1.1` |
| 圆角 | `22px`（四角） | `22px`（仅底部两角） |
| 顶部边框 | `rgba(100,130,255,0.08)` | `rgba(255,255,255,0.04)` |

#### player-controls::before 蓝色光线

- `top: 0; left: 10%; right: 10%; height: 1px`
- `linear-gradient(90deg, transparent, rgba(80,130,255,0.12), transparent)`

#### 按钮尺寸系统

| 元素 | 尺寸 | 间距 |
|------|------|------|
| 普通按钮 | `34×34px` | `gap: 6px` |
| 播放按钮 | `40×40px`（大 18%） | — |
| 普通 SVG | `16×16px` | — |
| 播放 SVG | `20×20px` | — |

#### 按钮交互状态

| 状态 | stroke | background | 其他 |
|------|--------|------------|------|
| **默认** | `rgba(255,255,255,0.55)` | 无 | — |
| **Hover** | `rgba(255,255,255,0.85)` | `rgba(255,255,255,0.05)` | — |
| **播放 Hover** | `#fff` | — | `filter: drop-shadow(0 0 6px rgba(80,130,255,0.3))` |

#### 进度条拖拽手柄（隐藏→显示）

- `ctrl-track-fill::after`：`8×8px` 白色圆
- 默认 `opacity: 0`，hover `.ctrl-track` 时 `opacity: 1`
- `transition: opacity 0.2s`

#### 其他控件

- **音量滑块**：`width: 72px; height: 3px`，填充 `var(--accent-blue)` + `0 0 6px rgba(74,142,255,0.3)`
- **倍速标签**：`font-size: 12px` 等宽，hover 加 `color: text-primary` + `background: rgba(255,255,255,0.05)`，`border-radius: 4px`

---

### 06 — 色板 Extracted Palette

| 名称 | 色值 | 用途 |
|------|------|------|
| **Deep** | `#0a0c14` | 最深背景 |
| **Mid** | `#10131e` | 主背景 |
| **Surface** | `#161a2a` | 卡片/面板背景 |
| **Elevated** | `#1c2038` | 悬浮层 |
| **Accent** | `#4a8eff` | 蓝色强调色 |
| **Glow** | `rgba(80,130,255,0.15)` | 辉光效果 |

---

### 07 — CSS Token 代码

完整 CSS 自定义属性集合（见源文件第 301-328 行），分为 4 组：
1. **色板** — `--sp-bg-deep/mid/surface/elevated`, `--sp-accent`
2. **毛玻璃** — `--sp-glass-bg/blur/border`
3. **边缘微光** — `--sp-glow-edge/mid/core`
4. **透射** — `--sp-trans-bottom/center`

---

## 三、间距与排版系统

| 属性 | 值 |
|------|-----|
| 页面 padding | `60px 40px 80px` |
| 页面 max-width | `1200px` |
| 模块间距 | `margin-bottom: 72px` |
| 分隔线 | `linear-gradient(90deg, transparent, rgba(80,130,255,0.08), transparent)`，`margin: 64px 0` |
| section 编号 | `11px` / `font-mono` / `letter-spacing 0.12em` / `uppercase` / `text-muted` |
| section 标题 | `22px` / `weight 500` |
| section 描述 | `14px` / `line-height 1.6` / `max-width 640px` |
| tag pill | `11px` / `font-mono` / `padding 4px 14px` / `border-radius 100px` / `bg rgba(74,142,255,0.06)` / `border rgba(74,142,255,0.12)` |
| header h1 | `36px` / `weight 600` / `letter-spacing 0.08em` |
| header subtitle | `15px` / `text-secondary` / `letter-spacing 0.04em` |

---

## 四、与现有代码对比（tokens.dart）

### ✅ 已实现

| 设计元素 | 现有 Token | 状态 |
|---------|-----------|------|
| 背景色阶梯 | `bgBase=#10131E`, `bgPanel=#161A2A` | ✅ 匹配 |
| 毛玻璃底色 | `bgGlass=rgba(18,22,40,0.55)` | ✅ 精确匹配 |
| 蓝色强调色 | `accentBlue=#4A8EFF` | ✅ 精确匹配 |
| 文字色阶 | `textPrimary/Secondary/Tertiary` | ✅ 匹配 |
| 毛玻璃边框 | `glassBorder=rgba(100,130,255,0.08)` | ✅ 匹配 |
| 毛玻璃模糊 | `glassBlur=10/24` | ✅ 有 thin/normal/thick 三级 |
| 控制栏圆角 | `controlBarRadius=16` | ⚠️ 设计稿为 22px |
| 控制栏蓝色边框 | `controlBarBorder=rgba(100,130,255,0.08)` | ✅ 匹配 |

### ⚠️ 部分匹配 / 差异

| 设计元素 | 设计稿值 | 现有值 | 差异 |
|---------|---------|-------|------|
| 最深背景 `Deep` | `#0a0c14` | 无对应 Token | **缺失** — 需添加 `bgDeep` |
| 悬浮层 `Elevated` | `#1c2038` | `bgElevated=#242432` | **色相偏移** — 设计稿更偏蓝 |
| 控制栏圆角 | `22px (radius-lg)` | `16px` | **差 6px** |
| 毛玻璃模糊 | `20px` | `10px (normal)` | 控制栏实际用 `24px (thick)` ✅ |
| 边缘微光三层 | box-shadow 3 层 | 无专门 Token | **缺失** — 需提取 |
| 透射光效 | radial-gradient | 无专门实现 | **缺失** — 需新增 |
| Hover 光晕追踪 | JS 追踪光标 | 无对应实现 | **缺失** — 需新增 |
| 进度条辉光 | `#4a8eff` + glow | `progressPlayed=#6C5CE7` | **颜色不同** — 设计稿为蓝色，现有为紫色 |

### ❌ 完全缺失

| 设计元素 | 说明 |
|---------|------|
| **边缘微光系统** | 5 层 box-shadow 结构 + 渐变描边 / 锥形柔光 / 脉冲呼吸 3 变体 |
| **透射光效** | 底部透射 + 中心透射 2 种几何模式 |
| **Hover 光晕追踪** | 鼠标跟随 200px 光晕效果 |
| **脉冲呼吸动画** | `@keyframes pulse-border` 3s 循环 |
| **进度条辉光手柄** | 拖拽时白色圆点 + 蓝色光晕 |
| **全局环境光** | body::before 三层径向渐变光场 |
| **字体系统** | SF Pro Display + SF Mono 双字体栈 |
| **圆角系统** | 4 级 radius（8/14/22/32px） |

---

## 五、设计 Token 对齐建议

### 新增 Token（tokens.dart）

```dart
// ── 背景补充 ──
static const bgDeep = Color(0xFF0A0C14);       // 最深背景
static const bgElevated = Color(0xFF1C2038);    // 修正为偏蓝色

// ── 边缘微光 ──
static const glowCore = Color(0xE6A0BEFF);     // rgba(160,190,255,0.9)
static const glowMid = Color(0x40648CFF);       // rgba(100,140,255,0.25)
static const glowEdge = Color(0x265078FF);      // rgba(80,120,255,0.15)
static const glowEdgeStrong = Color(0x596496FF); // rgba(100,150,255,0.35)

// ── 进度条修正 ──
static const progressPlayed = Color(0xFF4A8EFF); // 修正为蓝色（与设计稿一致）

// ── 圆角修正 ──
static const controlBarRadius = 22.0;            // 修正为 22px

// ── 圆角系统 ──
static const radiusSm = 8.0;                     // 按钮、speed 标签
static const radiusMd = 14.0;                    // 色板方块、透射卡片图标
static const radiusLg = 22.0;                    // 卡片、控制栏、hover 区域
static const radiusXl = 32.0;                    // 外框容器

// ── 字体系统 ──
static const fontFamilySans = 'SF Pro Display';  // 主字体
static const fontFamilyMono = 'SF Mono';         // 等宽字体
```

### 新增 Widget

| Widget | 用途 | 优先级 |
|--------|------|--------|
| `EdgeGlow` | 5 层 box-shadow 容器 + 3 变体 | P1 |
| `TransmittedLight` | 底部/中心 2 种透射几何 | P2 |
| `HoverGlowTracker` | 鼠标跟随 200px 光晕 | P3 |
| `PulseBorder` | 脉冲呼吸动画边框 | P3 |

---

## 六、设计语言关键词

```
暗夜深蓝 · 毛玻璃模糊 · 蓝色辉光 · 边缘微光 · 透射散射
极简线条 · 单色图标 · 等宽时间码 · 响应式布局 · 沉浸式
```

---

## 七、决策待确认

1. **进度条颜色**：设计稿为蓝色 `#4a8eff`，现有为紫色 `#6C5CE7` — 是否统一为蓝色？
2. **控制栏圆角**：设计稿 22px，现有 16px — 是否修正？
3. **Elevated 色值**：设计稿 `#1c2038`（偏蓝），现有 `#242432`（偏灰）— 是否修正？
4. **新增效果优先级**：边缘微光（P1）/ 透射（P2）/ Hover 追踪（P3）— 是否按此顺序实现？
5. **Deep 背景**：`#0a0c14` 是否需要作为独立 Token？（当前最深为 `bgBase=#10131E`）
6. **字体系统**：是否将主字体从 `Noto Sans SC` 切换为 `SF Pro Display`？（Windows 上回退到 `Segoe UI`）
7. **全局环境光**：是否需要在 Flutter 中实现 body::before 三层径向渐变光场？
