# Simple Player Flutter — 云同步方案设计文档

> 技术研究 | 2026-07-20 | 状态: 草案

---

## 1. 执行摘要

### 1.1 目标

为 Simple Player Flutter 实现跨设备播放状态同步能力，使用户在多台设备（桌面 PC、笔记本）之间无缝延续播放体验。

### 1.2 核心功能

| 功能 | 说明 |
|------|------|
| 播放列表同步 | 多设备共享播放列表，支持增删改排序 |
| 播放进度同步 | 断点续播位置跨设备共享 |
| 播放历史同步 | 最近播放记录（timestamp + position + duration） |
| 设置同步 | 用户偏好（音量、字幕、视频处理参数等） |
| 离线优先 | 无网络时正常工作，联网后自动同步 |

### 1.3 预期收益

- **用户体验**: 换设备时无需重新定位播放位置，历史记录不丢失
- **数据安全**: 云端备份防止本地数据丢失（重装系统、磁盘损坏）
- **生态粘性**: 增强多设备用户的使用粘性

### 1.4 非目标（本版本不做）

- 在线媒体流（仍为本地文件播放器）
- 多用户协作（单用户多设备场景）
- 文件内容同步（仅同步元数据，不传视频文件）
- 移动端（当前仅桌面端）

---

## 2. 需求分析

### 2.1 同步数据类型

基于现有持久化结构（`PlaylistStore` + `SettingsStore`），同步数据分为 4 类：

#### 2.1.1 播放列表（Playlist）

```
源: PlaylistStore → playlist.json
格式: { mode, currentIndex, items: [{ path, timestamp, positionMs, durationMs }] }
```

**字段分析:**

| 字段 | 同步? | 说明 |
|------|-------|------|
| `items[].path` | **有条件** | 绝对路径仅在同一设备有意义，需转换为相对路径或内容哈希 |
| `items[].timestamp` | 是 | 最后播放时间 |
| `items[].positionMs` | 是 | 断点位置（核心价值） |
| `items[].durationMs` | 是 | 视频时长 |
| `mode` | 是 | 播放模式偏好 |
| `currentIndex` | 否 | 设备相关的临时状态 |

**关键问题: 文件路径跨设备不一致**

当前 `PlaylistItem.path` 是绝对路径（如 `D:\Videos\movie.mp4`），跨设备无意义。需要引入设备无关的文件标识方案：

- **方案 A**: 文件名 + 大小 hash（`filename_size_hash`）— 简单但冲突概率中等
- **方案 B**: 文件内容 SHA-256 前 1MB — 可靠但计算成本高
- **方案 C**: 设备注册根目录映射（`device_id → root_path`）— 推荐，平衡可靠性与成本

#### 2.1.2 播放历史（History）

播放历史已合并到 PlaylistItem 的 `timestamp` 字段中。同步时按 `timestamp` 降序排序即可恢复历史视图。

#### 2.1.3 应用设置（AppSettings）

```
源: SettingsStore → SharedPreferences
格式: AppSettings (32+ 字段) + locale + themeIndex + shortcuts
```

**同步分类:**

| 类别 | 字段 | 跨设备? |
|------|------|---------|
| **通用偏好** | volume, playMode, isMuted, subtitleFontSize, subtitleColorIndex, subtitleBottomOffset, playbackSpeed | 是 |
| **视频处理** | brightness, contrast, saturation, hue, rotation, aspectRatio, deinterlace | 是 |
| **性能设置** | d3d11Sync, hardwareDecoding | 否（硬件相关） |
| **窗口状态** | windowWidth/Height/X/Y, isMaximized, isAlwaysOnTop | 否（设备相关） |
| **界面偏好** | locale, themeIndex, shortcuts | 是 |
| **轨道偏好** | audioTrackIndex, subtitleTrackIndex, subtitleDelay | 有条件（需映射） |

#### 2.1.4 同步元数据

每条同步记录需要附加：

```json
{
  "syncId": "uuid-v4",
  "deviceId": "device-uuid",
  "lastModified": 1690000000000,
  "version": 42,
  "checksum": "sha256-of-content"
}
```

### 2.2 同步场景

| 场景 | 触发方式 | 优先级 |
|------|----------|--------|
| 应用启动 | 拉取远程最新状态 | P0 |
| 播放进度变化 | 推送增量更新（防抖 30s） | P0 |
| 设置修改 | 推送增量更新（防抖 5s） | P1 |
| 播放列表变更 | 推送增量更新（防抖 3s） | P0 |
| 手动同步 | 用户触发全量同步 | P1 |
| 设备首次配对 | 全量上传 + 选择合并策略 | P0 |

---

## 3. 架构设计

### 3.1 整体架构

```
┌─────────────────────────────────────────────────────┐
│                    客户端 (Flutter)                    │
│                                                       │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────┐   │
│  │PlaylistStore│  │SettingsStore│  │ SyncManager     │   │
│  │ (已有)      │  │ (已有)       │  │ (新增)          │   │
│  └─────┬─────┘  └─────┬──────┘  └────────┬────────┘   │
│        │              │                   │            │
│        └──────────────┼───────────────────┘            │
│                       │                                │
│              ┌────────▼────────┐                       │
│              │  SyncRepository │                       │
│              │  (本地变更队列)   │                       │
│              └────────┬────────┘                       │
│                       │                                │
│              ┌────────▼────────┐                       │
│              │  SyncTransport  │                       │
│              │  (网络抽象层)    │                       │
│              └────────┬────────┘                       │
└───────────────────────┼───────────────────────────────┘
                        │ HTTPS / WebSocket
                        ▼
┌───────────────────────────────────────────────────────┐
│                    服务端 (Cloud)                       │
│                                                       │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────┐  │
│  │  Sync API     │  │  Auth Service │  │ Push Service│  │
│  │  (REST/WS)    │  │  (OAuth2)     │  │ (FCM/APNs)  │  │
│  └──────┬───────┘  └──────────────┘  └────────────┘  │
│         │                                              │
│  ┌──────▼───────┐                                     │
│  │  Data Store   │                                     │
│  │  (Firestore/  │                                     │
│  │   Supabase)   │                                     │
│  └──────────────┘                                     │
└───────────────────────────────────────────────────────┘
```

### 3.2 客户端模块

#### SyncManager — 同步调度器

```dart
/// 云同步调度器 — 管理本地变更检测、远程拉取、冲突解决
///
/// 生命周期与应用一致，由 DI 注入。监听 PlaylistStore/SettingsStore
/// 的变更事件，通过防抖合并后批量推送到云端。
class SyncManager {
  final SyncRepository _repo;
  final SyncTransport _transport;
  final ConflictResolver _resolver;

  /// 启动同步（应用启动时调用）
  Future<void> initialize();

  /// 推送本地变更到云端
  Future<void> pushChanges();

  /// 从云端拉取最新状态
  Future<void> pullChanges();

  /// 全量同步（首次配对或手动触发）
  Future<void> fullSync();

  /// 同步状态流（用于 UI 展示同步指示器）
  Stream<SyncStatus> get statusStream;
}
```

#### SyncRepository — 本地变更队列

```dart
/// 本地变更队列 — 持久化未同步的变更操作
///
/// 使用 SQLite 存储变更日志，保证应用崩溃后变更不丢失。
/// 每条变更记录: { entityType, entityId, operation, payload, timestamp, synced }
class SyncRepository {
  /// 记录本地变更
  Future<void> enqueue(SyncOperation op);

  /// 获取未同步的变更（按时间排序）
  Future<List<SyncOperation>> getPendingChanges();

  /// 标记变更已同步
  Future<void> markSynced(List<String> operationIds);

  /// 清理已同步的旧记录（保留最近 7 天）
  Future<void> cleanup();
}
```

#### SyncTransport — 网络传输层

```dart
/// 网络传输抽象 — 隔离具体云服务实现
///
/// 支持 REST（批量操作）和 WebSocket（实时推送）两种模式。
/// 实现类: FirebaseSyncTransport, SupabaseSyncTransport, etc.
abstract class SyncTransport {
  /// 推送变更批次到云端
  Future<PushResult> push(List<SyncOperation> ops);

  /// 拉取指定时间戳之后的变更
  Future<List<SyncOperation>> pull({required int sinceTimestamp});

  /// 获取设备列表
  Future<List<DeviceInfo>> getDevices();

  /// 注册当前设备
  Future<void> registerDevice(DeviceInfo info);
}
```

### 3.3 服务端模块

| 组件 | 职责 | 技术选型 |
|------|------|----------|
| Sync API | 接收/分发同步操作 | Cloud Functions / Edge Functions |
| Auth Service | 设备认证、用户身份 | Firebase Auth / Supabase Auth |
| Data Store | 持久化同步数据 | Firestore / Supabase PostgreSQL |
| Push Service | 实时通知其他设备 | FCM / Supabase Realtime |

### 3.4 存储层设计

#### 云端数据结构（Firestore 示例）

```
users/{userId}/
  ├── devices/{deviceId}          # 设备注册信息
  │     ├── name: "Office PC"
  │     ├── platform: "windows"
  │     ├── lastSync: timestamp
  │     └── rootPaths: ["D:\\Videos", "E:\\Movies"]
  │
  ├── playlist/{syncId}           # 播放列表项
  │     ├── fileKey: "movie_mp4_a3f2"   # 设备无关标识
  │     ├── fileName: "movie.mp4"
  │     ├── fileSize: 1073741824
  │     ├── timestamp: 1690000000000
  │     ├── positionMs: 45000
  │     ├── durationMs: 7200000
  │     ├── order: 5                      # 列表排序位置
  │     ├── lastModifiedBy: "device-uuid"
  │     └── version: 42
  │
  ├── settings/{settingGroup}     # 设置分组
  │     ├── playback: { volume, playMode, speed, ... }
  │     ├── subtitle: { fontSize, colorIndex, bottomOffset }
  │     ├── video: { brightness, contrast, ... }
  │     ├── interface: { locale, themeIndex, shortcuts }
  │     └── _meta: { version, lastModifiedBy }
  │
  └── syncLog/{logEntry}          # 同步审计日志
        ├── deviceId, operation, entityType
        ├── timestamp, status
        └── conflictResolution (if any)
```

---

## 4. 数据模型

### 4.1 核心实体

```dart
/// 同步操作类型
enum SyncOperationType { create, update, delete, reorder }

/// 同步实体类型
enum SyncEntityType { playlistItem, settings, deviceRegistration }

/// 同步操作 — 变更队列的基本单元
class SyncOperation {
  final String id;              // UUID
  final SyncEntityType entity;
  final String entityId;        // 实体标识 (fileKey / settingGroup)
  final SyncOperationType type;
  final Map<String, dynamic>? payload;
  final int timestamp;          // 毫秒时间戳
  final String deviceId;        // 产生变更的设备
  final int version;            // 乐观锁版本号

  const SyncOperation({
    required this.id,
    required this.entity,
    required this.entityId,
    required this.type,
    this.payload,
    required this.timestamp,
    required this.deviceId,
    required this.version,
  });
}
```

### 4.2 文件标识模型（解决路径问题）

```dart
/// 设备无关的文件标识 — 跨设备同步的核心
///
/// 使用 文件名 + 文件大小 + 前 4KB SHA-256 作为复合键。
/// 不依赖绝对路径，支持不同设备的不同目录结构。
class FileKey {
  final String fileName;
  final int fileSize;
  final String contentHash;   // 前 4KB 的 SHA-256

  /// 生成唯一键: "filename_size_hash_prefix"
  String get key => '${fileName}_${fileSize}_$contentHash';

  /// 从本地文件生成 FileKey
  static Future<FileKey> fromFile(File file) async {
    final stat = await file.stat();
    final bytes = await file.openRead(0, 4096).first;
    final hash = sha256.convert(bytes).toString().substring(0, 16);
    return FileKey(
      fileName: basename(file.path),
      fileSize: stat.size,
      contentHash: hash,
    );
  }
}
```

### 4.3 设备注册模型

```dart
/// 设备信息 — 每台设备注册一次
class DeviceInfo {
  final String deviceId;         // UUID，首次启动生成
  final String deviceName;       // 用户可编辑的显示名
  final String platform;         // "windows" / "macos" / "linux"
  final List<String> rootPaths;  // 该设备的媒体根目录
  final int registeredAt;
  final int lastSyncAt;

  const DeviceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.rootPaths,
    required this.registeredAt,
    required this.lastSyncAt,
  });
}
```

### 4.4 设置同步模型

```dart
/// 设置同步分组 — 按功能域分组减少冲突粒度
class SettingsSyncGroup {
  /// 通用偏好（音量、播放模式、字幕）
  static const playback = 'playback';
  static const subtitle = 'subtitle';
  static const videoProcessing = 'video';

  /// 界面偏好（语言、主题、快捷键）
  static const interface_ = 'interface';

  /// 不同步的设置（设备相关）
  /// window geometry, isMaximized, isAlwaysOnTop,
  /// d3d11Sync, hardwareDecoding
}
```

---

## 5. 同步策略

### 5.1 三层同步模型

```
┌─────────────────────────────────────────────────┐
│  Layer 1: 实时推送（WebSocket / Realtime）       │
│  用途: 播放进度变更的即时同步                     │
│  延迟: < 1s                                      │
│  触发: positionMs 变化（防抖 30s）                │
└────────────────────┬────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────┐
│  Layer 2: 增量同步（REST API）                    │
│  用途: 设置变更、列表增删改                       │
│  延迟: 1-5s                                      │
│  触发: 数据变更（防抖 3-5s） + 应用启动           │
└────────────────────┬────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────┐
│  Layer 3: 全量同步（批量 API）                    │
│  用途: 首次配对、手动同步、数据修复               │
│  延迟: 5-30s（取决于数据量）                     │
│  触发: 用户操作 / 长时间离线后上线                │
└─────────────────────────────────────────────────┘
```

### 5.2 变更检测与防抖

复用现有 `PlaylistStore` 的防抖模式（300ms），针对云同步使用更长的防抖周期：

```dart
/// 同步防抖配置
class SyncDebounceConfig {
  /// 播放进度 — 30s 防抖（频繁变化，低优先级实时性）
  static const position = Duration(seconds: 30);

  /// 播放列表变更 — 3s 防抖（拖拽排序等高频操作）
  static const playlist = Duration(seconds: 3);

  /// 设置变更 — 5s 防抖（滑块等连续操作）
  static const settings = Duration(seconds: 5);
}
```

### 5.3 增量同步流程

```
本地变更 → SyncRepository.enqueue()
         → 防抖等待
         → SyncTransport.push(batch)
         → 服务端应用变更 + 返回冲突
         → SyncRepository.markSynced(成功项)
         → ConflictResolver.resolve(冲突项)
         → 冲突解决后重新入队
```

### 5.4 全量同步流程

```
用户触发 / 首次配对
  → SyncTransport.pull(since: 0)  // 拉取所有数据
  → 与本地数据对比
  → 生成合并计划 (merge plan)
  → 用户确认合并策略 (保留本地 / 保留远程 / 智能合并)
  → 应用合并结果
  → 上传本地独有的数据
  → 完成
```

---

## 6. 冲突解决

### 6.1 冲突类型

| 冲突类型 | 示例 | 频率 |
|----------|------|------|
| **播放进度冲突** | 设备 A 播放到 10:00，设备 B 播放到 15:00 | 高 |
| **设置值冲突** | 设备 A 音量 80%，设备 B 音量 50% | 中 |
| **列表增删冲突** | 设备 A 添加文件 X，设备 B 删除文件 X | 低 |
| **排序冲突** | 设备 A 和 B 以不同顺序排列同一组文件 | 低 |

### 6.2 解决策略

```dart
/// 冲突解决器
class ConflictResolver {
  /// 播放进度: Last-Write-Wins + 取较大 position
  ///
  /// 同一文件在两台设备都有进度时，取更新的 timestamp 对应的值。
  /// 如果 timestamp 相同（极罕见），取较大的 positionMs（用户大概率想继续看更远的位置）。
  SyncOperation resolvePosition(SyncOperation local, SyncOperation remote) {
    if (local.timestamp > remote.timestamp) return local;
    if (remote.timestamp > local.timestamp) return remote;
    // timestamp 相同 — 取较大 position
    final localPos = local.payload?['positionMs'] as int? ?? 0;
    final remotePos = remote.payload?['positionMs'] as int? ?? 0;
    return localPos >= remotePos ? local : remote;
  }

  /// 设置: Last-Write-Wins（按字段粒度）
  ///
  /// 每个设置字段独立解决冲突，不互相影响。
  /// 使用 version 字段做乐观锁。
  SyncOperation resolveSetting(SyncOperation local, SyncOperation remote) {
    return local.version >= remote.version ? local : remote;
  }

  /// 列表增删: Add-Wins（CRDT 思路）
  ///
  /// 删除操作不立即物理删除，标记为 tombstone（保留 30 天）。
  /// 如果远端有 delete 但本地有 update，update 胜出（用户在用这个文件）。
  SyncOperation resolvePlaylist(SyncOperation local, SyncOperation remote) {
    if (local.type == SyncOperationType.delete &&
        remote.type == SyncOperationType.update) {
      return remote; // update 胜出
    }
    return local.timestamp >= remote.timestamp ? local : remote;
  }
}
```

### 6.3 Tombstone 机制

```json
// 被删除的播放列表项在云端保留为 tombstone
{
  "fileKey": "movie_mp4_a3f2",
  "_deleted": true,
  "_deletedAt": 1690000000000,
  "_deletedBy": "device-uuid",
  "version": 43
}
```

Tombstone 保留 30 天后由服务端定时任务清理。

---

## 7. 离线支持

### 7.1 设计原则

**离线优先 (Offline-First)**: 所有功能在无网络时完全可用，同步是增强而非依赖。

### 7.2 本地存储层

```
┌──────────────────────────────────────────────────┐
│  应用层                                            │
│  PlaylistStore (playlist.json) ← 现有，继续使用   │
│  SettingsStore (SharedPreferences) ← 现有         │
├──────────────────────────────────────────────────┤
│  同步层 (新增)                                     │
│  SyncRepository (SQLite)                          │
│  ├── change_queue: 未同步的变更操作                │
│  ├── sync_state: 上次同步时间戳、设备信息          │
│  └── conflict_log: 冲突解决记录                   │
├──────────────────────────────────────────────────┤
│  缓存层 (新增)                                     │
│  RemoteCache (SQLite / Hive)                      │
│  └── 云端数据的本地镜像（用于 diff 对比）          │
└──────────────────────────────────────────────────┘
```

### 7.3 变更队列

离线期间所有变更入队，联网后按序回放：

```dart
/// 变更队列持久化 (SQLite)
class ChangeQueue {
  /// 入队 — 离线时正常调用，变更写入 SQLite
  Future<void> enqueue(SyncOperation op) async {
    await _db.insert('change_queue', {
      'id': op.id,
      'entity_type': op.entity.name,
      'entity_id': op.entityId,
      'operation': op.type.name,
      'payload': jsonEncode(op.payload),
      'timestamp': op.timestamp,
      'device_id': op.deviceId,
      'version': op.version,
      'synced': 0,
    });
  }

  /// 回放 — 联网后按时间顺序推送
  Future<void> replay() async {
    final pending = await getPendingChanges();
    if (pending.isEmpty) return;

    // 按实体分组，合并连续操作
    final batches = _mergeConsecutiveOps(pending);

    for (final batch in batches) {
      try {
        await _transport.push(batch);
        await markSynced(batch.map((op) => op.id).toList());
      } on SyncException catch (e) {
        if (e.hasConflicts) {
          await _resolver.resolveAndRequeue(e.conflicts);
        }
        break; // 暂停回放，等待下次重试
      }
    }
  }

  /// 合并连续操作 — 同一实体的多次 update 合并为最后一次
  List<List<SyncOperation>> _mergeConsecutiveOps(List<SyncOperation> ops) {
    // 实现: 对同一 entityId 的连续 update 操作去重
    // 保留最后一次 update，跳过中间的
    // ...
  }
}
```

### 7.4 网络状态监听

```dart
/// 网络状态监听器
class ConnectivityMonitor {
  final _controller = StreamController<ConnectionStatus>.broadcast();

  Stream<ConnectionStatus> get statusStream => _controller.stream;

  ConnectivityMonitor() {
    // 监听网络变化
    Connectivity().onConnectivityChanged.listen((result) {
      final status = result != ConnectivityResult.none
          ? ConnectionStatus.online
          : ConnectionStatus.offline;
      _controller.add(status);
    });
  }

  /// 联网后自动触发同步
  void onOnline(void Function() syncCallback) {
    statusStream
      .where((s) => s == ConnectionStatus.online)
      .listen((_) => syncCallback());
  }
}
```

### 7.5 冲突日志与用户通知

离线期间可能产生冲突，联网同步后需要通知用户：

```dart
/// 同步结果通知
class SyncNotification {
  final int itemsSynced;
  final int conflictsResolved;
  final List<ConflictDetail> manualConflicts;  // 需要用户手动处理

  /// 自动生成用户可读的通知消息
  String toUserMessage() {
    if (manualConflicts.isEmpty) {
      return '同步完成: $itemsSynced 项已更新';
    }
    return '同步完成: $itemsSynced 项已更新, '
           '${manualConflicts.length} 项需要确认';
  }
}
```

---

## 8. 安全设计

### 8.1 认证方案

```
用户认证流程:
  1. 用户选择 "启用云同步"
  2. 弹出 OAuth2 登录 (Google / GitHub / Email)
  3. 获取 access_token + refresh_token
  4. access_token 存储在系统密钥管理器 (Windows Credential Manager / macOS Keychain)
  5. 每次请求携带 Bearer token
  6. Token 过期前自动刷新
```

**不使用匿名认证** — 数据需要跨设备关联，必须有用户身份。

### 8.2 数据加密

| 层级 | 加密方式 | 说明 |
|------|----------|------|
| 传输层 | TLS 1.3 (HTTPS) | 所有 API 请求强制 HTTPS |
| 存储层 | 服务端加密 (AES-256) | 云服务商提供的静态加密 |
| 应用层 | 可选 E2E 加密 | 用户选择启用时，客户端加密后上传 |

**应用层加密细节（可选 E2E）:**

```dart
/// E2E 加密 — 用户设置的同步数据可选加密
class E2ECrypto {
  /// 从用户密码派生密钥 (PBKDF2, 100k iterations)
  static Future<Uint8List> deriveKey(String password, Uint8List salt) async {
    // 使用 pointycastle 或 cryptography 包
  }

  /// 加密数据 (AES-256-GCM)
  static Future<EncryptedData> encrypt(Map<String, dynamic> data, Uint8List key) async {
    final plaintext = utf8.encode(jsonEncode(data));
    final nonce = _generateNonce(); // 12 bytes
    final cipher = GCMBlockCipher(AESEngine());
    // ...
  }

  /// 解密数据
  static Future<Map<String, dynamic>> decrypt(EncryptedData data, Uint8List key) async {
    // ...
  }
}
```

### 8.3 访问控制

```
数据隔离规则:
  - 每个用户只能访问自己的数据 (users/{userId}/)
  - 设备注册需要有效的 access_token
  - API 请求频率限制: 60 次/分钟/用户
  - 单用户最多注册 10 台设备
```

### 8.4 隐私考虑

- **文件路径**: 仅同步文件名和大小，不暴露完整目录结构
- **播放历史**: 仅存储时间戳和进度，不存储文件内容
- **设备信息**: 仅存储设备名和平台，不采集硬件指纹
- **数据删除**: 用户可随时删除云端所有数据（GDPR 合规）
- **本地优先**: 同步为可选功能，默认关闭

---

## 9. 云服务选择

### 9.1 候选方案对比

| 维度 | Firebase | Supabase | AWS Amplify | 自建 (VPS) |
|------|----------|----------|-------------|------------|
| **实时同步** | Firestore 原生支持 | Realtime 基于 PostgreSQL WAL | AppSync GraphQL | 需自建 WebSocket |
| **离线支持** | Firestore SDK 内置 | 需手动实现 | 需手动实现 | 完全自建 |
| **认证** | Firebase Auth (丰富) | Supabase Auth (GoTrue) | Cognito | 需自建 |
| **成本 (1K 用户)** | $0-25/月 (Spark 计划) | $0-25/月 (免费额度高) | $10-50/月 | $5-20/月 VPS |
| **Flutter SDK** | 官方维护 | 社区 + 官方 | 社区 | 无 |
| **数据模型** | NoSQL (文档) | PostgreSQL (关系) | DynamoDB/GraphQL | 自选 |
| **供应商锁定** | 高 | 低 (PostgreSQL) | 高 | 无 |
| **开发速度** | 快 | 快 | 中 | 慢 |
| **桌面端支持** | Dart SDK 支持 | REST API | REST API | REST API |

### 9.2 推荐方案: Supabase

**推荐理由:**

1. **PostgreSQL 关系模型** — 播放列表项、设置、设备之间的关系用 SQL 表达更自然
2. **低供应商锁定** — PostgreSQL 随时可迁移
3. **免费额度充足** — 500MB 数据库 + 1GB 文件存储 + 50K MAU
4. **Realtime 支持** — 基于 PostgreSQL WAL 的实时推送
5. **Row Level Security** — 内置行级权限控制，天然支持多用户隔离
6. **Edge Functions** — Deno/TypeScript 编写同步逻辑

**Supabase 架构:**

```sql
-- 播放列表项
CREATE TABLE playlist_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  file_key TEXT NOT NULL,         -- 设备无关文件标识
  file_name TEXT NOT NULL,
  file_size BIGINT NOT NULL,
  content_hash TEXT NOT NULL,
  timestamp_ms BIGINT,
  position_ms BIGINT,
  duration_ms BIGINT,
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_deleted BOOLEAN DEFAULT FALSE,
  version INTEGER NOT NULL DEFAULT 1,
  last_modified_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, file_key)
);

-- 设置分组
CREATE TABLE settings_groups (
  user_id UUID REFERENCES auth.users(id),
  group_name TEXT NOT NULL,       -- 'playback', 'subtitle', 'video', 'interface'
  data JSONB NOT NULL,
  version INTEGER NOT NULL DEFAULT 1,
  last_modified_by UUID,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY(user_id, group_name)
);

-- 设备注册
CREATE TABLE devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  name TEXT NOT NULL,
  platform TEXT NOT NULL,
  root_paths TEXT[] DEFAULT '{}',
  last_sync_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Row Level Security
ALTER TABLE playlist_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can only access own playlist"
  ON playlist_items FOR ALL
  USING (auth.uid() = user_id);
```

### 9.3 备选方案: Firebase Firestore

如果团队更熟悉 Firebase 生态：

```
优势:
  - Firestore 离线同步 SDK 开箱即用
  - 实时监听 (onSnapshot) 无需额外配置
  - Firebase Auth 集成最成熟

劣势:
  - NoSQL 数据模型对关系查询不友好
  - 供应商锁定严重
  - 桌面端 Dart SDK 偶有兼容性问题
  - 成本随读写次数增长，不可预测
```

---

## 10. 实施路线图

### Phase 1: 基础设施 (4 周)

**目标**: 云服务搭建 + 核心同步链路打通

| 任务 | 工时 | 产出 |
|------|------|------|
| 云服务初始化 (Supabase 项目 + 表结构) | 3d | Supabase 项目、SQL schema |
| 客户端认证模块 (OAuth2 登录流程) | 5d | `SyncAuthService` |
| FileKey 生成模块 (文件标识方案) | 3d | `FileKey` + 测试 |
| SyncTransport 抽象层 + Supabase 实现 | 5d | `SyncTransport` 接口 + 实现 |
| 基础 REST 同步 (push/pull) | 5d | 增量同步链路 |
| 设备注册与管理 | 2d | 设备 CRUD |
| 单元测试 + 集成测试 | 5d | 核心模块测试覆盖 > 80% |

**里程碑**: 一台设备上传播放列表，另一台设备能拉取并显示。

### Phase 2: 冲突解决 + 离线支持 (3 周)

**目标**: 离线可用 + 冲突自动解决

| 任务 | 工时 | 产出 |
|------|------|------|
| SQLite 变更队列 (SyncRepository) | 3d | 变更队列持久化 |
| 冲突检测与解决器 | 5d | `ConflictResolver` |
| Tombstone 机制 | 2d | 软删除 + 30 天清理 |
| 网络状态监听 + 自动重连 | 2d | `ConnectivityMonitor` |
| 离线回放逻辑 | 3d | 联网后自动回放队列 |
| 同步状态 UI (状态指示器) | 2d | 标题栏同步图标 |
| 冲突通知 UI | 2d | 冲突确认对话框 |
| 端到端测试 | 3d | 多设备同步场景测试 |

**里程碑**: 离线使用后联网自动同步，冲突自动解决率达 95%。

### Phase 3: 设置同步 + 优化 (3 周)

**目标**: 全量功能 + 性能优化 + 用户体验打磨

| 任务 | 工时 | 产出 |
|------|------|------|
| AppSettings 分组同步 | 3d | 4 个设置分组独立同步 |
| 全量同步 + 首次配对流程 | 3d | 合并策略选择 UI |
| Realtime 推送 (Supabase Realtime) | 3d | 播放进度实时同步 |
| 变更队列合并优化 | 2d | 连续操作去重 |
| 操作审计日志 | 2d | 同步历史记录 |
| E2E 加密 (可选) | 3d | 应用层加密 |
| 性能优化 (批量操作、压缩) | 2d | 大播放列表同步性能 |
| 文档 + 用户指南 | 2d | 设置页同步说明 |
| 全量回归测试 | 2d | 确保不影响现有功能 |

**里程碑**: 生产就绪，全功能可用。

### 总体时间线

```
Week 1-4:  Phase 1 — 基础设施
Week 5-7:  Phase 2 — 离线 + 冲突
Week 8-10: Phase 3 — 设置同步 + 优化

总工时: ~10 周 (单人) 或 ~5 周 (双人并行)
```

### 依赖项

| 依赖 | 当前状态 | 影响 |
|------|----------|------|
| `sqflite` 或 `drift` | 未引入 | Phase 1 需新增 SQLite 依赖 |
| `supabase_flutter` | 未引入 | Phase 1 需新增 |
| `connectivity_plus` | 未引入 | Phase 2 需新增 |
| `oauth2` / `googleapis_auth` | 未引入 | Phase 1 认证模块 |
| `cryptography` | 未引入 | Phase 3 E2E 加密 (可选) |

### 风险评估

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| 文件路径映射不准确 | 高 | 高 | 多维度文件匹配 (name+size+hash)，允许手动关联 |
| 大播放列表同步慢 | 中 | 中 | 分页同步、增量传输、压缩 |
| 冲突频繁导致用户体验差 | 中 | 高 | 提高防抖阈值、默认保守策略 (Last-Write-Wins) |
| 云服务成本超预期 | 低 | 中 | 监控用量、设置预算告警 |
| 桌面端 OAuth2 回调复杂 | 中 | 中 | 使用 Supabase 的 PKCE flow 或 deep link |

---

## 附录 A: 现有持久化结构总结

基于代码分析，当前持久化层:

| 组件 | 存储方式 | 数据 | 位置 |
|------|----------|------|------|
| `PlaylistStore` | JSON 文件 | 播放列表 + 项 + 历史元数据 | `playlist.json` |
| `SettingsStore` | SharedPreferences | 32+ 设置字段 | 系统 KV 存储 |
| `Playlist` | 内存模型 | items + currentIndex + mode | — |
| `PlaylistItem` | 数据类 | path + timestamp + positionMs + durationMs | — |
| `AppSettings` | 数据类 | 所有设置字段的不可变快照 | — |

**关键发现:**

- `PlaylistStore` 已有 300ms 防抖 + 原子写入 + 重试机制，可复用模式
- `PlaylistItem.path` 是绝对路径，云同步需引入 `FileKey` 机制
- `SettingsStore` 使用 SharedPreferences (KV)，同步需按功能域分组
- `ImportResult` sealed class 已有导入/导出框架，可扩展为云同步

## 附录 B: 与现有 Import/Export 的关系

`SettingsStore` 已有 `exportSettings()` / `importSettings()` 功能，输出格式为 `ExportData` JSON。云同步可以:

1. **复用序列化逻辑** — `ExportData.toMap()` 的 JSON 格式可直接作为云同步的 payload
2. **扩展 ImportResult** — 新增 `SyncImportResult` 变体支持冲突检测
3. **分组同步** — 将单一 export JSON 拆分为 4 个独立同步组，减少冲突粒度

---

*文档结束 — 后续根据技术选型结果细化实施细节*
