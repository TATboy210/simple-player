# CI/CD Configuration Plan — simple_player_flutter

> Version: 1.0 | Date: 2026-07-20 | Status: Draft

---

## 1. 执行摘要

### 1.1 CI/CD 目标

为 simple_player_flutter（Flutter 桌面媒体播放器）建立完整的 CI/CD 流水线，覆盖代码质量保障、多平台构建验证、自动化发布三大核心场景。项目基于 fvp（MDK/FFmpeg）引擎，需在 Windows、macOS、Linux 三平台构建。

### 1.2 主要功能

| 功能 | 说明 |
|------|------|
| 静态分析 | `flutter analyze --strict`（strict-casts/inference/raw-types）全量闸门 |
| 单元测试 | `flutter test --coverage` 覆盖率 >= 80% |
| 多平台构建 | Windows / macOS / Linux 矩阵构建验证 |
| 特性标志矩阵 | `USE_NEW_FULLSCREEN` 等 dart-define 组合测试 |
| 自动发布 | Tag 触发 + MSIX / DMG / AppImage 打包 + GitHub Release |
| 覆盖率报告 | PR 评论 + Codecov 集成 |
| 依赖缓存 | Flutter SDK + pub 缓存 + build runner 缓存 |
| 安全扫描 | Secret scanning + 依赖审计 |

### 1.3 预期收益

- **质量门禁**：每次 PR 自动验证分析 + 测试 + 构建，阻断低质量代码合入
- **发布效率**：手动触发 tag 即可完成三平台打包 + GitHub Release 创建
- **反馈速度**：缓存策略将 CI 时间从 ~15min 降至 ~5min
- **合规安全**：密钥最小权限 + 依赖漏洞自动检测

---

## 2. 现状分析

### 2.1 已有工作流

项目已有两个 GitHub Actions 工作流：

| 文件 | 触发条件 | 功能 |
|------|----------|------|
| `.github/workflows/ci.yml` | push/PR to master, manual | analyze + test + build 矩阵（3 平台）+ feature flag 矩阵 |
| `.github/workflows/release.yml` | manual (version input) | Windows 构建 + MSIX 打包 + GitHub Release |

### 2.2 已有能力

- [x] 三平台构建矩阵（Windows/macOS/Linux）
- [x] Flutter SDK 缓存（`subosito/flutter-action` cache: true）
- [x] 静态分析（`flutter analyze --fatal-infos`）
- [x] 单元测试
- [x] 特性标志矩阵（USE_NEW_FULLSCREEN 组合）
- [x] MSIX 打包 + GitHub Release
- [x] Linux 桌面构建依赖安装

### 2.3 缺失能力

- [ ] 测试覆盖率报告（`--coverage` 未启用）
- [ ] 覆盖率 PR 评论 / Codecov 集成
- [ ] macOS / Linux 发布构建（release.yml 仅 Windows）
- [ ] 依赖缓存（pub 缓存、build_runner 缓存）
- [ ] 文档生成工作流
- [ ] 依赖安全审计（`dart pub audit`）
- [ ] 构建产物版本化命名
- [ ] 失败通知（Slack / Discord / Email）
- [ ] Release Notes 自动生成
- [ ] 版本号自动同步检查

---

## 3. CI/CD 架构设计

### 3.1 整体架构

```
┌─────────────────────────────────────────────────────────┐
│                    GitHub Actions                         │
│                                                          │
│  ┌──────────┐   ┌──────────┐   ┌──────────────────┐    │
│  │  ci.yml   │   │release.yml│   │    docs.yml      │    │
│  │ Quality   │   │  Release  │   │  Documentation   │    │
│  │  Gates    │   │ Pipeline  │   │  Generation      │    │
│  └────┬─────┘   └─────┬────┘   └────────┬─────────┘    │
│       │               │                  │               │
│  ┌────▼─────┐   ┌─────▼────┐   ┌────────▼─────────┐    │
│  │Analyze   │   │Build     │   │ dart doc          │    │
│  │Test      │   │Package   │   │ Deploy to Pages   │    │
│  │Build     │   │Release   │   │                   │    │
│  │Coverage  │   │Notify    │   │                   │    │
│  └──────────┘   └──────────┘   └───────────────────┘    │
│                                                          │
│  ┌──────────────────────────────────────────────────┐    │
│  │              Shared Infrastructure                │    │
│  │  • Flutter SDK Cache    • Pub Dependency Cache    │    │
│  │  • Build Runner Cache   • Artifact Upload         │    │
│  │  • Secret Management    • Notification Dispatch   │    │
│  └──────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

### 3.2 触发条件矩阵

| 工作流 | push:master | PR:master | tag:v* | schedule | workflow_dispatch |
|--------|-------------|-----------|--------|----------|-------------------|
| ci.yml | Yes | Yes | - | - | Yes |
| release.yml | - | - | Yes | - | Yes (version input) |
| docs.yml | Yes | - | - | Weekly | Yes |

### 3.3 环境要求

| 组件 | 版本 | 说明 |
|------|------|------|
| Flutter SDK | stable channel | 通过 `subosito/flutter-action@v2` 安装 |
| Dart SDK | ^3.11.5 | Flutter SDK 自带 |
| Windows Runner | windows-latest | Windows 构建 + MSIX |
| macOS Runner | macos-latest | macOS 构建 + DMG |
| Linux Runner | ubuntu-latest | Linux 构建 + AppImage |

**Linux 桌面构建依赖：**
```bash
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev
```

---

## 4. GitHub Actions 工作流详细设计

### 4.1 ci.yml — 质量门禁工作流

#### 4.1.1 触发条件

```yaml
on:
  push:
    branches: [master]
  pull_request:
    branches: [master]
  workflow_dispatch:
```

#### 4.1.2 作业设计

**Job 1: quality-gates（三平台矩阵）**

| 步骤 | 命令 | 说明 |
|------|------|------|
| Checkout | `actions/checkout@v4` | 拉取代码 |
| Flutter SDK | `subosito/flutter-action@v2` | 安装 + 缓存 |
| Linux 依赖 | `apt-get install` | clang/cmake/ninja/gtk3 |
| 缓存恢复 | `actions/cache@v4` | pub 缓存 + build_runner 缓存 |
| 静态分析 | `flutter analyze --fatal-infos` | 严格模式，info 视为 error |
| 内核 lint 闸门 | `grep -rn 'debugPrint(' lib/kernel/` | 内核层禁用 debugPrint |
| 单元测试 | `flutter test --coverage` | 生成 lcov.info |
| 构建验证 | `flutter build ${{ matrix.platform }}` | 冒烟测试 |
| 覆盖率上传 | `codecov/codecov-action@v4` | 仅 ubuntu 上传 |
| 缓存保存 | `actions/cache/save` | 保存 pub 缓存 |

**Job 2: flag-matrix（Windows 特性标志组合）**

| flags 组合 | 说明 |
|------------|------|
| (default) | USE_NEW_FULLSCREEN=false |
| USE_NEW_FULLSCREEN=true | 新全屏模式 |
| USE_NEW_FULLSCREEN=true + USE_WINDOWS_NATIVE_FULLSCREEN=true | 原生全屏 |

**Job 3: dependency-audit（依赖安全审计）**

| 步骤 | 命令 | 说明 |
|------|------|------|
| Checkout | `actions/checkout@v4` | 拉取代码 |
| Flutter SDK | `subosito/flutter-action@v2` | 安装 |
| 依赖审计 | `dart pub audit` | 检查已知漏洞 |
| 许可证检查 | `dart run dart_dependency_validator` | 许可证合规 |

**Job 4: version-check（版本一致性检查）**

| 步骤 | 说明 |
|------|------|
| 提取 pubspec.yaml 版本 | 解析 version 字段 |
| 与 CHANGELOG 对比 | 确保 CHANGELOG 有对应条目 |
| 与 git tag 对比 | 检查版本未重复 |

#### 4.1.3 矩阵策略

```yaml
strategy:
  fail-fast: false
  matrix:
    include:
      - os: windows-latest
        platform: windows
        build-output: build/windows/x64/runner/Release/
      - os: macos-latest
        platform: macos
        build-output: build/macos/Build/Products/Release/
      - os: ubuntu-latest
        platform: linux
        build-output: build/linux/x64/release/bundle/
```

#### 4.1.4 缓存策略

```yaml
- name: Cache pub dependencies
  uses: actions/cache@v4
  with:
    path: |
      ${{ env.PUB_CACHE }}
      .dart_tool/
      build/
    key: ${{ runner.os }}-pub-${{ hashFiles('**/pubspec.lock') }}
    restore-keys: |
      ${{ runner.os }}-pub-
```

#### 4.1.5 完整示例配置

```yaml
name: CI

on:
  push:
    branches: [master]
  pull_request:
    branches: [master]
  workflow_dispatch:

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

env:
  FLUTTER_VERSION: 'stable'

jobs:
  # Job 1: Quality Gates — analyze + test + build on all 3 platforms
  quality-gates:
    strategy:
      fail-fast: false
      matrix:
        include:
          - os: windows-latest
            platform: windows
          - os: macos-latest
            platform: macos
          - os: ubuntu-latest
            platform: linux
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: ${{ env.FLUTTER_VERSION }}
          cache: true

      - name: Install Linux dependencies
        if: matrix.platform == 'linux'
        run: |
          sudo apt-get update
          sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev

      - name: Cache pub dependencies
        uses: actions/cache@v4
        with:
          path: |
            ${{ env.PUB_CACHE }}
            .dart_tool/
          key: ${{ runner.os }}-pub-${{ hashFiles('**/pubspec.lock') }}
          restore-keys: |
            ${{ runner.os }}-pub-

      - name: Install dependencies
        run: flutter pub get

      # Quality Gate 1: Static analysis (strict-casts + strict-inference + strict-raw-types)
      - name: Analyze
        run: flutter analyze --fatal-infos

      # Quality Gate 1b: Kernel layer debugPrint guard
      - name: Kernel lint gate
        if: matrix.platform == 'linux'
        run: |
          violations=$(grep -rn 'debugPrint(' lib/kernel/ | grep -v kernel_logger.dart | grep -v '//' || true)
          if [ -n "$violations" ]; then
            echo "::error::debugPrint found in lib/kernel/:"
            echo "$violations"
            exit 1
          fi

      # Quality Gate 2: Unit + widget tests with coverage
      - name: Test
        run: flutter test --coverage

      # Quality Gate 3: Build smoke test
      - name: Build
        run: flutter build ${{ matrix.platform }}

      # Coverage report (Linux only — single upload to avoid duplicates)
      - name: Upload coverage
        if: matrix.platform == 'linux'
        uses: codecov/codecov-action@v4
        with:
          file: coverage/lcov.info
          flags: unit
          fail_ci_if_error: false
        env:
          CODECOV_TOKEN: ${{ secrets.CODECOV_TOKEN }}

      # PR comment with coverage summary (Linux only)
      - name: Coverage comment
        if: matrix.platform == 'linux' && github.event_name == 'pull_request'
        uses: MishaKav/flutter-coverage-comment@main
        with:
          coverage-path: coverage/lcov.info

  # Job 2: Feature flag matrix (Windows only)
  flag-matrix:
    needs: quality-gates
    runs-on: windows-latest
    strategy:
      fail-fast: false
      matrix:
        flags:
          - ''
          - '--dart-define=USE_NEW_FULLSCREEN=true'
          - '--dart-define=USE_NEW_FULLSCREEN=true --dart-define=USE_WINDOWS_NATIVE_FULLSCREEN=true'
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: ${{ env.FLUTTER_VERSION }}
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Test with flags
        run: flutter test ${{ matrix.flags }}

      - name: Build with flags
        run: flutter build windows ${{ matrix.flags }}

  # Job 3: Dependency audit
  dependency-audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: ${{ env.FLUTTER_VERSION }}

      - name: Install dependencies
        run: flutter pub get

      - name: Dependency audit
        run: dart pub audit

  # Job 4: Version consistency check
  version-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Check version not duplicated in tags
        run: |
          VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}')
          if git tag -l "v$VERSION" | grep -q .; then
            echo "::error::Version v$VERSION already has a git tag"
            exit 1
          fi
          echo "Version v$VERSION is available for release"
```

---

### 4.2 release.yml — 发布工作流

#### 4.2.1 触发条件

```yaml
on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:
    inputs:
      version:
        description: 'Version tag (e.g., v1.0.0-rc.1)'
        required: true
```

#### 4.2.2 作业设计

**Job 1: build-windows**
| 步骤 | 命令 | 产物 |
|------|------|------|
| Checkout | `actions/checkout@v4` | - |
| Flutter SDK | `subosito/flutter-action@v2` | - |
| 构建 | `flutter build windows --dart-define=USE_NEW_FULLSCREEN=true` | EXE |
| MSIX 打包 | `dart run msix:create` | MSIX |
| 上传 | `actions/upload-artifact@v4` | MSIX + EXE |

**Job 2: build-macos**
| 步骤 | 命令 | 产物 |
|------|------|------|
| Checkout | `actions/checkout@v4` | - |
| Flutter SDK | `subosito/flutter-action@v2` | - |
| 构建 | `flutter build macos` | .app |
| DMG 打包 | `create-dmg` 或 `appdmg` | DMG |
| 上传 | `actions/upload-artifact@v4` | DMG |

**Job 3: build-linux**
| 步骤 | 命令 | 产物 |
|------|------|------|
| Checkout | `actions/checkout@v4` | - |
| Flutter SDK | `subosito/flutter-action@v2` | - |
| Linux 依赖 | `apt-get install` | - |
| 构建 | `flutter build linux` | bundle |
| AppImage 打包 | `appimage-builder` 或 tar.gz | AppImage |
| 上传 | `actions/upload-artifact@v4` | AppImage |

**Job 4: create-release**
| 步骤 | 说明 |
|------|------|
| 下载所有构建产物 | `actions/download-artifact@v4` |
| 生成 Release Notes | `gh release generate-notes` |
| 创建 GitHub Release | `softprops/action-gh-release@v2` |
| 附加所有平台产物 | MSIX + DMG + AppImage |

#### 4.2.3 完整示例配置

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:
    inputs:
      version:
        description: 'Version tag (e.g., v1.0.0-rc.1)'
        required: true

permissions:
  contents: write

env:
  FLUTTER_VERSION: 'stable'

jobs:
  # Build Windows (MSIX + portable EXE)
  build-windows:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: ${{ env.FLUTTER_VERSION }}
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Build Windows
        run: flutter build windows --dart-define=USE_NEW_FULLSCREEN=true --release

      - name: Create MSIX
        run: dart run msix:create

      - name: Upload Windows artifacts
        uses: actions/upload-artifact@v4
        with:
          name: windows-release
          path: |
            build/windows/x64/runner/Release/*.msix
            build/windows/x64/runner/Release/simple_player_flutter.exe

  # Build macOS (DMG)
  build-macos:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: ${{ env.FLUTTER_VERSION }}
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Build macOS
        run: flutter build macos --release

      - name: Create DMG
        run: |
          brew install create-dmg
          create-dmg \
            --volname "Simple Player" \
            --window-pos 200 120 \
            --window-size 600 400 \
            --icon-size 100 \
            --icon "Simple Player.app" 175 192 \
            --hide-extension "Simple Player.app" \
            --app-drop-link 425 192 \
            "SimplePlayer-${{ inputs.version || github.ref_name }}.dmg" \
            "build/macos/Build/Products/Release/"

      - name: Upload macOS artifacts
        uses: actions/upload-artifact@v4
        with:
          name: macos-release
          path: "*.dmg"

  # Build Linux (tar.gz bundle)
  build-linux:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: ${{ env.FLUTTER_VERSION }}
          cache: true

      - name: Install Linux dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev

      - name: Install dependencies
        run: flutter pub get

      - name: Build Linux
        run: flutter build linux --release

      - name: Package Linux bundle
        run: |
          cd build/linux/x64/release/bundle
          tar -czf ../../../../../SimplePlayer-${{ inputs.version || github.ref_name }}-linux-x64.tar.gz *

      - name: Upload Linux artifacts
        uses: actions/upload-artifact@v4
        with:
          name: linux-release
          path: "SimplePlayer-*-linux-x64.tar.gz"

  # Create GitHub Release with all artifacts
  create-release:
    needs: [build-windows, build-macos, build-linux]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Download all artifacts
        uses: actions/download-artifact@v4
        with:
          path: release-artifacts

      - name: Generate release notes
        id: notes
        run: |
          PREV_TAG=$(git tag --sort=-v:refname | head -2 | tail -1)
          CURRENT_TAG=${{ inputs.version || github.ref_name }}
          NOTES=$(gh release generate-notes $CURRENT_TAG --previous-tag $PREV_TAG || echo "Initial release")
          echo "notes<<EOF" >> $GITHUB_OUTPUT
          echo "$NOTES" >> $GITHUB_OUTPUT
          echo "EOF" >> $GITHUB_OUTPUT
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          tag_name: ${{ inputs.version || github.ref_name }}
          name: Simple Player ${{ inputs.version || github.ref_name }}
          body: ${{ steps.notes.outputs.notes }}
          prerelease: ${{ contains(inputs.version || github.ref_name, 'rc') || contains(inputs.version || github.ref_name, 'beta') || contains(inputs.version || github.ref_name, 'alpha') }}
          files: |
            release-artifacts/**/*.msix
            release-artifacts/**/*.exe
            release-artifacts/**/*.dmg
            release-artifacts/**/*.tar.gz
```

---

### 4.3 docs.yml — 文档生成工作流

#### 4.3.1 触发条件

```yaml
on:
  push:
    branches: [master]
    paths:
      - 'lib/**'
      - 'doc/**'
  schedule:
    - cron: '0 6 * * 1'  # 每周一 UTC 06:00
  workflow_dispatch:
```

#### 4.3.2 作业设计

| 步骤 | 命令 | 说明 |
|------|------|------|
| Checkout | `actions/checkout@v4` | 拉取代码 |
| Flutter SDK | `subosito/flutter-action@v2` | 安装 |
| 生成文档 | `dart doc` | API 文档生成 |
| 部署到 Pages | `peaceiris/actions-gh-pages@v4` | 发布到 GitHub Pages |

#### 4.3.3 完整示例配置

```yaml
name: Documentation

on:
  push:
    branches: [master]
    paths:
      - 'lib/**'
  schedule:
    - cron: '0 6 * * 1'
  workflow_dispatch:

permissions:
  contents: write
  pages: write

jobs:
  generate-docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: 'stable'

      - name: Install dependencies
        run: flutter pub get

      - name: Generate API docs
        run: dart doc

      - name: Deploy to GitHub Pages
        uses: peaceiris/actions-gh-pages@v4
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: doc/api
          destination_dir: api
          force_orphan: true
```

---

## 5. 静态分析作业详细设计

### 5.1 分析规则

项目 `analysis_options.yaml` 已配置严格模式：

```yaml
analyzer:
  language:
    strict-casts: true         # 禁止隐式 dynamic cast
    strict-inference: true     # 禁止类型推断失败
    strict-raw-types: true     # 禁止裸泛型
  errors:
    missing_required_param: error
    missing_return: error
    dead_code: warning
```

### 5.2 Lint 规则

| 规则 | 级别 | 说明 |
|------|------|------|
| prefer_const_constructors | error | 优先使用 const 构造器 |
| prefer_const_literals_to_create_immutables | error | 优先 const 字面量 |
| prefer_final_locals | error | 局部变量优先 final |
| avoid_print | error | 禁止 print，必须用 debugPrint |
| cancel_subscriptions | warning | 必须取消订阅 |
| close_sinks | warning | 必须关闭 Sink |
| unawaited_futures | warning | Future 必须 await |

### 5.3 自定义闸门

**内核层 debugPrint 检查（CI grep 闸门）：**

```bash
# analysis_options.yaml 无法限制目录级 lint，用 CI 脚本兜底
violations=$(grep -rn 'debugPrint(' lib/kernel/ | grep -v kernel_logger.dart | grep -v '//' || true)
if [ -n "$violations" ]; then
  echo "::error::debugPrint found in lib/kernel/ (must use KernelLogger)"
  echo "$violations"
  exit 1
fi
```

### 5.4 分析优化

- `--fatal-infos`：将 info 级别 lint 视为 error，零容忍
- `--fatal-warnings`：可选，更严格模式
- 并行化：各平台独立运行分析，无依赖

---

## 6. 单元测试作业详细设计

### 6.1 测试执行

```bash
# 基本执行
flutter test

# 带覆盖率
flutter test --coverage

# 指定平台
flutter test --platform=vm

# 带特性标志
flutter test --dart-define=USE_NEW_FULLSCREEN=true
```

### 6.2 覆盖率要求

| 指标 | 目标 | 当前状态 |
|------|------|----------|
| 行覆盖率 | >= 80% | 待测量 |
| 分支覆盖率 | >= 70% | 待测量 |
| 覆盖率趋势 | 不低于上次 | - |

### 6.3 覆盖率报告

**PR 评论集成：**

```yaml
- name: Coverage comment
  if: matrix.platform == 'linux' && github.event_name == 'pull_request'
  uses: MishaKav/flutter-coverage-comment@main
  with:
    coverage-path: coverage/lcov.info
```

**Codecov 集成：**

```yaml
- name: Upload coverage
  if: matrix.platform == 'linux'
  uses: codecov/codecov-action@v4
  with:
    file: coverage/lcov.info
    flags: unit
  env:
    CODECOV_TOKEN: ${{ secrets.CODECOV_TOKEN }}
```

### 6.4 测试隔离

- 每个测试文件独立运行，无共享状态
- 使用 `'test-${name}-${DateTime.now().millisecondsSinceEpoch}'` 作为唯一控制器名
- Fakes over mocks：手写测试替身优先于 Mockito

### 6.5 已知问题

mdk.dll 在 headless CI 环境下 FFI 加载可能失败（预存在问题，非代码回归）。解决方案：

```yaml
- name: Test
  run: flutter test
  continue-on-error: false  # 保持严格
```

如果 mdk.dll 问题持续，可考虑：
1. 标记涉及 FFI 的测试为 `@Tags(['ffi'])`，CI 中排除
2. 或使用 `skip` 条件跳过 headless 环境下的 FFI 测试

---

## 7. 构建作业详细设计

### 7.1 构建矩阵

| 平台 | Runner | 构建命令 | 产物格式 |
|------|--------|----------|----------|
| Windows | windows-latest | `flutter build windows --release` | EXE + MSIX |
| macOS | macos-latest | `flutter build macos --release` | .app + DMG |
| Linux | ubuntu-latest | `flutter build linux --release` | bundle + tar.gz |

### 7.2 平台特定依赖

**Linux：**

```yaml
- name: Install Linux dependencies
  if: matrix.platform == 'linux'
  run: |
    sudo apt-get update
    sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev
```

**macOS：**

```yaml
- name: Install macOS dependencies
  if: matrix.platform == 'macos'
  run: |
    brew install create-dmg
```

**Windows：**

```yaml
- name: Install Windows dependencies
  if: matrix.platform == 'windows'
  run: |
    # MSIX 工具通过 dart run msix:create 自动安装
```

### 7.3 版本化产物命名

```bash
# 从 pubspec.yaml 提取版本
VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}')
TAG=${{ inputs.version || github.ref_name }}

# 产物命名规范
# Windows: SimplePlayer-${TAG}-windows-x64.msix
# macOS:   SimplePlayer-${TAG}-macos.dmg
# Linux:   SimplePlayer-${TAG}-linux-x64.tar.gz
```

### 7.4 特性标志构建

发布构建启用新特性标志：

```bash
# Windows 发布构建
flutter build windows --release \
  --dart-define=USE_NEW_FULLSCREEN=true

# 可选：原生全屏
flutter build windows --release \
  --dart-define=USE_NEW_FULLSCREEN=true \
  --dart-define=USE_WINDOWS_NATIVE_FULLSCREEN=true
```

### 7.5 构建优化

- `--release` 模式：启用 tree-shaking + AOT 编译
- Flutter SDK 缓存：避免每次重新下载
- pub 缓存：`$PUB_CACHE` 目录缓存
- 并行构建：三平台独立 Job，并行执行

---

## 8. 环境和密钥管理

### 8.1 GitHub Secrets

| Secret 名称 | 用途 | 必需 |
|-------------|------|------|
| `CODECOV_TOKEN` | Codecov 上传覆盖率报告 | 推荐 |
| `SLACK_WEBHOOK_URL` | Slack 失败通知（可选） | 可选 |

### 8.2 GitHub Token

`GITHUB_TOKEN` 由 GitHub Actions 自动提供，用于：

- 创建 Release
- 上传 Release 产物
- 部署 GitHub Pages
- PR 评论

**权限配置：**

```yaml
permissions:
  contents: write      # 创建 Release + 上传产物
  pages: write         # 部署文档
  pull-requests: write # PR 评论（覆盖率）
```

### 8.3 密钥安全原则

| 原则 | 说明 |
|------|------|
| 最小权限 | 每个 Job 只申请必需的 permissions |
| 不泄露 | 确保密钥不出现在日志中（使用 `::add-mask::`） |
| 环境隔离 | 发布 Job 使用独立 environment（如 `production`） |
| 审计追踪 | 所有密钥使用记录在 Actions 日志中可追溯 |

### 8.4 环境保护规则（推荐）

```yaml
# 在 GitHub Settings > Environments 中配置
# Environment: production
# - Required reviewers: 1+
# - Wait timer: 5 minutes
# - Deployment branches: master + tags
```

---

## 9. 缓存策略

### 9.1 缓存层次

| 层次 | 缓存内容 | Key 策略 | 预期收益 |
|------|----------|----------|----------|
| L1 | Flutter SDK | channel + version | 省 ~3min SDK 下载 |
| L2 | pub dependencies | pubspec.lock hash | 省 ~2min pub get |
| L3 | build_runner 输出 | pubspec.lock + lib/ hash | 省 ~1min 代码生成 |
| L4 | build 输出 | 全源码 hash | 省 ~3min 增量构建 |

### 9.2 缓存配置

```yaml
# L1: Flutter SDK (subosito/flutter-action 内置)
- uses: subosito/flutter-action@v2
  with:
    channel: 'stable'
    cache: true  # 内置 SDK 缓存

# L2: pub 依赖缓存
- name: Cache pub dependencies
  uses: actions/cache@v4
  with:
    path: |
      ${{ env.PUB_CACHE }}
      .dart_tool/
    key: ${{ runner.os }}-pub-${{ hashFiles('**/pubspec.lock') }}
    restore-keys: |
      ${{ runner.os }}-pub-

# L3: build_runner 缓存
- name: Cache build_runner
  uses: actions/cache@v4
  with:
    path: |
      .dart_tool/build/
      .dart_tool/generated/
    key: ${{ runner.os }}-build-runner-${{ hashFiles('**/pubspec.lock') }}-${{ hashFiles('lib/**/*.dart') }}
    restore-keys: |
      ${{ runner.os }}-build-runner-${{ hashFiles('**/pubspec.lock') }}-
```

### 9.3 缓存失效策略

| 触发条件 | 失效缓存 |
|----------|----------|
| pubspec.lock 变更 | L2 + L3 + L4 |
| lib/**/*.dart 变更 | L3 + L4 |
| analysis_options.yaml 变更 | L4 |
| Flutter SDK 版本变更 | L1 + L2 + L3 + L4 |

### 9.4 缓存大小限制

- GitHub Actions 缓存限制：10GB / 仓库
- Flutter SDK 缓存：~1.5GB
- pub 缓存：~500MB
- build_runner 缓存：~200MB
- **总计：~2.2GB / 平台，在限制内**

---

## 10. 通知和报告

### 10.1 失败通知

**Slack 通知（可选）：**

```yaml
- name: Notify on failure
  if: failure()
  uses: slackapi/slack-github-action@v2
  with:
    payload: |
      {
        "text": "CI Failed: ${{ github.repository }}@${{ github.ref }}",
        "blocks": [
          {
            "type": "section",
            "text": {
              "type": "mrkdwn",
              "text": ":x: *CI Failed*\n*Repo:* `${{ github.repository }}`\n*Branch:* `${{ github.ref }}`\n*Commit:* `${{ github.sha }}`\n*Workflow:* <${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}|View>"
            }
          }
        ]
      }
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

**Email 通知（GitHub 内置）：**

在 GitHub Settings > Notifications 中配置：
- Workflow failure 通知 → Email
- 仅通知 pushes to master

### 10.2 覆盖率报告

**PR 评论格式：**

```
## Flutter Test Coverage

| Metric | Coverage |
|--------|----------|
| Lines | 82.5% |
| Functions | 85.0% |
| Branches | 71.2% |

<details>
<summary>File-by-file coverage</summary>

| File | Line Coverage |
|------|-------------|
| lib/kernel/engine/fvp_engine.dart | 90.2% |
| lib/kernel/services/playback_controller.dart | 85.7% |
...

</details>
```

### 10.3 构建摘要

```yaml
- name: Build summary
  if: always()
  run: |
    echo "## Build Results" >> $GITHUB_STEP_SUMMARY
    echo "| Platform | Status |" >> $GITHUB_STEP_SUMMARY
    echo "|----------|--------|" >> $GITHUB_STEP_SUMMARY
    echo "| Windows | ${{ steps.build-windows.outcome }} |" >> $GITHUB_STEP_SUMMARY
    echo "| macOS | ${{ steps.build-macos.outcome }} |" >> $GITHUB_STEP_SUMMARY
    echo "| Linux | ${{ steps.build-linux.outcome }} |" >> $GITHUB_STEP_SUMMARY
```

---

## 11. 安全考虑

### 11.1 权限最小化

```yaml
# 每个 Job 独立声明所需权限
permissions:
  contents: read  # 默认只读

jobs:
  create-release:
    permissions:
      contents: write  # 仅发布 Job 需要写权限
```

### 11.2 依赖安全

| 措施 | 实现 |
|------|------|
| 依赖审计 | `dart pub audit`（CI Job） |
| Lock 文件提交 | `pubspec.lock` 必须提交到 git |
| 版本锁定 | 生产依赖使用 `^` 语义版本范围 |
| 漏洞通知 | GitHub Dependabot 自动 PR |

### 11.3 供应链安全

```yaml
# 固定第三方 Action 版本到 SHA（防供应链攻击）
- uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
- uses: subosito/flutter-action@27c3c65bcf17e5b18e9ab5e75fca0fc0fbd5a3e5  # v2.12.0
```

### 11.4 构建产物完整性

```yaml
- name: Generate checksums
  run: |
    cd release-artifacts
    sha256sum *.msix *.dmg *.tar.gz > SHA256SUMS.txt

- name: Upload checksums
  uses: actions/upload-artifact@v4
  with:
    name: checksums
    path: release-artifacts/SHA256SUMS.txt
```

### 11.5 Secret 保护

```yaml
- name: Mask secrets in logs
  run: |
    echo "::add-mask::${{ secrets.SOME_TOKEN }}"
```

---

## 12. 实施路线图

### 12.1 Phase 1 — 基础增强（1-2 天）

**目标：** 在现有 ci.yml 基础上增强，零破坏性变更

| 任务 | 优先级 | 预计工时 |
|------|--------|----------|
| 启用覆盖率收集 (`--coverage`) | P0 | 30min |
| 添加 pub 缓存策略 | P0 | 30min |
| 添加 concurrency 控制 | P0 | 15min |
| 添加内核层 debugPrint 闸门 | P1 | 15min |
| 添加依赖审计 Job | P1 | 30min |
| 添加版本一致性检查 Job | P1 | 30min |

**交付物：**
- 更新后的 `ci.yml`，包含覆盖率 + 缓存 + 新 Job

### 12.2 Phase 2 — 发布自动化（2-3 天）

**目标：** 三平台发布 + 自动 Release Notes

| 任务 | 优先级 | 预计工时 |
|------|--------|----------|
| macOS 构建 + DMG 打包 | P0 | 2h |
| Linux 构建 + tar.gz 打包 | P0 | 1h |
| Tag 触发发布 | P0 | 1h |
| 自动生成 Release Notes | P1 | 1h |
| 产物版本化命名 | P1 | 30min |
| SHA256 校验和 | P1 | 30min |

**交付物：**
- 更新后的 `release.yml`，支持三平台发布

### 12.3 Phase 3 — 完善和优化（1-2 天）

**目标：** 通知、文档、安全加固

| 任务 | 优先级 | 预计工时 |
|------|--------|----------|
| 覆盖率 PR 评论集成 | P1 | 1h |
| Codecov 集成 | P1 | 30min |
| 文档生成工作流 (docs.yml) | P2 | 1h |
| Slack 失败通知（可选） | P2 | 30min |
| Action SHA 固定（供应链安全） | P2 | 1h |
| 环境保护规则配置 | P2 | 30min |

**交付物：**
- 新增 `docs.yml`
- 安全加固后的所有工作流
- 配置文档

---

## 13. 维护指南

### 13.1 日常维护

| 任务 | 频率 | 说明 |
|------|------|------|
| 检查 CI 失败 | 每日 | 修复 flaky tests |
| 更新 Flutter SDK | 每月 | stable channel 自动更新 |
| 更新 Action 版本 | 每季度 | Dependabot PR |
| 清理旧缓存 | 每月 | GitHub 自动清理 7 天未用 |
| 审查覆盖率趋势 | 每周 | Codecov dashboard |

### 13.2 故障排查

| 症状 | 可能原因 | 解决方案 |
|------|----------|----------|
| mdk.dll 加载失败 | headless 环境 FFI 问题 | 标记 `@Tags(['ffi'])` 跳过 |
| macOS 构建超时 | Runner 资源不足 | 重试 / 增加 timeout |
| 缓存未命中 | pubspec.lock 变更 | 预期行为，等待重建 |
| Linux 构建失败 | 依赖版本冲突 | 更新 apt 包版本 |
| 覆盖率下降 | 新代码未测试 | 阻断合入直到补充测试 |

### 13.3 版本升级检查清单

- [ ] Flutter SDK stable channel 最新版本
- [ ] `subosito/flutter-action` 最新版本
- [ ] 所有 `actions/*` 最新版本
- [ ] pubspec.lock 已更新并提交
- [ ] CI 通过所有平台
- [ ] 覆盖率 >= 80%
- [ ] 依赖审计无漏洞

---

## 14. 附录

### 14.1 文件清单

| 文件 | 状态 | 说明 |
|------|------|------|
| `.github/workflows/ci.yml` | 需更新 | 添加覆盖率、缓存、新 Job |
| `.github/workflows/release.yml` | 需重写 | 三平台发布 + 自动 Notes |
| `.github/workflows/docs.yml` | 新增 | API 文档生成 |
| `.github/dependabot.yml` | 推荐新增 | 依赖自动更新 |
| `codecov.yml` | 推荐新增 | Codecov 配置 |

### 14.2 Dependabot 配置（推荐）

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "pub"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5

  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "monthly"
    open-pull-requests-limit: 5
```

### 14.3 Codecov 配置（推荐）

```yaml
# codecov.yml
coverage:
  status:
    project:
      default:
        target: 80%
        threshold: 2%
    patch:
      default:
        target: 80%

comment:
  layout: "reach,diff,flags,files"
  behavior: default
  require_changes: false
```

### 14.4 参考资源

| 资源 | 链接 |
|------|------|
| GitHub Actions 文档 | https://docs.github.com/en/actions |
| subosito/flutter-action | https://github.com/subosito/flutter-action |
| Codecov Flutter 集成 | https://docs.codecov.com/docs/flutter |
| MSIX 打包 | https://pub.dev/packages/msix |
| Dependabot 配置 | https://docs.github.com/en/code-security/dependabot |

---

*End of CI/CD Configuration Plan*
