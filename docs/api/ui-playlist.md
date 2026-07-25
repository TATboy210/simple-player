# Playlist UI Widgets

## PlaylistPanel (StatefulWidget)

**File:** `lib/ui/playlist/playlist_panel.dart`

沉浸式浮窗播放列表 — 浮在控制栏上方，毛玻璃背景，水平缩略图。

### Constructor

```dart
const PlaylistPanel({
  required Playlist playlist,
  required bool visible,
  required VoidCallback onClose,
  required void Function(int index) onSelectIndex,
  required void Function(int index) onRemoveIndex,
  void Function(String path)? onShowProperties,
  void Function(String folderPath, List<PlaylistItem> scanned)? onFolderScanned,
  VoidCallback? onClearHistory,
  ValueListenable<bool>? resizing,
  double? availableWidth,
})
```

### Structure

- **上 1/5:** tab 切换（文件夹 / 历史）
- **下 4/5:** 水平缩略图列表

### Interaction

- 点击按钮切换显示/隐藏
- 点击外部区域关闭
- Escape 关闭

---

## FolderTab

**File:** `lib/ui/playlist/folder_tab.dart`

文件夹分组缩略图 tab。

---

## HistoryTab

**File:** `lib/ui/playlist/history_tab.dart`

时间戳排序历史 tab。

---

## ThumbnailTile

**File:** `lib/ui/playlist/thumbnail_tile.dart`

16:9 缩略图卡片。

### Features

- 系统缩略图（通过 ThumbnailService）
- 播放中叠加层
- 迷你进度条
- 文件名标签
