# 09 — CI/CD 与构建

> GitHub Actions 工作流、依赖清单、跨平台构建配置。

## GitHub Actions 工作流

项目有 3 个工作流，无 Windows 构建工作流：

### 1. CI (`ci.yml`)

**触发:** push/PR 到 `main` / `master`
**运行环境:** `windows-latest`

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: subosito/flutter-action@v2  (channel: stable, cache: true)
  - flutter pub get
  - dart analyze --fatal-infos
  - flutter test
```

**注意:** 仅运行分析和测试，无构建步骤。

### 2. Build Linux (`build-linux.yml`)

**触发:** push/PR 到 `main`，tags `v*`
**运行环境:** `ubuntu-latest`，超时 30 分钟

```yaml
steps:
  - actions/checkout@v4
  - Install Linux deps: clang, cmake, ninja-build, pkg-config, libgtk-3-dev, liblzma-dev, imagemagick
  - subosito/flutter-action@v2
  - flutter pub get
  - dart analyze --fatal-infos
  - flutter test
  - flutter build linux --release
  - Generate icon PNGs from SVG (16-512px)
  - Package: tar.gz with icons, launcher script, desktop installer
  - Upload artifact: SimplePlayer-Linux (retention: 30 days)
```

**打包内容:**
- `build/linux/x64/release/bundle/` — Flutter 构建产物
- `packaging/linux/icons/` — 多尺寸 PNG 图标
- `simple-player.sh` — 启动脚本
- `install-desktop.sh` — .desktop 文件安装脚本

### 3. Build macOS (`build-macos.yml`)

**触发:** push/PR 到 `main`，tags `v*`
**运行环境:** `macos-latest`，超时 30 分钟

```yaml
steps:
  - actions/checkout@v4
  - subosito/flutter-action@v2
  - flutter pub get
  - dart analyze --fatal-infos
  - flutter test
  - flutter build macos --release
  - brew install create-dmg
  - create-dmg (600x300 窗口, app icon 150x150, drop link 450x150)
  - Upload artifact: SimplePlayer-macOS (retention: 30 days)
```

**DMG 配置:**
- 卷名: "Simple Player"
- 窗口: 600×300, 位置 (200, 120)
- App 图标: (150, 150)
- 拖放链接: (450, 150)

## 缺失项

| 缺失 | 说明 |
|------|------|
| Windows 构建工作流 | 无 `build-windows.yml`，Windows 仅 CI 测试 |
| Release 自动化 | tag 触发构建但无自动发布到 GitHub Releases |
| 代码签名 | macOS/Windows 均无签名步骤 |
| 覆盖率检查 | CI 未配置覆盖率门槛 |

## 依赖清单

### 运行时依赖 (16 个)

| 包 | 版本 | 用途 |
|----|------|------|
| `fvp` | ^0.36.2 | MDK/FFmpeg 视频播放引擎 |
| `path_provider` | ^2.1.5 | 平台路径获取 |
| `file_picker` | ^11.0.2 | 文件选择对话框 |
| `window_manager` | ^0.5.1 | 窗口管理 (标题栏、窗口控制) |
| `shared_preferences` | ^2.5.5 | 键值存储 |
| `desktop_drop` | ^0.7.1 | 拖放支持 |
| `logger` | ^2.5.0 | 日志框架 |
| `dynamic_color` | ^1.8.1 | 动态色彩提取 |
| `widgets_easier` | ^0.0.10 | UI 工具集 |
| `flutter_easy_animations` | ^0.0.2 | 动画库 |
| `ffi` | ^2.1.4 | Dart FFI |
| `path` | ^1.9.1 | 路径操作 |
| `win32` | ^5.12.0 | Win32 API 绑定 |
| `crypto` | ^3.0.6 | 哈希计算 (缩略图缓存 key) |
| `flutter_localizations` | SDK | 本地化支持 |
| `flutter` | SDK | Flutter 框架 |

### 开发依赖 (2 个)

| 包 | 版本 | 用途 |
|----|------|------|
| `flutter_test` | SDK | 测试框架 |
| `flutter_lints` | ^6.0.0 | Lint 规则 |

## SDK 约束

```yaml
environment:
  sdk: ^3.11.5
```

## 构建命令

```bash
# 开发
flutter run -d windows
flutter run -d linux
flutter run -d macos

# Release 构建
flutter build windows --release
flutter build linux --release
flutter build macos --release

# 分析 + 测试
dart analyze --fatal-infos
flutter test
```

## 跨平台差异

| 能力 | Windows | Linux | macOS |
|------|---------|-------|-------|
| 视频引擎 | fvp (D3D11) | fvp (VAAPI) | fvp (Metal) |
| 窗口管理 | Win32 C++ runner | GTK | Cocoa |
| 缩略图 | Win32 COM | 无 | 无 |
| CI 工作流 | 仅测试 | 构建 + 打包 | 构建 + DMG |
| 拖放 | desktop_drop | desktop_drop | desktop_drop |
| FFI | win32 包 | — | — |

## l10n 配置

```yaml
# pubspec.yaml
flutter:
  generate: true  # 启用 gen_l10n
```

```
lib/l10n/
├── app_en.arb     # 英文 (主语言)
├── app_zh.arb     # 中文
└── app_localizations.dart  # 自动生成
```

## 资源

```
assets/fonts/
├── NotoSansSC-Regular.ttf   (400)
├── NotoSansSC-Medium.ttf    (500)
└── NotoSansSC-SemiBold.ttf  (600)
```
