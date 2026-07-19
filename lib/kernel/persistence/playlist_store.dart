import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../playlist/playlist.dart';
import '../utils/debug_probe.dart';
import '../diagnostics/kernel_logger.dart';

final log = KernelLogger.I;

/// 播放列表 JSON 持久化
///
/// 使用 300ms 防抖写入：快速操作（拖拽排序、批量添加）时
/// 合并多次 save() 为一次磁盘写入，减少 I/O 次数。
///
/// C3: 原子写入 — 先写 .tmp 再 rename，防止并发/崩溃导致文件损坏。
/// C4: 测试隔离 — create() 创建独立实例，reset() 清除默认实例状态。
class PlaylistStore {
  static const _fileName = 'playlist.json';
  static const _historyFileName = 'history.json';
  static const _debounceMs = 300;

  /// 调试探针 — 记录播放列表持久化操作的耗时。
  static final DebugProbe probe = DebugProbeRegistry.register('playlistStore');

  /// 默认实例 — 静态方法委托目标
  static PlaylistStore _instance = PlaylistStore();

  /// 写入重试配置 — 指数退避，覆盖磁盘满/临时锁等瞬态故障
  static const _maxRetries = 3;
  static const _retryBaseDelayMs = 100;

  /// 可选的自定义存储路径（测试注入临时目录）
  final String? _storagePath;

  /// 创建播放列表存储实例
  ///
  /// 生产环境使用默认路径（无参数）；测试注入临时目录：
  /// ```dart
  /// final store = PlaylistStore(storagePath: tempDir.path);
  /// store.save(playlist);
  /// ```
  PlaylistStore({String? storagePath}) : _storagePath = storagePath;

  /// 创建独立实例 — 与默认构造函数等价，保留向后兼容
  @Deprecated('Use PlaylistStore(storagePath: ...) directly')
  factory PlaylistStore.create({required String storagePath}) {
    return PlaylistStore(storagePath: storagePath);
  }

  Timer? _debounce;

  /// 存 JSON 快照（String），不存 Playlist 引用。
  /// 防抖期间 Playlist 可能被修改，快照保证写入 save() 调用时的状态。
  String? _pendingJson;

  /// C3: 原子写入守卫 — 防止并发 _flush 交错写入
  Future<void>? _writeInFlight;

  Future<Directory> _appDir() async {
    if (_storagePath != null) return Directory(_storagePath);
    return getApplicationSupportDirectory();
  }

  Future<File> _file() async {
    final dir = await _appDir();
    return File('${dir.path}/$_fileName');
  }

  /// 保存播放列表（300ms 防抖，合并连续写入）
  ///
  /// 立即序列化为 JSON 快照，防抖期间 Playlist 修改不影响已保存的快照。
  static void save(Playlist playlist) {
    _instance._saveImpl(playlist);
  }

  void _saveImpl(Playlist playlist) {
    _pendingJson = jsonEncode(playlist.toJson());
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: _debounceMs), _flushImpl);
  }

  /// C3: 原子写入 + 指数退避重试 — 写 .tmp 后 rename，失败最多重试 3 次
  Future<void> _flushImpl() async {
    final json = _pendingJson;
    if (json == null) return;

    // 等待上一次写入完成，防止并发交错
    if (_writeInFlight != null) {
      await _writeInFlight;
    }

    final completer = Completer<void>();
    _writeInFlight = completer.future;

    try {
      final f = await _file();
      for (var attempt = 0; attempt < _maxRetries; attempt++) {
        try {
          final tmpFile = File('${f.path}.tmp');
          await tmpFile.writeAsString(json, flush: true);
          await tmpFile.rename(f.path);
          return; // 写入成功
        } on Exception catch (e) {
          log.w('PlaylistStore._flush attempt ${attempt + 1} failed: $e');
          if (attempt < _maxRetries - 1) {
            await Future<void>.delayed(
              Duration(milliseconds: _retryBaseDelayMs * (1 << attempt)),
            );
          }
        }
      }
      log.e('PlaylistStore._flush: all $_maxRetries attempts failed');
    } finally {
      completer.complete();
      if (_writeInFlight == completer.future) {
        _writeInFlight = null;
      }
    }
  }

  /// 加载播放列表，失败返回 null
  ///
  /// 首次加载时自动迁移旧 history.json 数据：按 path 合并元数据到 playlist items。
  static Future<Playlist?> load() => _instance._loadImpl();

  Future<Playlist?> _loadImpl() async {
    try {
      final f = await _file();
      Playlist? playlist;

      if (await f.exists()) {
        final content = await f.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        playlist = Playlist.fromJson(json);
      }

      // 迁移旧 history.json（一次性，合并后删除）
      playlist = await _migrateHistory(playlist);
      return playlist;
    } on Exception catch (e) {
      log.e('PlaylistStore.load failed: $e');
      return null;
    }
  }

  /// 后台 Isolate 加载播放列表（文件 I/O + JSON 解析不阻塞 UI）
  ///
  /// 文件读取和 JSON 解析在独立 Isolate 中执行，
  /// 迁移逻辑在主 Isolate 回调中执行（低频一次性操作）。
  /// Isolate 失败时自动回退到 [load]。
  static Future<Playlist?> loadInBackground() =>
      probe.measureAsync('loadInBackground', () => _instance._loadInBackgroundImpl());

  Future<Playlist?> _loadInBackgroundImpl() async {
    try {
      final f = await _file();
      final path = f.path;
      final playlist = await Isolate.run(() => _loadPlaylistSync(path));
      return await _migrateHistory(playlist);
    } on Exception catch (e) {
      log.w('PlaylistStore.loadInBackground failed, falling back: $e');
      return _loadImpl();
    }
  }

  /// Isolate 入口 — 纯 Dart 文件 I/O + JSON 解析
  static Playlist? _loadPlaylistSync(String path) {
    try {
      final f = File(path);
      if (!f.existsSync()) return null;
      final content = f.readAsStringSync();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return Playlist.fromJson(json);
    } on Exception catch (e) {
      log.e('PlaylistStore._loadPlaylistSync failed: $e');
      return null;
    }
  }

  /// 迁移旧 history.json：按 path 合并元数据到 playlist items
  ///
  /// - playlist 有数据：将 history 的 timestamp/positionMs/durationMs 合并到匹配项
  /// - playlist 为空但 history 有数据：从 history 创建 playlist
  /// - 迁移成功后删除 history.json
  Future<Playlist?> _migrateHistory(Playlist? playlist) async {
    try {
      final dir = await _appDir();
      final historyFile = File('${dir.path}/$_historyFileName');
      if (!await historyFile.exists()) return playlist;

      final content = await historyFile.readAsString();
      final list = jsonDecode(content) as List<dynamic>;

      // 解析 history entries，构建 path → metadata map
      final historyMap = <String, Map<String, dynamic>>{};
      for (final entry in list) {
        try {
          final map = entry as Map<String, dynamic>;
          final path = map['path'] as String?;
          if (path != null) historyMap[path] = map;
        } on Exception catch (e) {
          log.d('PlaylistStore._migrateHistory: skipping corrupt entry: $e');
        }
      }

      if (historyMap.isEmpty) {
        await historyFile.delete();
        return playlist;
      }

      // 使用 Playlist.mergeHistory() 合并（无论 playlist 是否为空）
      playlist ??= Playlist();
      playlist.mergeHistory(historyMap);

      // 迁移成功，删除旧文件
      await historyFile.delete();
      log.d('PlaylistStore: migrated history.json');
    } on Exception catch (e) {
      log.e('PlaylistStore._migrateHistory failed: $e');
    }
    return playlist;
  }

  /// 清空（取消防抖，防止清空后回写旧数据）
  static Future<void> clear() => _instance._clearImpl();

  Future<void> _clearImpl() async {
    _debounce?.cancel();
    _pendingJson = null;
    try {
      final f = await _file();
      if (await f.exists()) await f.delete();
    } on Exception catch (e) {
      log.e('PlaylistStore.clear failed: $e');
    }
  }

  /// 释放资源（flush 未写入的数据）
  static Future<void> dispose() => _instance._disposeImpl();

  Future<void> _disposeImpl() async {
    _debounce?.cancel();
    await _flushImpl();
  }

  /// C4: 重置所有实例状态 — 仅供测试使用，防止跨测试泄漏
  ///
  /// 可选 [newInstance] 替换默认实例（用于注入自定义存储路径）。
  @visibleForTesting
  static void reset({PlaylistStore? newInstance}) {
    _instance._debounce?.cancel();
    _instance._debounce = null;
    _instance._pendingJson = null;
    _instance._writeInFlight = null;
    if (newInstance != null) _instance = newInstance;
  }
}
