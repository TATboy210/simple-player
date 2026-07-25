# 安装和配置

## 系统要求

| 项目 | 要求 |
|------|------|
| 操作系统 | Windows 10/11 (64-bit) |
| 磁盘空间 | ~100 MB（应用本身，不含媒体文件） |
| 运行环境 | 无需额外安装，Flutter 运行时和 MDK/FFmpeg 解码库已内置 |
| 推荐配置 | 独立显卡（硬件解码）、4GB+ 内存 |

## 安装方式

### MSIX 安装包（推荐）

1. 从发布页面下载 `SimplePlayer.msix`
2. 双击运行安装包
3. Windows 可能会显示 SmartScreen 警告，点击"更多信息" -> "仍要运行"
4. 按安装向导完成安装
5. 从开始菜单或桌面快捷方式启动 Simple Player

### 从源码构建

适用于开发者或需要自定义构建的用户：

```bash
# 前提：已安装 Flutter SDK 3.11.5+
git clone <repository-url>
cd simple_player_flutter

# 安装依赖
flutter pub get

# 开发运行
flutter run -d windows

# 构建发布版
flutter build windows --release

# 构建 MSIX 安装包
dart run msix:create
```

构建产物位于 `build/windows/x64/runner/Release/` 目录。

## 首次启动

启动 Simple Player 后，您会看到：

1. **极光呼吸动画背景** — 三个 Lissajous 光团缓慢运动
2. **品牌名称** — "S I M P L E   P L A Y E R"，字间距拉宽的轻量字体
3. **副标题** — "沉浸视听体验"
4. **打开文件按钮** — 毛玻璃风格的主操作按钮

此时播放器处于空闲状态（idle），等待加载媒体文件。

## 窗口控制

Simple Player 使用自定义无边框窗口，标题栏提供以下控制：

| 控制 | 操作 | 说明 |
|------|------|------|
| 拖拽移动 | 按住标题栏拖动 | 移动窗口位置 |
| 最大化/还原 | 双击标题栏 | 切换最大化和还原状态 |
| 置顶 | 点击图钉图标 | 将窗口固定在所有窗口之上 |
| 最小化 | 点击最小化按钮 | 最小化到任务栏 |
| 最大化 | 点击最大化按钮 | 最大化窗口 |
| 关闭 | 点击关闭按钮 | 关闭应用 |

窗口支持拖拽边缘调整大小。进入全屏模式后，标题栏自动隐藏，窗口拖拽调整大小功能禁用。
