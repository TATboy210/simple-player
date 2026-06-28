# Simple Player — 完整产品发行计划 (v2.0 Roadmap)

> Generated: 2026-06-26 | Updated: 2026-06-26 | Stage: **Production**
> Skills: release-checklist · launch-checklist · team-release · project-stage-detect · milestone-review

---

## 0. 项目阶段评估 (project-stage-detect)

| 维度 | 状态 | 详情 |
|------|------|------|
| **阶段** | Production | 62 测试文件、~93 源文件、5 层架构完整 |
| **代码健康** | 48 issues (10 error / 8 warning / 30 info) | error 全在 `media_info_dialog.dart`，info 为 lint |
| **TODO/FIXME** | 2 处 | `display_config.dart:1`, `macos_thumbnail_provider.dart:1` |
| **测试覆盖** | 62 test files | 覆盖 Kernel/Bridge/Service/UI 各层 |
| **架构成熟度** | HIGH | Strategy/Bridge/Facade/CQS 模式，DI 注入，防抖原子持久化 |
| **跨平台** | Windows only (macOS/Linux 代码已有但未验证) | D3D11 硬编码是 #1 gap |

**阶段置信度:** PASS — 明确处于 Production 阶段，核心功能完整，缺跨平台验证和打包。

---

## 1. 产品定位

### 一句话描述
**桌面端全格式硬件加速媒体播放器** — 基于 Flutter + fvp (MDK/FFmpeg)，支持 Windows/macOS/Linux 三平台，现代毛玻璃 UI。

### 目标用户画像

| 用户群 | 痛点 | 我们的解法 | 优先级 |
|--------|------|-----------|--------|
| **桌面影音爱好者** | VLC 界面老旧、PotPlayer 仅 Windows | 现代毛玻璃 UI + 三平台一致体验 | P0 |
| **开发者/极客** | 需要开源、可定制的播放器 | Flutter 开源、架构清晰、易扩展 | P0 |
| **Steam Deck 用户** | 缺少高质量本地播放器 | Steam 上架 + 触屏适配 | P1 |
| **多设备用户** | 不同平台用不同播放器 | 跨平台统一播放列表和设置 | P1 |

### 竞争分析 (5 竞品深度对比)

| 维度 | VLC | PotPlayer | mpv | IINA | SKYBOX VR | **Simple Player** |
|------|-----|-----------|-----|------|-----------|-------------------|
| 平台 | 全平台 | Windows | 全平台 | macOS | Quest/Steam | Win/Mac/Linux |
| UI  | 老旧 | 过时 | CLI | 精美 | VR 沉浸 | **毛玻璃现代** |
| 硬解 | 有 | 有 | 有 | 有 | 有 | **D3D11/VT/VAAPI** |
| 开源 | ✅ | ❌ | ✅ | ✅ | ❌ | ✅ |
| 格式 | 全 | 全 | 全 | 全 | VR+全 | 全 (MDK/FFmpeg) |
| 定价 | 免费 | 免费 | 免费 | 免费 | $9.99→订阅 | **免费+Steam买断** |
| 弱点 | UI过时 | 仅Win | CLI门槛 | 仅Mac | 更新bug多 | 新项目 |

### 核心卖点 (USP)
1. **全格式硬件加速** — D3D11 (Windows) / VideoToolbox (macOS) / VA-API (Linux)
2. **现代毛玻璃 UI** — GlassContainer 3-tier blur，Aurora 背景，响应式布局
3. **三平台一致体验** — 同一套 UI、同一套快捷键 (20+)、同一套播放逻辑
4. **极客友好** — 开源、键盘驱动、可扩展 5 层架构
5. **mpv 级解码** — fvp 底层就是 MDK/FFmpeg，格式兼容性不输 VLC/mpv

---

## 2. 技术架构总览

```
┌──────────────────────────────────────────────────────┐
│                     UI Layer (25 files ~6000 LoC)      │
│  PlayerScreen / ControlsOverlay / PlaylistPanel       │
│  GlassContainer 3-tier blur / AuroraBackground        │
│  ValueNotifier + ValueListenableBuilder (零 Bloc)      │
├──────────────────────────────────────────────────────┤
│                  Service Layer (mixin 组合)             │
│  PlaybackController = FileOps + Navigator + Monitor   │
│  ThumbnailService (LRU cache) / SubtitleService       │
│  VideoProcessingService / PathValidator (22 格式)      │
├──────────────────────────────────────────────────────┤
│                   Bridge Layer (DI + Strategy)          │
│  WindowBridge (抽象接口 + NoopWindowBridge 降级)        │
│  PlatformFullscreen (Win32 FFI / macOS MC / GTK3 FFI) │
│  WindowPersistence (原子 .tmp+rename, debounce)        │
├──────────────────────────────────────────────────────┤
│                  Kernel Layer (零 UI 依赖)              │
│  FvpEngine (fvp/MDK + FFmpeg + D3D11)                 │
│  Playlist (CQS 状态机, peekNext 不修改状态)             │
│  PlaylistStore (300ms debounce + 原子写入)              │
│  SettingsStore (SharedPreferences ~20 keys)            │
├──────────────────────────────────────────────────────┤
│                Native Platform (runner)                 │
│  Windows: C++ runner + D3D11 + WM_SIZING/WM_NCCALCSIZE│
│  macOS: Swift runner + Metal + MethodChannel           │
│  Linux: C runner + GTK3 + Wayland/X11 双路径           │
└──────────────────────────────────────────────────────┘
```

### 关键技术指标

| 指标 | 目标 | 当前状态 |
|------|------|----------|
| 4K 60fps 播放 | 流畅 (硬解) | ✅ Windows D3D11 |
| 启动到首帧 | < 1s | ✅ prewarm 机制 |
| 内存占用 | < 200MB | ✅ MemoryMonitor |
| 安装包大小 | < 50MB | 待打包验证 |
| 支持格式 | 20+ (MP4/MKV/AVI/MOV/WebM/FLV...) | ✅ MDK/FFmpeg |
| 快捷键 | 20+ | ✅ KeyboardHandler |
| 测试文件 | 60+ | ✅ 62 files |

---

## 3. 版本规划

### v1.0 — Windows 稳定版 (当前 → 2 周内)

**目标：** 夯实 Windows 主力平台，修复已知问题，准备首次公开发布。

#### P0 — 必须修复 (阻塞发布)

| # | 类别 | 项目 | 文件 | 预估 |
|---|------|------|------|------|
| 1 | 🔴 Bug | media_info_dialog.dart 10 个编译错误 | `lib/ui/dialogs/media_info_dialog.dart:51-53` | 2h |
| 2 | 🔴 Bug | open() 成功后不设 idle 状态 | `lib/kernel/engine/fvp_engine.dart:136-277` | 1h |
| 3 | 🔴 Bug | seekTo 与 buffering 状态竞态 | `lib/kernel/engine/fvp_engine.dart:319-343` | 2h |
| 4 | 🟡 Lint | 8 warnings (unused imports/variables/casts) | 多文件 | 30min |

#### P1 — 重要优化

| # | 类别 | 项目 | 文件 | 预估 |
|---|------|------|------|------|
| 5 | 🟡 优化 | MediaErrorType.network 错误类型 | `media_error_type.dart` | 30min |
| 6 | 🟡 优化 | PlaylistStore 写入失败重试 + .bak 轮转 | `playlist_store.dart` | 30min |
| 7 | 🟡 优化 | ThumbnailCache LRU 缓存 | 新增 + `thumbnail_tile.dart` | 1h |
| 8 | 🟡 优化 | FFmpeg 网络参数配置 | `fvp_engine.dart` | 1h |
| 9 | 🟡 优化 | FolderTab 分组结果缓存 | `folder_tab.dart` | 30min |

#### P2 — 体验提升

| # | 类别 | 项目 | 预估 |
|---|------|------|------|
| 10 | 🟢 体验 | 刷新率检测平台化 (60Hz → 真实值) | 2h |
| 11 | 🟢 体验 | subtitleDelay 捕获具体异常类型 | 15min |

#### 📦 发布打包

| # | 项目 | 预估 |
|---|------|------|
| 12 | Windows x86_64 安装包 (MSIX/Inno Setup) | 1d |
| 13 | winget manifest 提交 | 2h |
| 14 | GitHub Release + Release Notes | 2h |

**v1.0 里程碑标准 (milestone-review):**
- [ ] 零 S1/S2 Bug（当前 S1: media_info_dialog 编译错误, open() 状态 bug）
- [ ] `flutter analyze` 零 error（当前 10 个 error）
- [ ] 主流格式 (MP4/MKV/AVI/MOV) 硬解验证
- [ ] 20+ 快捷键全部可用
- [ ] 播放列表持久化可靠 (debounce + 原子写入)
- [ ] 4K 60fps 流畅播放
- [ ] 安装包可正常安装/卸载

**Go/No-Go 评估:**
- **当前状态:** NOT READY — 10 个编译错误 + 2 个 P0 bug
- **预计就绪:** 修复 #1-#4 后 → CONDITIONAL GO
- **完全就绪:** 修复 #1-#9 后 → GO

---

### v1.5 — 跨平台桌面版 (v1.0 后 → 3-4 周)

**目标：** macOS + Linux 原生支持，三平台统一发布。

#### P0 — 跨平台核心 (阻塞跨平台发布)

| # | 类别 | 项目 | 详情 | 预估 |
|---|------|------|------|------|
| 1 | 🔴 跨平台 | 解码器配置平台化 | D3D11→Windows, VideoToolbox→macOS, VA-API→Linux | 1d |
| 2 | 🔴 跨平台 | D3D11 属性 Platform.isWindows 守卫 | 防止 macOS/Linux 加载 D3D11 | 2h |
| 3 | 🔴 跨平台 | CI 构建矩阵 (6 目标) | Win x64/arm64, Mac x64/arm64, Linux x64/arm64 | 2d |

#### P1 — 平台功能补齐

| # | 类别 | 项目 | 详情 | 预估 |
|---|------|------|------|------|
| 4 | 🟡 功能 | macOS 缩略图 | QLThumbnailGenerator 替换 stub | 2d |
| 5 | 🟡 功能 | Linux 缩略图自生成 | ffmpeg CLI fallback (XDG cache 只读) | 1d |
| 6 | 🟡 打包 | macOS Universal Binary | arm64 + x86_64 fat binary | 1d |
| 7 | 🟡 打包 | Linux .deb / .AppImage | dpkg-deb + appimagetool | 1d |
| 8 | 🟡 分发 | Homebrew Cask | macOS brew install | 2h |
| 9 | 🟡 分发 | Flatpak (Flathub) | Linux 沙盒包 | 1d |

#### P2 — ARM64 验证

| # | 类别 | 项目 | 风险 | 预估 |
|---|------|------|------|------|
| 10 | 🟢 验证 | Windows ARM64 构建 | 依赖 fvp ARM64 二进制 | 1d |
| 11 | 🟢 验证 | Linux arm64 交叉编译 | 依赖 fvp ARM64 二进制 | 1d |

**跨平台差距分析 (来自 project_cross_platform_desktop):**

| # | Gap | 影响 | 现状 | 修复方案 |
|---|-----|------|------|----------|
| 1 | 解码器字符串硬编码 | macOS/Linux 回退软解 | `'D3D11:shader_resource=1,NVDEC,FFmpeg'` | 平台检测 + 条件配置 |
| 2 | D3D11 Configurator | 仅 Windows 有 | `d3d11_configurator.dart` | Platform.isWindows guard |
| 3 | CI 矩阵缺失 | 无法自动构建跨平台 | ubuntu + macos only | 添加 windows + 6 目标 |
| 4 | macOS 缩略图 stub | macOS 无缩略图 | always returns null | QLThumbnailGenerator |
| 5 | Linux 缩略图只读 | 无法生成新缩略图 | XDG cache read-only | ffmpeg CLI fallback |
| 6 | ARM64 未验证 | ARM 设备不可用 | 未测试 | fvp 二进制验证 |

**v1.5 里程碑标准:**
- [ ] 三平台构建通过 (Windows x64, macOS arm64, Linux x64)
- [ ] 各平台硬件加速生效（非 FFmpeg 软解回退）
- [ ] macOS/Linux 全屏功能正常 (PlatformFullscreen Strategy 模式)
- [ ] 缩略图在所有平台可用
- [ ] CI 自动构建 + 发布 (GitHub Actions 6 目标矩阵)
- [ ] Homebrew + Flatpak 分发可用

---

### v2.0 — 体验增强版 (v1.5 后 → 4-6 周)

**目标：** Impeller 迁移 + 网络流 + Steam 上架。

#### P0 — 渲染升级

| # | 类别 | 项目 | 详情 | 预估 |
|---|------|------|------|------|
| 1 | 🔴 渲染 | Impeller 迁移验证 | Windows 默认已启用，macOS Metal，Linux Vulkan | 3d |
| 2 | 🔴 渲染 | BackdropFilter 重构 | GlassContainer 6 处 GPU readback 优化 | 3d |
| 3 | 🔴 渲染 | FragmentShader 预编译 | glass_blur.frag + aurora_blob.frag | 2d |

#### P1 — 网络流 + Steam

| # | 类别 | 项目 | 详情 | 预估 |
|---|------|------|------|------|
| 4 | 🟡 功能 | HLS 自适应码率 (ABR) | Throughput-based → BBA → MPC 渐进 | 1w |
| 5 | 🟡 功能 | RTSP 低延迟流 | fflags +nobuffer + setBufferRange(drop) | 3d |
| 6 | 🟡 发布 | Steam 商店页面 + 上架 | $100 注册 + 商店页 + 审核 | 2d |
| 7 | 🟡 发布 | Steam Deck 触屏/手柄适配 | hit area 48dp + Steam Input SDK | 3d |
| 8 | 🟡 发布 | Steam Cloud 同步 | 播放列表 + 设置 | 2d |

#### P2 — 高级功能

| # | 类别 | 项目 | 预估 |
|---|------|------|------|
| 9 | 🟢 功能 | DLNA/SMB 网络串流 | 1w |
| 10 | 🟢 功能 | Steam 成就系统 | 1d |
| 11 | 🟢 功能 | Rich Presence ("正在播放 xxx.mp4") | 1d |

**Impeller 迁移风险矩阵:**

| 风险等级 | 组件 | 关键问题 |
|---------|------|---------|
| HIGH | BackdropFilter (5文件6处) | Impeller framebuffer readback 开销 |
| MEDIUM-HIGH | fvp Texture D3D11→Vulkan interop | 需运行时验证 |
| LOW | ClipRRect, Opacity/FadeTransition | Impeller 原生支持 |

**v2.0 里程碑标准:**
- [ ] Impeller 渲染无卡顿（shader 预热完成）
- [ ] HLS/RTSP 网络流可播放
- [ ] Steam 上架 + Steam Deck 验证通过
- [ ] 无 shader 编译卡顿（预编译）
- [ ] Steam Cloud 同步可用

---

## 4. 分发渠道规划

### 渠道矩阵

| 渠道 | 平台 | 形式 | 版本 | 优先级 | 状态 |
|------|------|------|------|--------|------|
| **GitHub Releases** | Win/Mac/Linux | 安装包 + 便携版 | v1.0 起 | P0 | 待打包 |
| **winget** | Windows | 包管理器 | v1.0 起 | P0 | 待 manifest |
| **Homebrew** | macOS | Cask | v1.5 起 | P1 | 待 formula |
| **Flatpak (Flathub)** | Linux | 沙盒包 | v1.5 起 | P1 | 待 manifest |
| **Steam** | Win/Mac/Linux | 商店应用 | v2.0 | P1 | 待注册 |

### 分发时间线

```
v1.0: GitHub Releases (Win x64) + winget
      └── 首发渠道，零成本，快速迭代

v1.5: + Homebrew (macOS) + Flatpak (Linux)
      └── 覆盖三平台主要包管理器

v2.0: + Steam 商店
      └── 商业化渠道，$100 注册费
```

### 打包技术选型

| 平台 | 格式 | 工具 | 优势 |
|------|------|------|------|
| Windows | MSIX | `flutter build windows` + msix 打包 | Windows Store 兼容、自动更新 |
| Windows | EXE | Inno Setup | 传统安装器、零依赖 |
| macOS | .app + .dmg | `flutter build macos` + create-dmg | 标准 macOS 分发 |
| Linux | .deb | dpkg-deb | Ubuntu/Debian 用户最多 |
| Linux | .AppImage | appimagetool | 零安装、便携 |
| Linux | .flatpak | flatpak-builder | 沙盒、Flathub 分发 |
| Steam | depot | Steamworks SDK | 商店曝光 + Steam Deck |

---

## 5. 营销策略

### 发布前 (v1.0 前 2 周)

| 项目 | 渠道 | 详情 |
|------|------|------|
| GitHub README 升级 | GitHub | 截图 + GIF + 功能列表 + 徽章 |
| Landing Page | GitHub Pages | 产品介绍 + 下载链接 + 截图 |
| 演示视频 | YouTube/Bilibili | 30s 精华 + 2min 功能展示 |
| 发帖准备 | HN/Reddit/V2EX | 标题 + 文案 + 链接清单 |

### 发布日 (v1.0)

| 动作 | 渠道 | 目标 |
|------|------|------|
| GitHub Release + Notes | GitHub | 首发下载 |
| Show HN 帖子 | Hacker News | 技术社区曝光 |
| r/Flutter 帖子 | Reddit | Flutter 社区 |
| r/software 帖子 | Reddit | 软件爱好者 |
| V2EX 帖子 | V2EX | 中文技术社区 |
| 少数派投稿 | 少数派 | 中文高质量用户 |
| 小众软件投稿 | 小众软件 | 软件发现平台 |

### 持续增长 (v1.5-v2.0)

| 动作 | 时间 | 目标 |
|------|------|------|
| Steam 商店页面 | v2.0 前 1 个月 | 开启愿望单 |
| Flathub 上架 | v1.5 | Linux 社区曝光 |
| 博客文章 | 持续 | 架构设计 / Flutter 桌面开发经验 |
| GitHub Discussions | v1.0 | 社区建设 |
| Discord | v1.5 | 实时社区 |

### 定价策略

| 版本 | 价格 | 说明 |
|------|------|------|
| **开源版** | 免费 | GitHub 开源，核心功能完整 |
| **Steam 版** | $4.99-9.99 | 商店分发 + Steam Cloud + 成就 |
| **捐赠** | 自愿 | GitHub Sponsors / Buy Me a Coffee |

> ⚠️ **SKYBOX 教训:** 2024 年买断→订阅 ($9.99/月)，用户称 "bait and switch"，71.9% 好评暴跌。**永远不要买断→订阅。保持买断制或免费。**

### 社区建设路线图

```
v1.0: GitHub Issues + Discussions (bug 报告 + 功能请求)
v1.5: Discord 服务器 (实时反馈 + 社区交流)
v2.0: Steam 社区 + Steam 论坛 (商业化用户群)
```

---

## 6. 质量门禁 (release-checklist)

### 6.1 代码健康

**当前状态 (2026-06-26):**

| 指标 | 当前 | 目标 | 状态 |
|------|------|------|------|
| flutter analyze errors | 10 | 0 | ❌ BLOCKED |
| flutter analyze warnings | 8 | 0 | ❌ |
| TODO/FIXME | 2 | < 5 | ✅ |
| 测试文件数 | 62 | 60+ | ✅ |
| 测试通过 | 待验证 | 100% | ⚠️ |

**发布前检查清单:**

- [ ] `flutter analyze` 零 error（当前 10 个，全在 `media_info_dialog.dart`）
- [ ] `flutter analyze` 零 warning（当前 8 个：unused imports, unused variables, unnecessary casts）
- [ ] `flutter test` 100% 通过
- [ ] TODO/FIXME 数量可接受 (< 5) ✅
- [ ] 无 debug print() 残留（使用 debugPrint()）
- [ ] 无硬编码密钥/凭据

### 6.2 平台验证

| 平台 | 验证项 | v1.0 | v1.5 | v2.0 |
|------|--------|------|------|------|
| Windows x64 | 全功能 | ✅ 必须 | ✅ | ✅ |
| Windows arm64 | 构建测试 | — | ⚡ 验证 | ✅ |
| macOS arm64 | 全功能 | — | ✅ 必须 | ✅ |
| macOS x86_64 | Universal Binary | — | ⚡ 验证 | ✅ |
| Linux x64 | 全功能 | — | ✅ 必须 | ✅ |
| Linux arm64 | 构建测试 | — | ⚡ 验证 | ✅ |
| Steam Deck | 触屏+手柄 | — | — | ✅ 必须 |

### 6.3 性能基准

| 指标 | 目标 | 测试方法 | v1.0 | v1.5 | v2.0 |
|------|------|----------|------|------|------|
| 4K 60fps 硬解 | 流畅 | 手动播放 4K HDR 视频 | ✅ | ✅ | ✅ |
| 启动到首帧 | < 1s | PerfMonitor 计时 | ✅ | ✅ | ✅ |
| 内存占用 | < 200MB | MemoryMonitor 4h | ✅ | ✅ | ✅ |
| 安装包大小 | < 50MB | 打包后测量 | ⚡ | ⚡ | ⚡ |
| 无 shader 卡顿 | 0 次 | Impeller 预热后 | — | — | ✅ |

### 6.4 安全审查 (flutter-security)

- [ ] 无硬编码密钥/凭据
- [ ] 用户输入验证 (PathValidator: 22 格式 + 路径穿越防护)
- [ ] 文件操作安全 (PlaylistStore 原子写入)
- [ ] 无 XSS/注入风险 (纯桌面应用，无 web 组件)
- [ ] 第三方许可证完整 (fvp/MDK/FFmpeg/flutter)

### 6.5 分发检查

- [ ] 安装包可正常安装/卸载
- [ ] 版本号正确 (pubspec.yaml)
- [ ] Release Notes 完整
- [ ] 许可证文件包含在安装包中
- [ ] 自动更新机制 (MSIX 自带 / Sparkle for macOS)

---

## 7. 风险与缓解

### 7.1 技术风险

| # | 风险 | 概率 | 影响 | 缓解措施 | Plan B |
|---|------|------|------|----------|--------|
| 1 | fvp 不支持 ARM64 | 中 | Win/Mac ARM64 不可用 | 提前验证 pub-cache 二进制 | 仅 x64 发布，标记 ARM64 为实验性 |
| 2 | macOS VideoToolbox 不生效 | 中 | macOS 回退软解，4K 卡顿 | 验证 VT 配置 + FFmpeg fallback | 文档说明 macOS 软解限制 |
| 3 | Linux Wayland 兼容 | 低 | 窗口管理功能异常 | GTK3 已处理 X11/Wayland | 测试 GNOME/KDE，文档已知问题 |
| 4 | Impeller 渲染异常 | 中 | UI 卡顿或视觉错误 | 保留 Skia 回退，渐进迁移 | 保持 Skia 直到 Impeller 稳定 |
| 5 | Steam 审核延迟 | 低 | v2.0 推迟 | 提前 1 个月提交 | Proton 兼容 Plan B |
| 6 | fvp D3D11→Vulkan interop | 中 | Impeller 下 Texture 异常 | 运行时验证 | 回退 Skia |

### 7.2 市场风险

| # | 风险 | 缓解 |
|---|------|------|
| 1 | VLC/mpv 用户不愿切换 | 差异化 UI + 硬解优化 + 开源 |
| 2 | Steam 买断无人问津 | 先开源建立用户群，Steam 提供增值 |
| 3 | 免费竞品 (DeoVR) 抢市场 | 本地播放专注 + 跨平台一致性 |
| 4 | 负面评价集中 bug | SKYBOX 教训：更新质量 > 新功能 |

### 7.3 进度风险

| # | 风险 | 缓解 |
|---|------|------|
| 1 | 跨平台工作量超预期 | 代码已有 (macOS/Linux fullscreen, runner)，主要是验证 |
| 2 | Impeller 迁移阻塞 | v2.0 可推迟，不影响 v1.0/v1.5 |
| 3 | 单人开发瓶颈 | 优先 P0，P2 可延后 |

---

## 8. 里程碑时间线

```
2026-07 (Week 1-2)
  └── v1.0 Windows 稳定版发布
       ├── Week 1: 修复 P0 Bug (media_info_dialog + open/seek 状态)
       │            修复 warnings (8 个)
       │            MediaErrorType.network + PlaylistStore 重试
       ├── Week 2: Windows 安装包 (MSIX + EXE)
       │            winget manifest
       │            GitHub Release + Release Notes
       └── 发布日: HN/Reddit/V2EX/少数派 推广

2026-08 (Week 3-6)
  └── v1.5 跨平台桌面版发布
       ├── Week 3: 解码器平台化 (D3D11/VT/VAAPI)
       │            D3D11 Platform.isWindows guard
       ├── Week 4: macOS 缩略图 (QLThumbnailGenerator)
       │            Linux 缩略图 (ffmpeg CLI fallback)
       │            macOS 全屏验证
       ├── Week 5: CI 6 目标构建矩阵
       │            macOS Universal Binary
       │            Linux .deb / .AppImage
       ├── Week 6: Homebrew Cask + Flatpak
       │            ARM64 验证 (if fvp 支持)
       └── 发布日: 三平台同步发布

2026-09 ~ 10 (Week 7-12)
  └── v2.0 体验增强版发布
       ├── Week 7-8: Impeller 迁移验证 + BackdropFilter 重构
       │              FragmentShader 预编译
       ├── Week 9-10: HLS ABR (Throughput → BBA)
       │               RTSP 低延迟流
       ├── Week 11: Steam 商店页面 + 注册 ($100)
       │             Steam Deck 触屏/手柄适配
       ├── Week 12: Steam Cloud 同步
       │             Steam 上架
       └── 发布日: Steam 首发 + 社区建设启动
```

---

## 9. 成功指标

### 量化指标

| 指标 | v1.0 目标 | v1.5 目标 | v2.0 目标 | 衡量方式 |
|------|----------|----------|----------|----------|
| GitHub Stars | 100+ | 500+ | 1000+ | GitHub API |
| 月活用户 | 50+ | 200+ | 1000+ | 下载量估算 |
| 平台覆盖 | 1 (Win) | 3 (Win/Mac/Linux) | 3 + Steam Deck | 构建矩阵 |
| 格式支持 | 10+ | 15+ | 20+ | MDK/FFmpeg |
| Bug 报告 | < 5/月 | < 10/月 | < 15/月 | Issues |
| 测试覆盖 | 60+ | 80+ | 100+ | test files |
| 安装包大小 | < 50MB | < 50MB | < 50MB | 打包测量 |

### 质量指标

| 指标 | v1.0 | v1.5 | v2.0 |
|------|------|------|------|
| flutter analyze | 0 error | 0 error | 0 error |
| 测试通过率 | 100% | 100% | 100% |
| S1 Bug | 0 | 0 | 0 |
| 启动时间 | < 1s | < 1s | < 1s |
| 崩溃率 | < 0.1% | < 0.1% | < 0.05% |

### 社区指标

| 指标 | v1.0 | v1.5 | v2.0 |
|------|------|------|------|
| GitHub Issues 活跃 | 5+/月 | 10+/月 | 15+/月 |
| PR 贡献者 | 0 | 1-2 | 3-5 |
| Discord 成员 | — | 50+ | 200+ |
| Steam 评测 | — | — | 50+ (好评率 > 80%) |

---

## 10. team-release 发布协调流程

### Phase 1: 发布规划 (Producer)

- [ ] 确认里程碑验收标准全部满足
- [ ] 识别延期项目并确认 scope
- [ ] 设定发布日期并通知团队
- [ ] 输出：发布授权 + scope 确认

### Phase 2: 发布候选 (Release Manager)

- [ ] 从确认的 commit 切 release 分支
- [ ] 更新版本号 (pubspec.yaml + 安装包)
- [ ] 生成 release-checklist
- [ ] 冻结分支 — 仅修 bug，不加功能

### Phase 3: 质量门禁 (并行)

- **QA Lead:** 全量回归测试，零 S1/S2 bug
- **DevOps:** 构建所有平台产物，CI 通过
- **Security:** 安全审查 (输入验证、文件操作、许可证)

### Phase 4: Go/No-Go (Producer)

- 收集所有 sign-off
- 评估未关闭 issue — 阻塞 or 可带病发布
- 做出 Go/No-Go 决定

### Phase 5: 部署 (Release Manager + DevOps)

- [ ] Git tag
- [ ] Release Notes (changelog)
- [ ] GitHub Release 发布
- [ ] 包管理器提交 (winget/Homebrew/Flatpak)
- [ ] 48 小时监控

### Phase 6: 发布后 (Community + QA)

- [ ] 发布公告 (各渠道)
- [ ] 监控 bug 报告
- [ ] 收集用户反馈
- [ ] 安排回顾会议 (如有重大问题)

---

## 11. 下一步行动 (立即可执行)

### 本周 (v1.0 Week 1)

| 优先级 | 任务 | 预估 | 依赖 |
|--------|------|------|------|
| 🔴 P0 | 修复 media_info_dialog.dart 10 个编译错误 | 2h | 无 |
| 🔴 P0 | 修复 open() 后不设 idle 状态 | 1h | 无 |
| 🔴 P0 | 修复 seekTo 与 buffering 状态竞态 | 2h | 无 |
| 🟡 P1 | 修复 8 个 warnings | 30min | 无 |
| 🟡 P1 | 添加 MediaErrorType.network | 30min | 无 |
| 🟡 P1 | PlaylistStore 写入失败重试 | 30min | 无 |

### 下周 (v1.0 Week 2)

| 优先级 | 任务 | 预估 | 依赖 |
|--------|------|------|------|
| 🟡 P1 | ThumbnailCache LRU 缓存 | 1h | 无 |
| 🟡 P1 | FFmpeg 网络参数配置 | 1h | 无 |
| 📦 发布 | Windows 安装包 (MSIX/EXE) | 1d | P0 完成 |
| 📦 发布 | winget manifest | 2h | 安装包完成 |
| 📦 发布 | GitHub Release + Notes | 2h | 全部完成 |

### v1.5 启动条件

- [ ] v1.0 发布成功
- [ ] 零 S1 Bug 报告 (1 周观察期)
- [ ] 验证 fvp ARM64 二进制可用性

---

## 12. 附录

### A. 已识别的 15 个架构模式 (代码审查发现)

| 层 | 模式 | 文件 |
|----|------|------|
| Engine | Notifier Surface (10 ValueNotifier) | fvp_engine.dart |
| Engine | Guarded Action (disposed+try-catch) | fvp_engine.dart |
| Engine | Callback Adapter + Thread Hop | fvp_callback_handler.dart |
| Engine | Composition Helpers (3 个 Helper) | fvp_engine.dart |
| Engine | Hand-Written Fake + Call Tracking | test files |
| 持久化 | Snapshot Debounce Write | playlist_store.dart |
| 持久化 | Atomic Write + Serialization | playlist_store.dart |
| 持久化 | CQS Navigation | playlist.dart |
| 持久化 | Input Sanitization Layer | settings_store.dart |
| 持久化 | Prewarm Cache | settings_store.dart |
| UI | Resize-Aware Degradation | glass_container.dart |
| UI | _RepaintNotifier Trick | custom_painter files |
| UI | Pre-render + ColorFilter | aurora_background.dart |
| UI | Dual AnimationController Cross-fade | controls_overlay.dart |
| UI | LayoutBuilder Size Clamping | dialog files |

### B. 关键文件索引

| 文件 | 行数 | 职责 |
|------|------|------|
| `lib/kernel/engine/fvp_engine.dart` | ~500 | MDK/FFmpeg 引擎封装 |
| `lib/kernel/services/playback_controller.dart` | ~300 | 播放控制编排器 (3 mixin) |
| `lib/ui/player/player_screen.dart` | ~400 | 主播放器界面 (Stack 合成) |
| `lib/ui/player/controls_overlay.dart` | ~300 | 自动隐藏控制层 |
| `lib/ui/shared/glass_container.dart` | ~150 | 毛玻璃容器 (BackdropFilter) |
| `lib/kernel/bridge/window_service.dart` | ~400 | Win32 窗口管理 |
| `lib/kernel/persistence/playlist_store.dart` | ~200 | 原子持久化 (debounce+tmp+rename) |

### C. 参考记忆

| 记忆 | 内容 | 关联 |
|------|------|------|
| project_full_architecture | 5 层完整架构 | 技术架构章节 |
| project_cross_platform_desktop | 4 构建目标 + 6 差距 | v1.5 跨平台章节 |
| project_steam_steamos_plan | Steam 上架路线 | v2.0 Steam 章节 |
| project_impeller_migration | Impeller 6 阶段 | v2.0 渲染章节 |
| project_hls_abr_plan | HLS ABR 架构 | v2.0 网络流章节 |
| reference_skybox_vr_analysis | 竞品分析 | 营销+定价策略 |
| project_code_review_checkpoint | 15 模式 + 11 发现 | 质量门禁章节 |

---

*This plan is a living document. Update after each milestone.*
*Skills used: release-checklist, launch-checklist, team-release, project-stage-detect, milestone-review*
