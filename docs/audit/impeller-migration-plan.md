# Impeller 迁移方案

> Simple Player Flutter — 从 Skia 切换到 Impeller 渲染引擎的完整迁移计划

**文档版本**: v1.0
**创建日期**: 2026-07-20
**状态**: 技术研究

---

## 目录

1. [执行摘要](#1-执行摘要)
2. [Impeller 架构分析](#2-impeller-架构分析)
3. [与 Skia 对比](#3-与-skia-对比)
4. [项目兼容性分析](#4-项目兼容性分析)
5. [迁移方案](#5-迁移方案)
6. [风险评估和回滚方案](#6-风险评估和回滚方案)
7. [性能测试方案](#7-性能测试方案)
8. [实施路线图](#8-实施路线图)

---

## 1. 执行摘要

### 1.1 Impeller 优势

Impeller 是 Flutter 的下一代渲染引擎，从 Skia 迁移到 Impeller 的核心优势：

- **无着色器编译 Jank**: 所有着色器在 Flutter 引擎编译时预编译，运行时无首次使用卡顿
- **更可预测的性能**: 减少帧时间方差，帧率更稳定
- **更低的 CPU 开销**: 更高效的渲染管线，减少 draw call 开销
- **更少的 GPU 内存占用**: 优化的纹理管理和缓冲区复用
- **桌面端原生支持**: Windows 上使用 Direct3D 11 后端，与 fvp 的 D3D11 纹理共享同一 API 层

### 1.2 迁移目标

- 在 Windows 桌面端默认启用 Impeller 渲染引擎
- 确保 fvp 视频纹理 (Texture widget) 在 Impeller 下正常工作
- 确保 Glassmorphism 效果 (BackdropFilter + blur) 在 Impeller 下渲染正确
- 确保 AuroraBackground 自定义画笔在 Impeller 下性能不退化
- 帧率稳定性提升 (Jank 率下降)

### 1.3 预期收益

| 指标 | Skia 现状 | Impeller 预期 | 改善幅度 |
|------|-----------|---------------|----------|
| 首帧 Jank | 存在 (着色器编译) | 消除 | 100% |
| 平均帧时间 | ~8ms | ~6ms | ~25% |
| Jank 帧占比 | ~2-5% | <1% | 75%+ |
| CPU 占用 (播放中) | ~15% | ~10% | ~33% |
| GPU 内存 | 基线 | 下降 10-20% | 10-20% |

---

## 2. Impeller 架构分析

### 2.1 预编译着色器

Impeller 的核心创新是将所有渲染所需的着色器在引擎编译时一次性生成，而非运行时按需编译。

**Skia 的问题**:
- 着色器在首次遇到特定渲染组合时编译
- 编译耗时 10-100ms，导致可见的帧卡顿
- 需要 "Shader Warmup" 变通方案（预热缓存）

**Impeller 的方案**:
- 使用 SkSL (Skia Shading Language) 的变体，在引擎构建时编译为平台原生着色器
- 所有着色器以二进制形式嵌入引擎，运行时零编译开销
- 消除了 "Shader Warmup" 的需要

**对本项目的影响**:
- AuroraBackground 的 Canvas 渲染 (drawImage, drawPoints, radial gradient) 涉及多种着色器组合
- Glassmorphism 的 BackdropFilter + blur 涉及高斯模糊着色器
- 当前 Skia 下首次弹出设置面板/播放列表时可能出现短暂卡顿，Impeller 下将消除

### 2.2 渲染管线

Impeller 使用更高效的渲染管线：

```
Dart → Entity Pass (DisplayList) → Backend (D3D11/MTL/Vulkan) → GPU
```

**与 Skia 管线对比**:

```
Skia:   Dart → DisplayList → SkCanvas → GPU (运行时着色器编译)
Impeller: Dart → Entity Pass → 预编译 Pipeline → GPU (零编译)
```

**关键差异**:
- Impeller 使用 Entity-based 渲染模型，每个绘制操作对应一个 "Entity"
- Entity 可以被引擎优化、合并、重新排序
- 减少了 GPU state change 次数

### 2.3 内存管理

- **纹理池复用**: Impeller 维护纹理池，减少分配/释放开销
- **更小的着色器二进制**: 预编译着色器比运行时编译的着色器占用更少内存
- **Layer 优化**: 对于简单的变换操作，Impeller 可以避免创建中间纹理

### 2.4 Windows D3D11 后端

在 Windows 上，Impeller 使用 Direct3D 11 后端：

- 与 fvp 的 MDK 引擎共享同一 D3D11 设备
- Texture widget 通过 `ID3D11Texture2D` 共享实现跨引擎纹理传递
- 潜在的零拷贝纹理路径（如果 Impeller 和 fvp 共享 D3D11 设备）

---

## 3. 与 Skia 对比

### 3.1 性能对比

| 维度 | Skia | Impeller | 说明 |
|------|------|----------|------|
| 着色器编译 | 运行时按需 | 预编译 | Impeller 消除首次卡顿 |
| Draw Call 开销 | 中等 | 低 | Entity 合并优化 |
| 动画帧率稳定性 | 有波动 | 更稳定 | 无编译中断 |
| 复杂模糊 (BackdropFilter) | GPU 密集 | 优化实现 | Impeller 有专用模糊路径 |
| 文本渲染 | 好 | 好 | 两者差异不大 |
| 大纹理 (视频帧) | 好 | 好 | D3D11 纹理直接传递 |

### 3.2 内存对比

| 维度 | Skia | Impeller |
|------|------|----------|
| 着色器缓存 | 运行时增长，不可预测 | 固定大小，预编译嵌入 |
| 中间纹理 | 按需分配 | 纹理池复用 |
| GPU 显存使用 | 基线 | 下降 10-20% |

### 3.3 兼容性对比

| 维度 | Skia | Impeller |
|------|------|----------|
| CustomPainter 支持 | 完全 | 完全 (Canvas API 兼容) |
| Texture widget | 完全 | 完全 (D3D11 共享) |
| BackdropFilter | 完全 | 完全 (优化实现) |
| BlendMode 支持 | 全部 | 大部分 (个别高级模式可能有差异) |
| ImageFilter.blur | 完全 | 完全 |
| ColorFilter | 完全 | 完全 |
| MaskFilter | 完全 | 完全 |
| saveLayer | 完全 | 完全 (性能更优) |

### 3.4 桌面端 Impeller 成熟度

截至 2026 年中：
- **macOS**: 默认启用 (stable since Flutter 3.22)
- **iOS**: 默认启用 (stable since Flutter 3.22)
- **Windows**: 可选启用，即将默认 (预计 2026 H2)
- **Linux**: 可选启用，Vulkan 后端
- **Android**: 默认启用 (stable since Flutter 3.22)

---

## 4. 项目兼容性分析

### 4.1 渲染特性清单

对本项目使用的所有渲染特性逐一分析 Impeller 兼容性：

#### 4.1.1 Texture Widget (视频渲染)

**文件**: `lib/ui/player/video_surface.dart`

```dart
Texture(textureId: id)
```

- **兼容性**: 完全兼容
- **原理**: Texture widget 通过 `TextureRegistrar` 注册平台纹理。在 Windows 上，fvp 使用 D3D11 `ID3D11Texture2D`。Impeller 的 D3D11 后端支持从外部导入纹理。
- **风险**: 低。纹理共享路径已在 Impeller 的测试矩阵中。
- **验证**: 需确认 fvp 的 `updateTexture()` 在 Impeller 模式下返回的 textureId 有效。

#### 4.1.2 BackdropFilter + ImageFilter.blur (毛玻璃效果)

**文件**: `lib/ui/shared/glass_container.dart`, `lib/ui/player/control_bar.dart`, `lib/ui/playlist/playlist_panel.dart`, `lib/ui/dialogs/settings_panel.dart`

- **兼容性**: 完全兼容
- **原理**: Impeller 有优化的模糊实现，可能比 Skia 更快
- **风险**: 低。模糊是 Impeller 重点优化的场景。
- **注意**: 项目已实现 blur 降级 (`blurEnabled=false`) 和 resize 期间跳过 (`resizing` 信号)，这些优化在 Impeller 下仍然有价值。
- **验证**: 需对比 3 个 GlassTier (thin=8, normal=11.5, thick=24) 的渲染结果是否一致。

#### 4.1.3 CustomPainter (极光背景)

**文件**: `lib/ui/shared/aurora_background.dart`

使用的 Canvas API:
- `drawRect` — 兼容
- `drawCircle` + `Gradient.radial` — 兼容
- `drawImage` (带 scale/translate 变换) — 兼容
- `drawPicture` — 兼容
- `drawPoints` (PointMode.points) — 兼容
- `saveLayer` + `ColorFilter.mode` + `ImageFilter.blur` — 兼容

- **兼容性**: 完全兼容
- **风险**: 低。所有使用的 Canvas API 都是 Impeller 一等支持的。
- **验证**: 需对比 AuroraBackground 的视觉输出，确认色彩和模糊效果一致。

#### 4.1.4 ClipRRect + RepaintBoundary

- **兼容性**: 完全兼容
- **原理**: 这是最基础的 Flutter 渲染原语

#### 4.1.5 ColorFilter + BlendMode

**文件**: `lib/ui/shared/aurora_background.dart`

```dart
..colorFilter = ui.ColorFilter.mode(color, ui.BlendMode.srcIn)
```

- **兼容性**: 完全兼容
- **风险**: 低。`BlendMode.srcIn` 是常用混合模式。

#### 4.1.6 MaskFilter.blur (边缘光效)

**文件**: `lib/ui/shared/edge_glow.dart`

```dart
..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
```

- **兼容性**: 完全兼容
- **风险**: 低

#### 4.1.7 BoxShadow (阴影)

**文件**: `lib/ui/player/control_bar.dart`

- **兼容性**: 完全兼容
- **原理**: BoxShadow 由 Flutter framework 层处理，不直接依赖引擎着色器

### 4.2 依赖项兼容性

| 依赖 | 版本 | Impeller 兼容性 | 说明 |
|------|------|----------------|------|
| fvp | ^0.37.2 | **需验证** | D3D11 纹理路径，核心风险点 |
| window_manager | ^0.5.2 | 兼容 | 窗口管理，不涉及渲染 |
| shared_preferences | ^2.5.5 | 兼容 | 键值存储，不涉及渲染 |
| ffi | ^2.1.0 | 兼容 | FFI 桥接，不涉及渲染 |
| win32 | (pubspec.lock) | 兼容 | Win32 API，不涉及渲染 |

### 4.3 fvp 兼容性深入分析

fvp 是最关键的依赖项，因为它直接涉及视频纹理的创建和传递：

**当前 fvp 纹理路径 (Skia)**:
```
MDK 解码帧 → D3D11 Texture2D → TextureRegistrar → Flutter Texture Widget (Skia 渲染)
```

**预期 fvp 纹理路径 (Impeller)**:
```
MDK 解码帧 → D3D11 Texture2D → TextureRegistrar → Flutter Texture Widget (Impeller 渲染)
```

**关键问题**:
1. fvp 使用 `FlutterDesktopTextureRegistrarRegisterExternalTexture` 注册纹理
2. Impeller 的 D3D11 后端需要从同一 D3D11 设备读取纹理
3. 如果 fvp 和 Impeller 使用不同的 D3D11 设备，可能需要纹理拷贝

**验证步骤**:
1. 检查 fvp 是否共享 Flutter 引擎的 D3D11 设备
2. 启用 Impeller 后运行视频播放，确认纹理正常显示
3. 检查是否有纹理拷贝导致的性能退化

### 4.4 Windows 平台特定考量

- **D3D11 版本**: Windows 10+ 均支持 D3D11.1，满足 Impeller 要求
- **GPU 驱动**: Impeller 对驱动版本要求不高 (D3D11 是 2009 年的标准)
- **窗口合成**: `window_manager` 的 frameless 窗口与 Impeller 无冲突
- **全屏切换**: WS_THICKFRAME / SetWindowPos 全屏方案不涉及渲染引擎

---

## 5. 迁移方案

### 5.1 Phase 1: 准备 (Pre-Migration)

#### 5.1.1 建立性能基线

在 Skia 下运行完整的性能基准测试，记录：

- 启动时间 (cold start)
- 视频打开到首帧渲染时间
- 控制栏弹出/收起动画帧率
- 设置面板打开帧率
- 播放列表面板打开帧率
- AuroraBackground 单独渲染帧率
- 全屏切换帧率
- 内存占用 (RSS, GPU)

**工具**: Flutter DevTools Performance, PerfMonitor (项目内置), Windows Task Manager

#### 5.1.2 建立视觉回归测试基线

截取关键 UI 状态的截图作为对比基准：

- 空状态 (AuroraBackground)
- 视频播放中 (Texture + ControlBar)
- 毛玻璃控制栏 (GlassContainer + BackdropFilter)
- 设置面板 (多层 GlassContainer)
- 播放列表面板 (GlassContainer + ClipRRect)
- 极光背景 + 视频叠加

#### 5.1.3 确认 fvp 兼容性

- 检查 fvp changelog 是否提到 Impeller 支持
- 在 fvp GitHub issues 中搜索 "impeller" 相关问题
- 如有必要，升级 fvp 到最新版本

#### 5.1.4 更新 Flutter SDK

确保使用支持 Windows Impeller 的 Flutter 版本：
- Flutter 3.22+ (Impeller Windows 稳定版)
- 确认 `--enable-impeller` 标志在 Windows 上可用

### 5.2 Phase 2: 测试 (Testing)

#### 5.2.1 启用 Impeller 运行应用

```bash
# 方式 1: 命令行标志
flutter run -d windows --enable-impeller

# 方式 2: 编译时配置 (engine 构建参数)
# --enable-impeller --impeller-force-gl

# 方式 3: 运行时配置 (Flutter 3.22+)
# 在 main.dart 中:
#   await initializeImpeller();
```

#### 5.2.2 逐功能验证清单

| # | 功能 | 验证项 | 优先级 |
|---|------|--------|--------|
| 1 | 视频播放 | Texture 正常显示，无花屏/黑屏 | P0 |
| 2 | 视频播放 | 纹理比例正确 (aspectRatio) | P0 |
| 3 | 视频播放 | 帧率稳定 (无额外 Jank) | P0 |
| 4 | 视频播放 | seek 后纹理更新正常 | P0 |
| 5 | 控制栏 | BackdropFilter 模糊效果正确 | P1 |
| 6 | 控制栏 | 弹出/收起动画流畅 | P1 |
| 7 | 设置面板 | 多层模糊正确叠加 | P1 |
| 8 | 播放列表 | 毛玻璃效果正确 | P1 |
| 9 | AuroraBackground | 极光渐变正确 | P1 |
| 10 | AuroraBackground | 光团运动流畅 | P2 |
| 11 | OSD | 浮动消息显示正确 | P2 |
| 12 | 进度条 | 缩略图弹窗正确 | P2 |
| 13 | 全屏切换 | 切换帧率正常 | P1 |
| 14 | 窗口 resize | 无撕裂/闪烁 | P1 |
| 15 | 视频色彩校正 | ColorFilter 效果一致 | P2 |

#### 5.2.3 对比测试

- 逐项对比 Skia 和 Impeller 的视觉输出
- 使用 `RepaintBoundary` + 截图 API 自动化视觉回归
- 记录任何视觉差异（模糊半径、颜色、透明度）

### 5.3 Phase 3: 迁移 (Migration)

#### 5.3.1 配置变更

**方案 A: 命令行标志 (推荐初期)**

不修改代码，仅在启动时传入标志：
```bash
flutter run -d windows --enable-impeller
```

**方案 B: 编译时配置 (推荐中期)**

在 `windows/runner/CMakeLists.txt` 中添加：
```cmake
target_compile_definitions(${BINARY_NAME} PRIVATE
  "FLUTTER_ENABLE_IMPELLER=1"
)
```

**方案 C: 运行时配置 (推荐长期)**

```dart
// lib/main.dart
void main() {
  // Impeller 是默认引擎，无需特殊配置
  // 如果需要显式禁用 (回滚):
  //   WidgetsFlutterBinding.ensureInitialized();
  //   await initializeImpeller(enabled: false);
  runApp(const SimplePlayerApp());
}
```

#### 5.3.2 代码变更

**预期变更**: 零或极少。

Impeller 是渲染引擎替换，不改变 Flutter API。理论上不需要修改应用代码。可能的例外：

1. **如果 fvp 需要升级**: 更新 `pubspec.yaml` 中的 fvp 版本
2. **如果发现 BlendMode 差异**: 调整 `aurora_background.dart` 中的混合模式
3. **如果模糊效果有细微差异**: 微调 `Tokens.glassBlur*` 常量

#### 5.3.3 性能优化机会

启用 Impeller 后，可以移除 Skia 特定的优化变通方案：

- **AuroraBackground 的 15fps 降级**: 如果 Impeller 的 Canvas 渲染足够快，可以恢复 60fps
- **GlassContainer 的 blurEnabled 降级**: 如果 Impeller 的模糊实现更快，低配设备可能不需要降级
- **resize 期间跳过 BackdropFilter**: 如果 Impeller 的 GPU readback 更快，可以减少跳过条件

### 5.4 Phase 4: 验证 (Validation)

#### 5.4.1 性能验证

重新运行 Phase 1 的性能基线测试，对比结果：

- 所有指标应持平或改善
- Jank 帧占比应显著下降
- 内存占用不应增加

#### 5.4.2 稳定性验证

- 连续播放 2 小时无崩溃
- 反复打开/关闭设置面板 100 次无异常
- 反复全屏/窗口切换 50 次无异常
- 拖拽文件加载 50 个视频无异常

#### 5.4.3 兼容性验证

- 测试至少 5 种不同视频格式 (MP4/MKV/AVI/WebM/FLV)
- 测试至少 3 种分辨率 (720p/1080p/4K)
- 测试至少 2 种 GPU (NVIDIA/AMD/Intel 集显)

---

## 6. 风险评估和回滚方案

### 6.1 风险矩阵

| 风险 | 概率 | 影响 | 等级 | 缓解措施 |
|------|------|------|------|----------|
| fvp 纹理不兼容 | 中 | 高 | **高** | 提前验证; 准备 fvp 升级或降级方案 |
| 毛玻璃效果渲染差异 | 低 | 中 | **中** | 视觉回归测试; 微调参数 |
| 某些 BlendMode 不支持 | 低 | 低 | **低** | 只使用常见 BlendMode |
| 低配 GPU 性能退化 | 低 | 中 | **中** | 多 GPU 测试; 保留降级路径 |
| Flutter SDK 版本不兼容 | 低 | 高 | **中** | 锁定 Flutter 版本; CI 测试 |
| D3D11 设备共享冲突 | 低 | 高 | **中** | fvp 作者沟通; 验证共享路径 |

### 6.2 回滚方案

#### 6.2.1 快速回滚 (分钟级)

如果使用命令行标志启用：
```bash
# 移除 --enable-impeller 标志即可回滚到 Skia
flutter run -d windows
```

如果使用编译时配置：
- 修改 CMakeLists.txt，移除 `FLUTTER_ENABLE_IMPELLER` 定义
- 重新编译

#### 6.2.2 Git 回滚

- 迁移期间使用独立分支 (`feat/impeller-migration`)
- 所有变更通过 PR 合并，可随时 revert
- 确保 master 分支始终可用 Skia 构建

#### 6.2.3 运行时回滚 (如果实现)

在设置中添加 "使用 Impeller" 开关：
- 默认启用 Impeller
- 用户可手动切换回 Skia
- 需要重启应用生效

### 6.3 降级策略

如果 Impeller 在某些场景下表现不佳：

1. **场景级降级**: 对特定场景禁用 BackdropFilter (已有 `blurEnabled` 支持)
2. **功能级降级**: 对 AuroraBackground 禁用动画 (已有引擎状态暂停支持)
3. **全局回滚**: 完全回退到 Skia

---

## 7. 性能测试方案

### 7.1 测试环境

| 配置 | 规格 |
|------|------|
| 测试机 A (高配) | Intel i7-13700K, NVIDIA RTX 4070, 32GB RAM |
| 测试机 B (中配) | Intel i5-12400, NVIDIA GTX 1650, 16GB RAM |
| 测试机 C (低配) | Intel i5-8250U, Intel UHD 620, 8GB RAM |
| OS | Windows 11 23H2+ |
| Flutter | 3.29.x (stable) |

### 7.2 测试指标

#### 7.2.1 帧率指标

| 指标 | 工具 | 目标 |
|------|------|------|
| 平均帧时间 | PerfMonitor / DevTools | <16.6ms (60fps) |
| P95 帧时间 | DevTools Timeline | <33ms |
| P99 帧时间 | DevTools Timeline | <50ms |
| Jank 帧占比 | DevTools | <1% |
| 严重 Jank 占比 | DevTools | <0.1% |

#### 7.2.2 内存指标

| 指标 | 工具 | 目标 |
|------|------|------|
| RSS (驻留内存) | Task Manager / PerfMonitor | <300MB |
| Dart 堆 | DevTools Memory | <50MB |
| GPU 内存 | GPU-Z / DevTools | 不超过 Skia 基线 |

#### 7.2.3 CPU 指标

| 指标 | 工具 | 目标 |
|------|------|------|
| 播放中 CPU 占用 | Task Manager | <15% |
| 空闲 CPU 占用 | Task Manager | <1% |
| 启动 CPU 峰值 | DevTools | <50% |

### 7.3 测试场景

#### 7.3.1 启动场景

```
Cold Start → AuroraBackground 渲染 → 空状态显示
测量: 启动时间, 首帧渲染时间
```

#### 7.3.2 视频播放场景

```
Open File → 解码 → 首帧渲染 → 持续播放 60s
测量: 打开延迟, 首帧时间, 播放帧率, Jank 率
```

#### 7.3.3 控制栏交互场景

```
播放中 → 鼠标移动 → 控制栏弹出 → 鼠标移开 → 控制栏收起
重复 50 次
测量: 弹出动画帧率, BackdropFilter 渲染时间
```

#### 7.3.4 设置面板场景

```
打开设置面板 → 切换 Tab → 关闭面板
重复 20 次
测量: 打开帧率, Tab 切换帧率, 内存增长
```

#### 7.3.5 播放列表场景

```
打开播放列表 → 滚动缩略图 → 切换文件夹/历史 Tab → 关闭
测量: 打开帧率, 滚动帧率, 缩略图加载
```

#### 7.3.6 全屏切换场景

```
窗口模式 → 全屏 → 窗口模式
重复 30 次
测量: 切换耗时, 帧率波动
```

#### 7.3.7 持续播放压力测试

```
播放 4K 视频 → 持续 2 小时
测量: 内存增长趋势, CPU 占用趋势, 是否崩溃
```

### 7.4 自动化测试脚本

```dart
// test/performance/impeller_benchmark.dart
// 使用 integration_test + flutter_driver 自动化性能测试

import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Impeller Performance Benchmark', () {
    testWidgets('cold start time', (tester) async {
      final stopwatch = Stopwatch()..start();
      await tester.pumpWidget(const SimplePlayerApp());
      await tester.pumpAndSettle();
      stopwatch.stop();
      // 记录启动时间
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
    });

    testWidgets('control bar animation jank-free', (tester) async {
      // 模拟鼠标移动触发控制栏
      // 使用 DevTools Timeline 验证无 Jank
    });
  });
}
```

---

## 8. 实施路线图

### 8.1 Phase 1: 基线建立与兼容性验证 (Week 1-2)

**目标**: 确认 Impeller 在当前项目上可行

| 任务 | 时间 | 交付物 |
|------|------|--------|
| 建立 Skia 性能基线 | 2 天 | 性能基线报告 |
| 建立视觉回归基线截图 | 1 天 | 截图目录 |
| 检查 fvp Impeller 兼容性 | 1 天 | 兼容性报告 |
| 启用 Impeller 运行应用 | 1 天 | 初步兼容性评估 |
| 逐功能验证 (P0 项) | 2 天 | 功能验证清单 |
| 对比 Skia vs Impeller 视觉 | 1 天 | 差异报告 |
| 风险评估与缓解方案 | 1 天 | 更新后的风险矩阵 |

**里程碑**: 确认 Impeller 可行，无 P0 兼容性阻塞

### 8.2 Phase 2: 性能验证与优化 (Week 3-4)

**目标**: 确认 Impeller 性能优于或持平 Skia

| 任务 | 时间 | 交付物 |
|------|------|--------|
| 全场景性能对比测试 | 3 天 | 性能对比报告 |
| 多 GPU 兼容性测试 | 2 天 | GPU 兼容性矩阵 |
| 持续播放稳定性测试 | 2 天 | 稳定性报告 |
| 识别 Impeller 优化机会 | 1 天 | 优化建议清单 |
| 实施优化 (移除 Skia 变通) | 2 天 | 优化后的代码 |
| 编写自动化性能测试 | 2 天 | CI 性能测试 |

**里程碑**: 性能验证通过，优化方案确定

### 8.3 Phase 3: 生产部署 (Week 5-6)

**目标**: 默认启用 Impeller

| 任务 | 时间 | 交付物 |
|------|------|--------|
| 合并 Impeller 配置到主分支 | 1 天 | PR + Code Review |
| 更新文档 (CLAUDE.md, README) | 1 天 | 更新的文档 |
| 更新 CI/CD 流水线 | 1 天 | CI 配置 |
| 回滚方案文档确认 | 0.5 天 | 回滚 Runbook |
| Beta 用户测试 | 3 天 | 用户反馈 |
| 监控与告警设置 | 1 天 | 监控面板 |
| 正式发布 | 0.5 天 | Release Notes |

**里程碑**: Impeller 默认启用，监控就绪，回滚方案就绪

### 8.4 关键决策点

| 决策点 | 时间 | 决策依据 |
|--------|------|----------|
| Go/No-Go: fvp 兼容性 | Week 1 末 | fvp 纹理在 Impeller 下是否正常 |
| Go/No-Go: 性能验证 | Week 3 末 | 性能是否持平或改善 |
| Go/No-Go: 生产部署 | Week 5 末 | 所有验证通过，无阻塞性问题 |

---

## 附录

### A. 当前渲染特性使用清单

| 特性 | 使用位置 | Impeller 影响 |
|------|----------|---------------|
| `Texture` widget | `video_surface.dart` | 需验证 D3D11 纹理共享 |
| `BackdropFilter` + blur | `glass_container.dart`, `control_bar.dart`, `playlist_panel.dart`, `settings_panel.dart` | 优化路径 |
| `CustomPainter` + Canvas | `aurora_background.dart` | 完全兼容 |
| `ClipRRect` | 多处 | 完全兼容 |
| `RepaintBoundary` | 多处 | 完全兼容 |
| `ColorFilter.mode` + `BlendMode.srcIn` | `aurora_background.dart` | 完全兼容 |
| `ImageFilter.blur` | `glass_container.dart`, `aurora_background.dart` | 完全兼容 |
| `MaskFilter.blur` | `edge_glow.dart` | 完全兼容 |
| `Gradient.radial` | `aurora_background.dart` | 完全兼容 |
| `saveLayer` | `aurora_background.dart` | 完全兼容，性能更优 |
| `drawPoints` (PointMode) | `aurora_background.dart` | 完全兼容 |
| `BoxShadow` | `control_bar.dart` | 完全兼容 |
| `ScaleTransition` | `glass_container.dart` | 完全兼容 |

### B. 参考资料

- [Impeller 官方文档](https://docs.flutter.dev/perf/impeller)
- [Flutter Impeller 路线图](https://github.com/flutter/flutter/wiki/Impeller-Roadmap)
- [fvp 插件仓库](https://github.com/wang-bin/fvp)
- [Flutter Texture 文档](https://api.flutter.dev/flutter/widgets/Texture-class.html)
- [Impeller Windows 状态](https://github.com/flutter/flutter/issues/128923)

### C. 术语表

| 术语 | 说明 |
|------|------|
| Impeller | Flutter 的下一代渲染引擎，替代 Skia |
| Skia | Flutter 的默认渲染引擎 (Google 开源 2D 图形库) |
| D3D11 | Direct3D 11, Windows 图形 API |
| Texture Widget | Flutter 的平台纹理渲染组件 |
| BackdropFilter | Flutter 的背景模糊 Widget |
| saveLayer | Canvas 的图层合成操作 |
| Entity Pass | Impeller 的渲染单元 |
| Jank | 帧率卡顿 |
| GPU Readback | GPU 到 CPU 的数据回读 (性能敏感) |
