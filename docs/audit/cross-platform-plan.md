# 跨平台扩展方案 — Simple Player Flutter

> 版本: v1.0 | 日期: 2026-07-20 | 状态: 技术研究

---

## 1. 执行摘要

### 1.1 目标

将 Simple Player Flutter 从 Windows-only 桌面播放器扩展为跨 Windows / macOS / Linux 三平台桌面应用，最大化复用现有 Dart/Flutter 代码，最小化平台特定代码量。

### 1.2 支持平台

| 平台 | 最低版本 | 引擎后端 | 优先级 |
|------|----------|----------|--------|
| Windows | 10 (1903+) | fvp (MDK/D3D11) | P0 — 已完成 |
| macOS | 12 Monterey+ | fvp (MDK/Metal) | P1 — 首个移植目标 |
| Linux | Ubuntu 22.04+ | fvp (MDK/Vulkan) | P2 — 第二阶段 |

### 1.3 预期收益

- **用户覆盖**: 桌面 OS 市场份额 Windows ~73%, macOS ~16%, Linux ~4% — 覆盖 93%+ 桌面用户
- **代码复用**: 现有 ~85% Dart 代码（kernel/services/ui）零修改跨平台
- **工程收益**: 抽象层强制接口隔离，提升 Windows 实现的可测试性
- **发布渠道**: macOS App Store + Homebrew, Linux Snap/Flatpak, Windows 现有渠道

---

## 2. 平台分析

### 2.1 Windows 现状

当前 Windows 实现是项目的基准，关键平台绑定点：

**Bridge 层（`lib/kernel/bridge/`）**:
- `WindowBridge` — 抽象接口（5 状态 + 7 命令），已具备跨平台设计基础
- `WindowService` — 具体实现，依赖 `window_manager` 包 + `WindowListener` mixin
- `Win32DisplayEnumerator` — Win32 FFI 直接调用 `EnumDisplayMonitors` / `GetMonitorInfoW`
- `Win32DisplayAdapter` — 适配器模式包装静态 FFI 为 `DisplayEnumerator` 接口
- `DisplayConfig` — 刷新率检测（当前降级为 60Hz 安全默认值）
- `WindowPersistence` — 防抖 + 写入锁，纯 Dart 实现，已跨平台

**Engine 层（`lib/kernel/engine/`）**:
- `FvpEngine` — fvp 插件包装，D3D11 特定参数 (`d3d11.sync.cpu`)
- `DisplayConfig.d3d11SyncMode()` — 刷新率感知的 D3D11 同步策略

**Native 层**:
- Win32 MethodChannel (`com.simple_player/window`) — 窗口控制
- C++ runner — `WM_NCCALCSIZE` / `WM_NCHITTEST` / `WM_SIZING` 处理

**依赖分析**:

| 依赖 | 跨平台状态 | 替代方案 |
|------|-----------|----------|
| `window_manager` | 已跨平台 (Win/Mac/Linux) | 无需替换 |
| `fvp` | 已跨平台 (Win/Mac/Linux) | 无需替换 |
| `shared_preferences` | 已跨平台 | 无需替换 |
| Win32 FFI (user32.dll) | Windows-only | 需平台分支 |
| C++ runner WM_* 消息 | Windows-only | 需 macOS/Linux 替代 |

### 2.2 macOS 特性

**窗口管理**:
- `NSWindow` — 无边框窗口 (`NSWindowStyleMaskBorderless`)
- `NSWindow.collectionBehavior` — 全屏行为控制
- `NSWindow.titlebarAppearsTransparent` — 透明标题栏
- `NSWindow.styleMask` — 可调整大小、最小化、关闭按钮控制
- `NSScreen` — 多显示器枚举（等价 Win32 `EnumDisplayMonitors`）

**媒体播放**:
- AVFoundation — 系统原生解码（fvp/MDK 在 macOS 使用 VideoToolbox 硬解）
- Metal — GPU 渲染（fvp macOS 后端）
- CoreAudio — 音频输出

**沙箱限制**:
- App Store 要求 App Sandbox — 文件访问受限
- `com.apple.security.files.user-selected.read-write` — 用户选择的文件
- `com.apple.security.network.client` — 网络流媒体
- 临时目录无限制，但用户目录需权限

**构建系统**:
- Xcode 14+ / macOS 12+ SDK
- Swift 5.7+ runner
- 签名: Developer ID (直接分发) 或 App Store Connect

### 2.3 Linux 特性

**窗口管理**:
- GTK3/GTK4 — `GtkWindow` 无边框模式
- `window_manager` 已支持 Linux (GTK 后端)
- Wayland vs X11 — 需处理两种显示协议
- `libhandy` / `libadwaita` — GNOME 风格自适应

**媒体播放**:
- GStreamer — Linux 标准多媒体框架
- fvp/MDK 在 Linux 使用 Vulkan 渲染后端
- PipeWire / PulseAudio — 音频输出（现代 vs 传统）

**文件系统**:
- XDG Base Directory — `~/.config`, `~/.local/share`
- Flatpak sandbox — `xdg-document-portal`
- Snap confinement — `home` interface

**构建系统**:
- CMake (Flutter Linux runner 默认)
- GCC 11+ / Clang 14+
- pkg-config 依赖管理

---

## 3. 架构设计

### 3.1 平台抽象层

现有 `WindowBridge` 接口已具备跨平台基础。扩展策略：

```
lib/kernel/bridge/
├── window_bridge.dart          # 抽象接口 (已有, 不变)
├── window_mode.dart            # 枚举 (已有, 不变)
├── window_state.dart           # 状态容器 (已有, 不变)
├── window_persistence.dart     # 持久化 (已有, 纯 Dart, 不变)
├── display_enumerator.dart     # 显示器抽象 (已有, 不变)
├── display_config.dart         # 刷新率策略 (需平台分支)
├── window_service.dart         # 当前 Win32 实现 → 重命名为 win32/
├── win32/
│   ├── win32_window_service.dart    # 从 window_service.dart 迁移
│   ├── win32_display_enumerator.dart # 已有
│   └── win32_fullscreen.dart        # Win32 全屏 FFI
├── macos/
│   ├── macos_window_service.dart    # NSWindow 包装
│   ├── macos_display_enumerator.dart # NSScreen 枚举
│   └── macos_fullscreen.dart        # NSWindow fullscreen
├── linux/
│   ├── linux_window_service.dart    # GTK 窗口包装
│   ├── linux_display_enumerator.dart # GDK display 枚举
│   └── linux_fullscreen.dart        # GTK fullscreen
└── platform_factory.dart            # 平台工厂 — 条件导入选择实现
```

### 3.2 平台工厂 — 条件导入

使用 Dart 条件导入（`dart:io` + `Platform.isWindows`）在编译时选择实现：

```dart
// platform_factory.dart
import 'window_bridge.dart';
import 'win32/win32_window_service.dart'
    if (dart.library.io) 'macos/macos_window_service.dart'
    if (dart.library.io) 'linux/linux_window_service.dart';

/// 创建当前平台的 WindowBridge 实现。
WindowBridge createWindowBridge() {
  if (Platform.isWindows) return Win32WindowService();
  if (Platform.isMacOS) return MacOSWindowService();
  if (Platform.isLinux) return LinuxWindowService();
  throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
}
```

**替代方案 — `flutter_fullscreen` 式条件导入**:

```dart
// 更清晰的条件导入语法
import 'stub_window_service.dart'
    if (dart.library.io) 'win32/win32_window_service.dart'
    if (dart.library.ffi) 'win32/win32_window_service.dart';
```

推荐使用 `Platform.isX` 运行时检查 + 统一文件，因为：
- 条件导入在桌面平台行为一致（都支持 `dart:io`）
- 运行时检查更直观，IDE 跳转更友好
- 避免 stub 文件的维护负担

### 3.3 DisplayEnumerator 平台扩展

现有 `DisplayEnumerator` 接口设计良好，直接为 macOS/Linux 实现：

| 平台 | 实现类 | 底层 API | 坐标系 |
|------|--------|----------|--------|
| Windows | `Win32DisplayAdapter` | `EnumDisplayMonitors` FFI | 物理像素 → 逻辑像素 |
| macOS | `MacOSDisplayAdapter` | `NSScreen.screens` (FFI/MethodChannel) | 点（已逻辑） |
| Linux | `LinuxDisplayAdapter` | `GdkMonitor` (FFI/MethodChannel) | 像素 → 逻辑像素 |

macOS 和 Linux 可通过 MethodChannel 调用原生代码获取显示器信息，避免直接 FFI（GTK/NSScreen 的 FFI 绑定复杂度高）。

### 3.4 Engine 层平台适配

fvp 插件本身已跨平台，但配置参数需平台分支：

```dart
// display_config.dart 修改
class DisplayConfig {
  /// 返回当前平台的渲染后端同步模式。
  static String renderSyncMode() {
    if (Platform.isWindows) return _d3d11SyncMode();
    if (Platform.isMacOS) return _metalSyncMode();
    if (Platform.isLinux) return _vulkanSyncMode();
    return '1'; // 安全默认
  }

  static String _d3d11SyncMode() => syncModeForHz(_instance._cachedHz);
  static String _metalSyncMode() => '1'; // Metal 通常不需要手动同步控制
  static String _vulkanSyncMode() => '1'; // Vulkan sync 待调研
}
```

---

## 4. macOS 适配方案

### 4.1 NSWindow 集成

**窗口初始化**:

```dart
// macos_window_service.dart
class MacOSWindowService with WindowListener implements WindowBridge {
  // window_manager 已封装 NSWindow — 直接使用
  // 差异点:
  // 1. macOS 无 WS_THICKFRAME — 通过 NSScreen.frame 自动处理
  // 2. macOS 全屏是原生行为 — NSWindow.toggleFullScreen
  // 3. macOS 标题栏按钮 — NSWindowButton.close/miniaturize/zoom

  @override
  Future<void> init() async {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      backgroundColor: Colors.transparent,
      titleBarStyle: TitleBarStyle.hidden,
      // macOS: 隐藏标题栏但保留红绿灯按钮
      windowButtonVisibility: true, // macOS 特有: 保留关闭/最小化/最大化按钮
      minimumSize: Size(854, 513),
    );
    // ... 恢复窗口状态
  }
}
```

**macOS 与 Windows 差异点**:

| 功能 | Windows 实现 | macOS 实现 |
|------|-------------|------------|
| 无边框窗口 | `TitleBarStyle.hidden` + WS_THICKFRAME FFI | `TitleBarStyle.hidden` + `windowButtonVisibility: true` |
| 全屏 | 自定义 FFI (SetWindowPos) | `NSWindow.toggleFullScreen` (原生) |
| 窗口圆角 | DWMWA_WINDOW_CORNER_PREFERENCE | NSWindow 自动圆角 |
| 多显示器 | EnumDisplayMonitors FFI | NSScreen.screens |
| 置顶 | `setAlwaysOnTop` | `NSWindow.level = .floating` |
| 拖拽移动 | `startDragging` | NSWindow.mouseDown (自动) |

### 4.2 AVFoundation / fvp 集成

fvp 在 macOS 使用 VideoToolbox 硬件解码 + Metal 渲染：

```dart
// FvpEngine 平台参数
class FvpEngine {
  Map<String, String> _platformParams() {
    if (Platform.isWindows) {
      return {
        'd3d11.sync.cpu': DisplayConfig.d3d11SyncMode(),
        // Windows 特有参数
      };
    } else if (Platform.isMacOS) {
      return {
        // macOS: VideoToolbox 硬解默认开启
        // Metal 渲染由 fvp 自动选择
        'videotoolbox': '1',
      };
    } else if (Platform.isLinux) {
      return {
        // Linux: VAAPI/VDPAU 硬解
        'vaapi': '1',
        'vulkan': '1',
      };
    }
    return {};
  }
}
```

### 4.3 沙箱处理

macOS App Sandbox 对文件访问的限制：

```
Entitlements:
  com.apple.security.app-sandbox: true
  com.apple.security.files.user-selected.read-write: true  # 用户选择的文件
  com.apple.security.network.client: true                   # 网络流媒体
  com.apple.security.files.downloads.read-write: true       # 下载目录
```

**影响与应对**:

1. **文件打开**: 使用 `file_picker` 包 — 已通过 `NSOpenPanel` 获取用户授权，沙箱安全
2. **拖放文件**: macOS 沙箱下拖放文件需要 `com.apple.security.files.bookmarks.app-scope`
3. **缩略图**: macOS 使用 `QLThumbnailGenerator` — 沙箱内可用
4. **最近文件**: macOS 自动管理 `NSDocumentController.recentDocuments`
5. **持久化路径**: 使用 `path_provider` 包 — 返回沙箱内路径

### 4.4 macOS 缩略图服务

当前 Windows 缩略图使用 Win32 COM (`IThumbnailProvider`)。macOS 替代：

```dart
// macOS 缩略图 — 通过 MethodChannel 调用 QLThumbnailGenerator
class MacOSThumbnailService {
  static const _channel = MethodChannel('com.simple_player/thumbnail');

  Future<Uint8List?> generateThumbnail(String path, {int width = 320}) async {
    return await _channel.invokeMethod('generateThumbnail', {
      'path': path,
      'width': width,
    });
  }
}
```

Swift 端实现:
```swift
import QuickLookThumbnailing

func generateThumbnail(path: String, width: Int) async throws -> Data? {
    let url = URL(fileURLWithPath: path)
    let size = CGSize(width: width, height: width * 9 / 16)
    let request = QLThumbnailGenerator.Request(
        fileAt: url, size: size, scale: 2.0,
        representationTypes: .thumbnail
    )
    let thumbnail = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
    return thumbnail.uiImage.pngData()
}
```

---

## 5. Linux 适配方案

### 5.1 GTK 窗口集成

Flutter Linux runner 默认使用 GTK3。`window_manager` 已封装：

```dart
// linux_window_service.dart
class LinuxWindowService with WindowListener implements WindowBridge {
  // window_manager Linux 实现基于 GTK3
  // 差异点:
  // 1. 无 DWM — 通过 GTK CSS 实现毛玻璃效果（或降级）
  // 2. 全屏 — gtk_window_fullscreen / gtk_window_unfullscreen
  // 3. 多显示器 — GdkDisplay.get_monitor_at_window

  @override
  Future<void> init() async {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      backgroundColor: Colors.transparent,
      titleBarStyle: TitleBarStyle.hidden,
      // Linux: 隐藏标题栏后需要自定义标题栏（已有 custom_title_bar.dart）
      windowButtonVisibility: false,
      minimumSize: Size(854, 513),
    );
    // ... 恢复窗口状态
  }
}
```

**Linux 与 Windows 差异点**:

| 功能 | Windows 实现 | Linux 实现 |
|------|-------------|------------|
| 无边框窗口 | WS_THICKFRAME FFI | GTK `decorated: false` |
| 全屏 | SetWindowPos FFI | `gtk_window_fullscreen` |
| 毛玻璃 | DWM `BackdropFilter` | GTK CSS `backdrop-filter` (有限) 或降级 |
| 多显示器 | EnumDisplayMonitors FFI | `GdkDisplay.monitors` |
| 置顶 | `setAlwaysOnTop` | `gtk_window_set_keep_above` |
| 窗口圆角 | DWMWA_WINDOW_CORNER_PREFERENCE | GTK CSS `border-radius` |

### 5.2 GStreamer / fvp 集成

fvp 在 Linux 使用 GStreamer 后端 + Vulkan 渲染：

```dart
// Linux 特有引擎参数
Map<String, String> _linuxEngineParams() {
  return {
    'video.output': 'vulkan',  // 或 'opengl'
    'decode.hw': 'vaapi',      // VAAPI 硬解 (Intel/AMD)
    // NVIDIA 用户可能需要 'nvdec'
    'audio.output': 'pipewire', // 或 'pulse'
  };
}
```

**硬解支持矩阵**:

| GPU 厂商 | 硬解 API | GStreamer 元素 |
|----------|----------|---------------|
| Intel | VA-API | `vaapih264dec`, `vaapih265dec` |
| AMD | VA-API | `vaapih264dec`, `vaapih265dec` |
| NVIDIA | NVDEC/VDPAU | `nvh264dec`, `vdpauh264dec` |

fvp/MDK 内部处理硬解选择，应用层只需配置 `decode.hw` 参数。

### 5.3 文件系统适配

```dart
// Linux 路径策略
class LinuxPathStrategy {
  /// 配置目录 — ~/.config/simple_player/
  static String get configDir =>
      '${Platform.environment['HOME']}/.config/simple_player';

  /// 数据目录 — ~/.local/share/simple_player/
  static String get dataDir =>
      '${Platform.environment['HOME']}/.local/share/simple_player';

  /// 缓存目录 — ~/.cache/simple_player/
  static String get cacheDir =>
      '${Platform.environment['HOME']}/.cache/simple_player';
}
```

使用 `path_provider` 包自动处理 XDG 路径，无需手动实现。

### 5.4 Wayland 兼容性

Wayland 是 Linux 默认显示协议的趋势。关键差异：

| 特性 | X11 | Wayland |
|------|-----|---------|
| 全屏 | `_NET_WM_STATE_FULLSCREEN` | `xdg_toplevel.set_fullscreen` |
| 窗口定位 | `XMoveWindow` | 不支持（由 compositor 控制） |
| 拖拽移动 | `XdndDrag` | `wl_data_device` |
| 置顶 | `_NET_WM_STATE_ABOVE` | 不保证（compositor 依赖） |

**策略**: 依赖 `window_manager` 的抽象，不在应用层直接处理 Wayland/X11 差异。`window_manager` 已处理大部分兼容性问题。

---

## 6. 构建和发布

### 6.1 构建配置

**Windows** (已有):
```bash
flutter build windows --release
# 输出: build/windows/x64/runner/Release/
```

**macOS**:
```bash
flutter build macos --release
# 输出: build/macos/Build/Products/Release/
# 签名: flutter build macos --release --export-options-plist macos/ExportOptions.plist
```

**Linux**:
```bash
flutter build linux --release
# 输出: build/linux/x64/release/bundle/
```

### 6.2 macOS 构建配置

**Xcode 项目配置** (`macos/Runner.xcodeproj`):

```
Build Settings:
  - macOS Deployment Target: 12.0
  - Architectures: arm64, x86_64 (Universal Binary)
  - Code Signing: Developer ID Application
  - Hardened Runtime: Yes
  - App Sandbox: Yes (App Store) / No (直接分发)
```

**Entitlements 文件**:

```xml
<!-- macos/Runner/Release.entitlements -->
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>
</dict>
</plist>
```

### 6.3 Linux 打包格式

| 格式 | 适用场景 | 配置复杂度 |
|------|----------|-----------|
| Snap | Ubuntu 商店 | 中等 — `snapcraft.yaml` |
| Flatpak | Flathub (跨发行版) | 中等 — `*.flatpak-manifest.json` |
| AppImage | 直接下载运行 | 低 — `AppImageBuilder.yml` |
| .deb / .rpm | 特定发行版 | 高 — 各发行版打包脚本 |

**推荐**: Flatpak 优先（Flathub 覆盖面广），AppImage 备选（零依赖运行）。

**Snap 配置示例** (`snap/snapcraft.yaml`):

```yaml
name: simple-player
version: '1.0.0'
summary: Desktop media player
description: |
  Modern desktop video player powered by fvp (MDK/FFmpeg).
grade: stable
confinement: strict
base: core22

parts:
  simple-player:
    plugin: flutter
    source: .
    flutter-target: lib/main.dart

apps:
  simple-player:
    command: simple_player
    extensions: [gnome]
    plugs:
      - home
      - removable-media
      - network
```

### 6.4 发布渠道

| 平台 | 渠道 | 分发方式 |
|------|------|----------|
| Windows | GitHub Releases | .exe 安装包 (已有) |
| Windows | Microsoft Store | MSIX 打包 |
| macOS | GitHub Releases | .dmg (Universal Binary) |
| macOS | Homebrew | `brew install simple-player` |
| macOS | App Store | .pkg via App Store Connect |
| Linux | GitHub Releases | .AppImage / .flatpak |
| Linux | Flathub | Flatpak |
| Linux | Snap Store | Snap |

---

## 7. 测试策略

### 7.1 平台测试矩阵

| 测试层 | Windows | macOS | Linux | 工具 |
|--------|---------|-------|-------|------|
| 单元测试 | 现有 327 tests | 同左 (Dart) | 同左 (Dart) | `flutter test` |
| Widget 测试 | 现有 | 需适配 | 需适配 | `flutter test` |
| 集成测试 | 现有 | 需新增 | 需新增 | `flutter test integration_test/` |
| 平台测试 | Win32 FFI | NSWindow FFI | GTK FFI | 原生测试框架 |
| 性能测试 | 现有 | 需新增 | 需新增 | `flutter test --profile` |

### 7.2 抽象层测试

`WindowBridge` 接口的测试替身已存在（`FakeWindowService`）。新增平台实现需：

1. **接口契约测试**: 确保所有平台实现满足 `WindowBridge` 契约
2. **平台差异测试**: 每个平台的特有行为（如 macOS 全屏动画、Wayland 窗口定位限制）
3. **回归测试**: Windows 现有测试不因抽象层重构而退化

```dart
// 接口契约测试示例
void testWindowBridgeContract(WindowBridge Function() factory) {
  test('init() sets mode to windowed', () async {
    final bridge = factory();
    await bridge.init();
    expect(bridge.mode.value, WindowMode.windowed);
  });

  test('setMode(maximized) updates mode', () async {
    final bridge = factory();
    await bridge.init();
    await bridge.setMode(WindowMode.maximized);
    expect(bridge.mode.value, WindowMode.maximized);
  });
}

// 运行: 每个平台实现都执行相同的契约测试
group('Win32WindowService', () => testWindowBridgeContract(Win32WindowService.new));
group('MacOSWindowService', () => testWindowBridgeContract(MacOSWindowService.new));
group('LinuxWindowService', () => testWindowBridgeContract(LinuxWindowService.new));
```

### 7.3 CI/CD 矩阵

```yaml
# .github/workflows/ci.yaml
jobs:
  test:
    strategy:
      matrix:
        os: [windows-latest, macos-latest, ubuntu-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test --coverage

  build:
    strategy:
      matrix:
        include:
          - os: windows-latest
            build_cmd: flutter build windows --release
          - os: macos-latest
            build_cmd: flutter build macos --release
          - os: ubuntu-latest
            build_cmd: flutter build linux --release
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: ${{ matrix.build_cmd }}
```

### 7.4 macOS 集成测试

macOS 集成测试需注意：
- **签名**: 测试二进制需要签名才能在 macOS 12+ 运行
- **沙箱**: 测试时可临时禁用沙箱 (`com.apple.security.app-sandbox: false`)
- **显示器**: CI 环境无物理显示器 — 使用虚拟显示器 (`CGVirtualDisplay`)

---

## 8. 实施路线图

### Phase 1: 抽象层重构（Windows 保持不变） — 2 周

**目标**: 将现有 Win32 实现移入 `win32/` 子目录，引入平台工厂，零功能变化。

| 任务 | 工作量 | 依赖 |
|------|--------|------|
| 创建 `win32/` 目录结构，迁移 `WindowService` → `Win32WindowService` | 2h | 无 |
| 迁移 `DisplayConfig` 平台分支逻辑 | 1h | 无 |
| 创建 `platform_factory.dart` 条件导入 | 1h | 迁移完成 |
| 更新所有 import 路径 (`WindowService` → `Win32WindowService` / 工厂) | 2h | 工厂完成 |
| 接口契约测试（抽象层） | 3h | 工厂完成 |
| Windows 回归测试 — 确保 327 tests 全部通过 | 2h | import 更新 |
| 更新 `app.dart` DI 注入使用工厂 | 1h | 工厂完成 |

**交付物**: Windows 功能零变化，抽象层测试覆盖 100%。

### Phase 2: macOS 移植 — 3 周

**目标**: macOS 可运行，播放视频，基本窗口管理可用。

| 任务 | 工作量 | 依赖 |
|------|--------|------|
| 创建 `macos/` Flutter runner 配置 | 2h | Phase 1 |
| 实现 `MacOSWindowService` (window_manager 封装) | 4h | Phase 1 |
| 实现 `MacOSDisplayAdapter` (NSScreen) | 3h | Phase 1 |
| `DisplayConfig` macOS 分支 (Metal sync) | 1h | Phase 1 |
| macOS 缩略图服务 (QLThumbnailGenerator MethodChannel) | 4h | 无 |
| 沙箱 Entitlements 配置 | 2h | 无 |
| macOS 构建配置 (Xcode, Universal Binary) | 3h | 无 |
| macOS 窗口行为测试 (全屏/最小化/置顶) | 3h | WindowService |
| macOS 集成测试 (播放/暂停/拖放) | 4h | 缩略图服务 |
| fvp macOS 验证 (VideoToolbox + Metal) | 2h | 构建配置 |

**交付物**: macOS 可播放视频、窗口管理正常、通过集成测试。

### Phase 3: Linux 移植 + 发布准备 — 3 周

**目标**: Linux 可运行，三平台发布包就绪。

| 任务 | 工作量 | 依赖 |
|------|--------|------|
| 创建 `linux/` Flutter runner 配置 | 2h | Phase 1 |
| 实现 `LinuxWindowService` (GTK3 封装) | 4h | Phase 1 |
| 实现 `LinuxDisplayAdapter` (GDK) | 3h | Phase 1 |
| `DisplayConfig` Linux 分支 (Vulkan sync) | 1h | Phase 1 |
| Linux 缩略图服务 (GStreamer thumbnail) | 4h | 无 |
| Wayland/X11 兼容性测试 | 4h | WindowService |
| fvp Linux 验证 (VAAPI/VDPAU + Vulkan) | 3h | 构建配置 |
| Flatpak 打包配置 | 3h | 无 |
| AppImage 打包配置 | 2h | 无 |
| macOS .dmg 打包 | 2h | Phase 2 |
| Windows MSIX 打包 (可选) | 2h | 无 |
| CI/CD 多平台矩阵 | 3h | 所有平台 |
| 发布文档 (README 更新、安装说明) | 2h | 打包完成 |

**交付物**: 三平台发布包、CI/CD 流水线、安装文档。

---

## 9. 风险与缓解

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| fvp macOS/Linux 稳定性不足 | 中 | 高 | 提前验证 fvp 示例项目，必要时贡献 PR |
| macOS 沙箱限制文件访问 | 低 | 中 | 使用 `file_picker` 授权，测试沙箱边界 |
| Wayland 窗口定位限制 | 中 | 低 | 依赖 `window_manager` 抽象，降级处理 |
| Linux 发行版碎片化 | 中 | 中 | Flatpak 优先 (跨发行版)，AppImage 备选 |
| macOS 签名/公证成本 | 低 | 低 | Apple Developer Program $99/年 |
| 抽象层重构破坏 Windows | 低 | 高 | Phase 1 严格回归测试，327 tests 门禁 |

---

## 10. 工作量估算

| 阶段 | 工作量 | 日历时间 | 关键里程碑 |
|------|--------|----------|-----------|
| Phase 1: 抽象层 | ~16h | 2 周 | Windows 零回归，工厂可用 |
| Phase 2: macOS | ~32h | 3 周 | macOS 可播放，集成测试通过 |
| Phase 3: Linux + 发布 | ~33h | 3 周 | 三平台发布包，CI 就绪 |
| **总计** | **~81h** | **8 周** | 三平台可用 |

---

## 附录 A: 现有跨平台代码清单

以下代码已具备跨平台能力，无需修改：

| 文件 | 跨平台原因 |
|------|-----------|
| `lib/kernel/bridge/window_bridge.dart` | 纯抽象接口 |
| `lib/kernel/bridge/window_mode.dart` | 纯 Dart 枚举 |
| `lib/kernel/bridge/window_state.dart` | 纯 Dart 状态容器 |
| `lib/kernel/bridge/window_persistence.dart` | 纯 Dart，依赖 SettingsStore |
| `lib/kernel/bridge/display_enumerator.dart` | 纯抽象接口 |
| `lib/kernel/models/*.dart` | 纯 Dart 数据类 |
| `lib/kernel/playlist/playlist.dart` | 纯 Dart 逻辑 |
| `lib/kernel/services/playback_controller.dart` | 纯 Dart 编排 |
| `lib/kernel/services/playback_navigator.dart` | 纯 Dart 逻辑 |
| `lib/kernel/utils/*.dart` | 纯 Dart 工具 |
| `lib/ui/**/*.dart` | Flutter Widget，自动跨平台 |
| `lib/l10n/**` | Flutter 本地化，自动跨平台 |

## 附录 B: 平台特定代码清单

以下代码需要平台分支或替代实现：

| 文件 | 平台绑定 | 替代方案 |
|------|----------|----------|
| `bridge/win32/win32_display_enumerator.dart` | Win32 FFI | macOS: NSScreen, Linux: GdkMonitor |
| `bridge/display_config.dart` | D3D11 参数 | macOS: Metal, Linux: Vulkan |
| `engine/fvp_engine.dart` | D3D11 参数 | 平台参数工厂 |
| `services/thumbnail_service.dart` | Win32 COM | macOS: QLThumbnail, Linux: GStreamer |
| `kernel/bridge/window_service.dart` | window_manager + Win32 | 各平台 WindowService |

## 附录 C: 参考资料

- [Flutter Desktop Embedding](https://docs.flutter.dev/platform-integration/desktop)
- [window_manager 包](https://pub.dev/packages/window_manager) — 已跨平台
- [fvp 包](https://pub.dev/packages/fvp) — MDK/FFmpeg 跨平台播放器
- [Flutter macOS 签名指南](https://docs.flutter.dev/deployment/macos)
- [Flutter Linux 打包指南](https://docs.flutter.dev/deployment/linux)
- [Flatpak Flutter 示例](https://github.com/niclas3640/flutter_flatpak_example)
