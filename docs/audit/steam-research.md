# Steam 上架技术研究报告

**Created:** 2026-07-20
**Project:** Simple Player Flutter (fvp/MDK-FFmpeg 桌面播放器)
**Current Version:** 1.0.0-rc.1
**Platform Status:** Windows (primary), macOS, Linux (次级)

---

## 1. 上架前置条件

### 1.1 Steamworks 账号与费用

| 项目 | 详情 |
|------|------|
| Steamworks Partner 账号 | 注册地址: https://partner.steamgames.com |
| Steam Direct 费用 | **$100 USD / 每个 app** (收入达 $1,000 后可退还) |
| 税务信息 | 需提交 W-9 (美国) 或 W-8BEN (非美国) 税务表格 |
| 银行信息 | 配置收款账户用于收入分成 |
| 审核周期 | 账号审核约 1-30 天 |

### 1.2 商店页面素材要求

| 素材类型 | 规格要求 | 优先级 |
|----------|----------|--------|
| Capsule Image (小) | 231 x 87 px | 必须 |
| Capsule Image (大) | 467 x 175 px | 必须 |
| Header Capsule | 460 x 215 px | 必须 |
| Page Background | 1438 x 810 px | 必须 |
| Screenshots | 至少 5 张, 1920x1080 推荐 | 必须 |
| 宣传片 (Trailer) | 推荐 1080p, 30-60 秒 | 强烈推荐 |
| 应用图标 | 256 x 256 px | 必须 |
| 商店描述 | 中英文双语 | 必须 |
| 系统需求 | 最低/推荐配置 | 必须 |

### 1.3 提交审核清单

- [ ] Steamworks Partner 账号已注册并审核通过
- [ ] Steam Direct 费用已支付 ($100)
- [ ] 税务与银行信息已配置
- [ ] 商店页面素材已上传 (capsule, screenshots, trailer)
- [ ] 应用描述已填写 (中英文)
- [ ] 系统需求已配置 (最低/推荐)
- [ ] 定价与区域已设置
- [ ] 发布日期已选择 (需提前至少 2 周设置 upcoming visibility)
- [ ] 应用构建已通过 SteamPipe 上传
- [ ] DRM 配置已确认 (可选: Steamworks DRM 或无 DRM)
- [ ] 内容政策合规检查通过

### 1.4 适用的应用类型

Simple Player 作为**媒体播放器**应用 (非游戏), 在 Steam 上属于以下类别:
- **Software** 类型 (Steam 上有 Software 非游戏分类)
- 可标记为 "Utilities" 或 "Photo Editing" (视频播放器归类)
- Steam Software 不需要 Achievements/Trading Cards, 但可以集成

---

## 2. Steam Deck 适配要点

### 2.1 Steam Deck Verified 认证

Steam Deck Verified 是 Valve 的兼容性评级系统:

| 等级 | 含义 | 目标 |
|------|------|------|
| Verified | 在 Deck 上完美运行 | 最终目标 |
| Playable | 可运行但需手动配置 | 最低目标 |
| Unsupported | 无法在 Deck 上运行 | 避免 |
| Unknown | 未测试 | 初始状态 |

### 2.2 Verified 认证核心要求

**输入兼容性:**
- 所有功能必须可通过控制器操作 (无强制键盘/鼠标依赖)
- 需支持 Steam Input API 或手柄映射
- 当前 Simple Player 依赖 20+ 键盘快捷键 — 需要手柄映射方案
- Steam Deck 有触屏, 可作为辅助输入

**显示兼容性:**
- Steam Deck 分辨率: 1280 x 800 (16:10)
- 当前设计基于 600dp 响应式布局 — 需验证小屏适配
- 必须支持 800p 全屏模式
- 文字可读性 (小屏下字体不能太小)

**性能要求:**
- 目标: 稳定 30fps+ (视频播放器需 60fps)
- Steam Deck 使用 AMD Van Gogh APU (Zen 2 + RDNA 2)
- fvp/MDK 使用 FFmpeg 软解 + GPU 加速 — 需验证 Deck 兼容性

**Linux/Proton 兼容性:**
- Steam Deck 运行 SteamOS 3.x (基于 Arch Linux)
- 原生 Linux 构建优先于 Proton (Windows 兼容层)
- Flutter 已支持 Linux 桌面 — 需要验证 fvp 在 Linux 上的行为

### 2.3 Steam Deck 检测 API

```cpp
// 检测是否在 Steam Deck 上运行
bool IsSteamRunningOnSteamDeck();

// 检测是否在 Big Picture 模式
bool IsSteamInBigPictureMode();
```

### 2.4 适配策略

| 层级 | 工作内容 | 优先级 |
|------|----------|--------|
| P0 | Linux 原生构建 + fvp 验证 | 必须 |
| P1 | 控制器输入映射 (播放/暂停/音量/seek) | 必须 |
| P2 | 1280x800 响应式布局验证 | 必须 |
| P3 | 触屏支持 (基础手势) | 推荐 |
| P4 | Big Picture 模式优化 | 推荐 |

---

## 3. Steamworks SDK 集成方案

### 3.1 Steamworks SDK 概述

Steamworks SDK 是 Valve 提供的 C/C++ SDK, 核心功能:

| 功能 | API | 与 Simple Player 相关性 |
|------|-----|------------------------|
| Steam API 初始化 | `SteamAPI_Init()` / `SteamAPI_Shutdown()` | 必须 |
| Steam Overlay | `ISteamFriends` | 推荐 (社区功能) |
| Steam Cloud | `ISteamRemoteStorage` | 推荐 (设置同步) |
| Achievements | `ISteamUserStats` | 可选 (播放成就) |
| Steam Input | `ISteamInput` | 必须 (Deck 控制器) |
| Steam Audio | `ISteamAudio` | 不需要 (用 fvp) |
| DRM | Steamworks DRM | 可选 |
| Crash Reporting | `SteamAPI_WriteMiniDump()` | 推荐 |
| DLC | `ISteamApps` | 不需要 |

### 3.2 Flutter 集成架构

由于 Steamworks SDK 是 C/C++, Flutter/Dart 需要通过 FFI 或 MethodChannel 集成:

**方案 A: C++ Plugin (推荐)**
```
Flutter App
    ↓ (MethodChannel / FFI)
C++ Steam Plugin (steam_api64.dll)
    ↓
Steamworks SDK
```

- 类似现有 `window_bridge.dart` 的 Win32 MethodChannel 模式
- 编写 C++ 插件封装 Steamworks API
- 通过 Pigeon 生成类型安全的 Dart/C++ 绑定

**方案 B: FFI 直接调用**
```
Flutter App
    ↓ (dart:ffi)
steam_api64.dll (直接调用)
```

- 使用 `dart:ffi` 直接加载 `steam_api64.dll`
- 需要手写 FFI 绑定
- 更底层, 但更灵活

**方案 C: steamworks.js 参考**
- GitHub: ValveSoftware/steamworks.js (Node.js/Electron 封装)
- 参考其封装模式, 移植到 Dart FFI
- 但不直接使用 (Node.js 依赖)

### 3.3 推荐集成方案: C++ Plugin + Pigeon

基于项目现有架构 (`window_bridge.dart` 已有 MethodChannel 模式):

```
lib/kernel/bridge/
├── window_bridge.dart          # 现有 Win32 桥接
└── steam_bridge.dart           # 新增 Steam 桥接

windows/runner/
├── steam_plugin.cpp            # C++ Steam API 封装
└── steam_api64.dll             # Steamworks SDK 运行时

linux/
└── libsteam_api.so             # Steamworks SDK Linux 版本
```

### 3.4 核心集成步骤

```cpp
// steam_plugin.cpp — 核心初始化
#include "steam_api.h"

bool InitializeSteam(uint32 appId) {
    if (SteamAPI_RestartAppIfNecessary(appId)) {
        return false; // 需要通过 Steam 启动
    }
    if (!SteamAPI_Init()) {
        return false; // Steam 客户端未运行
    }
    return true;
}

void RunSteamCallbacks() {
    SteamAPI_RunCallbacks(); // 需要定期调用
}

void ShutdownSteam() {
    SteamAPI_Shutdown();
}
```

```dart
// steam_bridge.dart — Dart 侧封装
class SteamBridge {
    static const _channel = MethodChannel('com.simple_player/steam');
    
    Future<bool> initialize(int appId) async {
        return await _channel.invokeMethod('init', {'appId': appId});
    }
    
    Future<void> runCallbacks() async {
        await _channel.invokeMethod('runCallbacks');
    }
    
    Future<void> shutdown() async {
        await _channel.invokeMethod('shutdown');
    }
}
```

### 3.5 steam_appid.txt 配置

在可执行文件同目录放置:
```
480  # 测试用 Spacewar App ID, 正式发布替换为真实 App ID
```

### 3.6 Steam API 回调循环

Steamworks SDK 需要定期调用 `SteamAPI_RunCallbacks()`:
- 在 Flutter 中, 可使用 `Timer.periodic` (每 100ms)
- 或集成到现有的 `PositionPoller` 定时器中
- 确保在主线程调用 (或使用回调封送)

---

## 4. 分发渠道规划

### 4.1 多渠道分发策略

| 渠道 | 平台 | 优先级 | 说明 |
|------|------|--------|------|
| Steam | Windows + Linux | P0 | 主要分发渠道 |
| Flathub (Flatpak) | Linux | P1 | Steam Deck 备选 + Linux 桌面用户 |
| GitHub Releases | 全平台 | P1 | 开发者/技术用户 |
| MSIX (Microsoft Store) | Windows | P2 | 已有 msix_config 配置 |
| macOS App Store | macOS | P3 | 需要 Apple 开发者账号 |

### 4.2 Flatpak 分发方案

**Flatpak Manifest (初步设计):**

```yaml
id: com.simpleplayer.SimplePlayer
runtime: org.freedesktop.Platform
runtime-version: '24.08'
sdk: org.freedesktop.Sdk
command: simple_player_flutter
finish-args:
  - --share=ipc
  - --socket=fallback-x11
  - --socket=wayland
  - --socket=pulseaudio
  - --device=dri                    # GPU 加速 (视频播放必需)
  - --filesystem=home               # 访问用户视频文件
  - --filesystem=xdg-videos:ro      # 视频目录只读访问

modules:
  # Flutter SDK (交叉编译)
  - name: flutter-sdk
    buildsystem: simple
    build-commands:
      - # 预编译 Flutter Linux 构建产物
    
  # fvp/MDK 依赖
  - name: mdk-runtime
    buildsystem: simple
    build-commands:
      - install -D libmdk.so /app/lib/libmdk.so
    sources:
      - type: archive
        url: https://github.com/niceplayer/mdk/releases/...
    
  # Simple Player 应用
  - name: simple-player
    buildsystem: simple
    build-commands:
      - cp -r build/linux/x64/release/bundle/* /app/
    sources:
      - type: dir
        path: .
```

**Flatpak 构建流程:**
```bash
# 1. 在 Linux 环境构建 Flutter 应用
flutter build linux --release

# 2. 使用 flatpak-builder 打包
flatpak-builder --force-clean --user --install-deps-from=flathub \
    --repo=repo --install builddir com.simpleplayer.SimplePlayer.yml

# 3. 提交到 Flathub
# 需要 fork flathub/com.simpleplayer.SimplePlayer 仓库
```

### 4.3 Steam + Flatpak 双渠道策略

```
                     ┌─────────────┐
                     │  源代码仓库  │
                     └──────┬──────┘
                            │
              ┌─────────────┼─────────────┐
              │             │             │
       ┌──────┴──────┐ ┌───┴────┐ ┌──────┴──────┐
       │ Windows 构建 │ │Linux 构建│ │ macOS 构建  │
       └──────┬──────┘ └───┬────┘ └──────┬──────┘
              │             │             │
       ┌──────┴──────┐     │      ┌──────┴──────┐
       │ SteamPipe   │     │      │ GitHub      │
       │ (Steam)     │     │      │ Releases    │
       └─────────────┘     │      └─────────────┘
                           │
                    ┌──────┴──────┐
                    │             │
             ┌──────┴──┐  ┌──────┴──────┐
             │ Steam   │  │ Flathub     │
             │ (Linux) │  │ (Flatpak)   │
             └─────────┘  └─────────────┘
```

### 4.4 SteamPipe 构建上传

```bash
# SteamPipe 使用 SteamCMD 上传构建
# depot_build.vdf 配置示例:
"DepotBuildConfig"
{
    "DepotID" "YOUR_DEPOT_ID"
    "ContentRoot" "D:\\simple_player_flutter\\build\\windows\\x64\\runner\\Release"
    "FileMapping"
    {
        "LocalPath" "*"
        "DepotPath" "."
        "Recursive" "1"
    }
}

# 上传命令
steamcmd +login YOUR_USERNAME +run_app_build depot_build.vdf +quit
```

---

## 5. Linux 构建可行性分析

### 5.1 当前 Linux 支持状态

| 组件 | 状态 | 风险 |
|------|------|------|
| Flutter Linux Desktop | 已支持 | 低 |
| fvp (MDK) Linux | 需验证 | **中** |
| window_manager Linux | 已支持 | 低 |
| hotkey_manager Linux | 已支持 | 低 |
| file_picker Linux | 已支持 | 低 |
| desktop_drop Linux | 已支持 | 低 |

### 5.2 fvp/MDK Linux 关键验证项

fvp 底层使用 MDK (基于 FFmpeg), Linux 支持需要:
- [ ] `libmdk.so` 在 Linux x64 上可用
- [ ] 硬件加速 (VAAPI/VDPAU) 在 Steam Deck APU 上工作
- [ ] Texture 渲染与 Flutter Linux embedder 兼容
- [ ] 音频输出 (PulseAudio/PipeWire) 正常

### 5.3 Steam Deck 特殊考虑

- SteamOS 3.x 基于 Arch Linux, 使用 KDE Plasma 桌面
- 默认使用 PipeWire 音频
- GPU 为 AMD RDNA 2, 支持 VAAPI 硬解
- 容器化运行 (Flatpak 或 Steam runtime)

---

## 6. 时间线与资源估算

### 6.1 Phase 分解

| 阶段 | 工作内容 | 预计时间 | 依赖 |
|------|----------|----------|------|
| **Phase S1: Linux 验证** | fvp Linux 构建 + 基础功能测试 | 1-2 周 | 无 |
| **Phase S2: Steamworks 集成** | C++ Plugin + Steam Bridge + 初始化 | 2-3 周 | S1 |
| **Phase S3: Steam Deck 适配** | 控制器输入 + 响应式布局 + 性能 | 2-3 周 | S2 |
| **Phase S4: 商店页面** | 素材制作 + 描述撰写 + 提交审核 | 1-2 周 | S2 |
| **Phase S5: Flatpak 打包** | Manifest + Flathub 提交 | 1-2 周 | S1 |
| **Phase S6: 测试与发布** | Beta 测试 + 正式发布 | 1-2 周 | S3-S5 |

**总计: 8-14 周 (约 2-3.5 个月)**

### 6.2 资源需求

| 资源 | 说明 | 成本 |
|------|------|------|
| Steamworks Partner 账号 | 一次性注册 | $100 |
| Steam Direct 费用 | 每个 app | $100 (可退还) |
| Linux 开发环境 | WSL2 或 VM | 无额外成本 |
| Steam Deck 硬件 | 测试用 | ~$400 (可选, 可用模拟器) |
| 商店素材设计 | Capsule + Screenshots | 自行设计或外包 |
| Apple 开发者账号 | macOS 上架 (可选) | $99/年 |

### 6.3 关键风险

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| fvp Linux 不兼容 | 阻塞整个 Linux/Deck 方案 | Phase S1 优先验证, 准备 Proton 兜底 |
| Steam Deck 控制器适配复杂 | 影响 Verified 认证 | 先做 Playable, 逐步优化 |
| Steamworks SDK FFI 复杂度 | 延长集成时间 | 参考 steamworks.js 封装模式 |
| 小屏布局适配 | 影响 Deck 用户体验 | 600dp 响应式已有基础 |
| MDK 商业许可 | 分发限制 | 确认 MDK 许可证允许 Steam 分发 |

---

## 7. 推荐行动计划

### 7.1 立即可做 (本周)

1. **注册 Steamworks Partner 账号** — 开始审核流程 (1-30 天)
2. **验证 fvp Linux 构建** — 在 WSL2 或 Linux VM 中测试 `flutter build linux`
3. **确认 MDK 许可证** — 确保允许通过 Steam 分发

### 7.2 短期 (2-4 周)

4. **完成 v3.0 内核重写** — Phase 21-22 收尾 (当前进行中)
5. **Linux 原生构建验证** — 完整功能测试
6. **Steamworks SDK 集成** — C++ Plugin + Steam Bridge

### 7.3 中期 (4-8 周)

7. **Steam Deck 适配** — 控制器 + 响应式布局
8. **商店页面准备** — 素材 + 描述 + 定价
9. **Flatpak 打包** — Manifest + Flathub 提交

### 7.4 发布 (8-14 周)

10. **Beta 测试** — Steam Beta 分支 + 社区反馈
11. **正式发布** — Steam + Flathub 同步上线

---

## 8. 参考资料

- Steamworks Partner Portal: https://partner.steamgames.com
- Steamworks SDK 文档: https://partner.steamgames.com/doc/sdk
- Steam Deck Verified: https://partner.steamgames.com/doc/steamdeck
- SteamPipe 文档: https://partner.steamgames.com/doc/sdk/uploading
- Flatpak 文档: https://docs.flatpak.org
- Flathub: https://flathub.org
- steamworks.js (参考): https://github.com/ValveSoftware/steamworks.js
- Flutter Linux Desktop: https://docs.flutter.dev/platform-integration/linux

---

*Report created: 2026-07-20 — Steam publishing technical research for Simple Player Flutter*
*Sources: Steamworks Partner API docs (Context7), Flatpak docs (Context7), project pubspec.yaml*
