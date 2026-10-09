/// Services 层播放控制模块 — 打开与播放门面（v0.0.5 起队列感知）.
///
/// 本文件实现 [PlaybackController] 作为播放运行时能力的统一入口，UI 层只与本类交互。
///
/// 架构位置：PlayerViewModel → **PlaybackController** → MediaEngine
/// 设计模式：Facade（门面模式）— 简化 UI 层对播放能力的调用路径
///
/// v0.0.5 打开语义（用户拍板「自动装载同目录」）:
/// - 打开单个本地视频 → 扫描同目录视频文件装进队列（[FolderScanner] 排序）,
///   从该文件起播（相册式体验）; 队列权威在 mpv 原生 playlist.
/// - URL / 扫描失败 / 目标不在扫描结果 → 退化为单元素队列.
/// - 拖入多文件的批量装载不经本类（调用方直接走 [QueueControl.openPlaylist]）.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../diagnostics/kernel_logger.dart';
import '../diagnostics/network_diagnostics.dart';
import '../engine/engine_state.dart';
import '../models/validation_error.dart';
import '../scanner/folder_scanner.dart';
import '../utils/debug_probe.dart';
import '../utils/path_utils.dart';
import 'path_validator.dart';
import 'subtitle_service.dart';
import 'track_preference_service.dart';

final _log = KernelLogger.I;

/// 播放控制器 — 播放运行时能力的统一门面入口
///
/// 职责划分：
/// - 打开并播放：[openAndPlay]（路径校验 → 同目录装载 → OpenResult 分发）
/// - 停止卸载：[stopCurrentMedia]
/// - 播放/暂停：pause / play / isPlaying 薄委托（无打开流程交互）
///
/// 生命周期：使用 → dispose()（无 init 副作用，用户设置已移除）
class PlaybackController {
  PlaybackController({
    required this.engine,
    this._onError,
    this._subtitleService,
    this._trackPreferenceService,
    Future<NetworkInterfaceSnapshot?> Function()? networkSnapshotProvider,
  }) : _networkSnapshotProvider =
           networkSnapshotProvider ?? collectNetworkSnapshot {
    // v0.0.6.1 修复: 播放列表切换 (playEntryAt→jumpTo / 自动续播 / shuffle
    // 随机跳转) 从不经过 [openAndPlay], currentFileName/currentPath 因此
    // 永不更新 — 控制栏标题停留在上一个文件. 监听队列代数 + 引擎状态,
    // 跟随**实际装载**的条目同步标题 (见 [_syncCurrentMediaFromQueue]).
    engine.queueRevision.addListener(_syncCurrentMediaFromQueue);
    engine.state.addListener(_syncCurrentMediaFromQueue);
  }

  /// 视频渲染引擎实例.
  ///
  /// Media engine instance.
  final MediaEngine engine;

  /// 错误回调 — 捕获异常时调用（null 表示忽略错误）
  final void Function(PlayerError error)? _onError;

  /// 网络接口快照采集器 — 默认 [collectNetworkSnapshot], 测试可注入 fake (B5/9).
  final Future<NetworkInterfaceSnapshot?> Function() _networkSnapshotProvider;

  /// 字幕服务 — 可选依赖，null 表示无外挂字幕支持
  final SubtitleService? _subtitleService;

  /// 轨道偏好服务 — 可选依赖，null 表示不持久化轨道偏好
  final TrackPreferenceService? _trackPreferenceService;

  /// 调试探针 — 记录播放控制操作的耗时和事件（编译时开关 kDebugMode）.
  ///
  /// Debug probe — records timing and events (compile-time kDebugMode gate).
  final DebugProbe probe = DebugProbeRegistry.register('playback');

  /// 当前播放文件名（仅文件名，不含路径）— UI 层显示标题栏文件名.
  ///
  /// Current playback file name (basename only) — displayed in title bar.
  final ValueNotifier<String> currentFileName = ValueNotifier('');

  /// 当前播放文件绝对路径（null 表示无媒体加载）.
  ///
  /// 替代原 `playlist.current` 的「当前媒体引用」职责；
  /// 队列/历史/断点/播放模式职责已在 v1.8 移除。
  final ValueNotifier<String?> currentPath = ValueNotifier<String?>(null);

  /// 最近一次路径校验错误（null 表示无错误）— UI 层显示用.
  final ValueNotifier<String?> validationError = ValueNotifier<String?>(null);

  /// 错误回调（子模块通过 `_controller.onError?.call(error)` 调用）.
  ///
  /// Error callback invoked by sub-modules.
  void Function(PlayerError error)? get onError => _onError;

  /// 打开请求代数 — [openAndPlay] 在"校验→同目录扫描→装载"之间存在真实
  /// IO 窗口 ([FolderScanner.scan]), 引擎 generation 只覆盖最后一段;
  /// 本计数器在扫描窗口内淘汰旧请求 ([stopCurrentMedia] 同样递增),
  /// 防止"停止后扫描完成又把媒体装回"的竞争.
  int _openRequestGeneration = 0;

  /// 获取字幕服务（可能为 null）.
  ///
  /// Returns the subtitle service, or null if not configured.
  SubtitleService? get subtitleService => _subtitleService;

  /// 获取轨道偏好服务（可能为 null）.
  ///
  /// Returns the track preference service, or null if not configured.
  TrackPreferenceService? get trackPreferenceService => _trackPreferenceService;

  /// 暂停播放 — 直接委托 [MediaEngine.pause]，不与打开流程交互.
  ///
  /// Pauses playback. Thin forwarder; does not touch the open flow.
  void pause() => engine.pause();

  /// 恢复播放 — 直接委托 [MediaEngine.play].
  ///
  /// Resumes playback. Thin forwarder to the engine.
  void play() => engine.play();

  /// 是否正在播放 — 从引擎 [MediaState] notifier 派生，非独立布尔标志.
  bool get isPlaying => engine.state.value == MediaState.playing;

  /// 切换播放与暂停状态。
  ///
  /// 状态合法性与不可切换状态的 no-op 行为由 [MediaEngine] 统一处理。
  void togglePlayPause() => engine.togglePlayPause();

  /// 将当前位置向后跳转 [ms] 毫秒。
  ///
  /// 位置边界由 [MediaEngine] clamp，默认快退 10 秒。
  void skipBack([int ms = 10000]) => engine.skipBack(ms);

  /// 将当前位置向前跳转 [ms] 毫秒。
  ///
  /// 位置边界由 [MediaEngine] clamp，默认快进 10 秒。
  void skipForward([int ms = 10000]) => engine.skipForward(ms);

  // ── 打开与播放（v0.0.5: 同目录自动装载队列）──

  /// 打开并播放文件 — 完整打开流程（路径校验 → 同目录装载 → 副作用提交）.
  ///
  /// 装载语义: 本地视频扫描同目录视频文件成队列, 从该文件起播;
  /// URL/扫描退化 → 单元素队列. 队列权威在 mpv, 面板视图由
  /// [PlaylistCoordinator] 随引擎镜像自动同步, 本类无需通知它.
  ///
  /// 并发安全分两层: 引擎 [OpenResult] 契约覆盖装载段（旧请求返回
  /// [OpenSuperseded]）; 本类 `_openRequestGeneration` 覆盖扫描 IO 窗口
  /// （新请求/停止使旧请求在进引擎前淘汰）. 淘汰的请求不发布任何副作用.
  ///
  /// 返回 true 表示成功打开并开始播放；
  /// false 表示校验失败 / 打开错误 / 被更新请求淘汰。
  Future<bool> openAndPlay(String path) async {
    final requestGen = ++_openRequestGeneration;
    // N1 修复: 入口单点 trim 归一化 — validate 内部虽会 trim, 但原串曾直接
    // 流入下游, 带首尾空格的 URL 会误走同目录扫描 (isUrl 对带空格串返回
    // false) 并把带空格路径交给引擎. 归一化只在此信任边界做一次,
    // normalizedPath 同时喂 validate 与全部下游 — 被校验的值即被装载的值
    // (单一真相源, 不改 _buildQueuePaths/_locateInQueue 签名、不动
    // FolderScanner).
    final normalizedPath = path.trim();
    // N2: 校验失败按类别映射错误码 — classify 判类别, messageFor 取消息,
    // 一次 classify 同时供消息与错误码 (类别单一真相源)。旧实现把一切
    // 校验失败统一报 pathTraversal fatal, 扩展名不符被误报"路径不安全"。
    final failureType = PathValidator.classify(normalizedPath);
    if (failureType != null) {
      final validationMsg = PathValidator.messageFor(
        failureType,
        normalizedPath,
      );
      validationError.value = validationMsg;
      onError?.call(_playerErrorFor(failureType, validationMsg));
      return false;
    }
    validationError.value = null;

    // 同目录装载（毫秒级: FolderScanner 流式扫描 + mpv loadlist 整体装载）;
    // 失败/退化路径均归一为单元素队列, 不阻断打开.
    final queuePaths = await _buildQueuePaths(normalizedPath);
    // 扫描 IO 窗口内被新请求或停止淘汰 → 不进引擎, 也不发布任何状态.
    if (requestGen != _openRequestGeneration) return false;
    final startIndex = _locateInQueue(queuePaths, normalizedPath);
    final result = await engine.openPlaylist(
      queuePaths,
      startIndex: startIndex < 0 ? 0 : startIndex,
    );
    switch (result) {
      case OpenSuccess():
        // 装载成功后再查代数 — 引擎装载期间到达的停止/新请求使本请求过期.
        if (requestGen != _openRequestGeneration) return false;
        // 字幕检测不影响主播放链路，失败仅记录诊断信息。
        unawaited(
          subtitleService?.detectAndLoad(normalizedPath).catchError((
            Object error,
          ) {
            _log.d('Subtitle detection failed: $error');
          }),
        );
        trackPreferenceService?.restoreAfterOpen(engine.mediaInfo);
        engine.play();
        currentFileName.value = PathUtils.basename(normalizedPath);
        currentPath.value = normalizedPath;
        return true;
      case OpenError(:final error):
        // N3 排序契约: 错误先可见, 诊断后补齐 — onError 在快照采集前同步
        // 投递, 网络流失败不再被快照查询(最长 2s)阻塞. 卡片可见字段
        // (message/path/stack)是 reporter 摄入时刻的不可变快照, 时序重排
        // 不影响其完整性.
        onError?.call(error);
        // B5/9: 网络流打开失败时补采本机接口摘要 (interfaceCount +
        // hasNonLoopback), 帮助定位"本机离线"vs"远端不可达". isUrl 门控
        // 确保本地文件失败不触发查询. fire-and-forget: 快照完成后异步
        // 补写进同一 error.context — 红线: 补写后不得二次调 onError
        // (reporter 对 controller 错误无去重, 重复回调产生重复卡片).
        if (PathValidator.isUrl(normalizedPath)) {
          // 镜像字幕检测模式: catchError 降级防未处理异步异常逃逸
          // (T-261009-05, provider 可注入).
          unawaited(
            _enrichNetworkSnapshot(error, requestGen).catchError((Object e) {
              _log.d('Network snapshot enrichment failed: $e');
            }),
          );
        }
        return false;
      case OpenSuperseded():
        // 旧请求被新请求淘汰，不提交任何属于旧请求的副作用。
        return false;
    }
  }

  /// 校验失败类别 → PlayerError 错误码映射 (N2)
  ///
  /// Maps a [ValidationErrorType] to the closest registered error code so
  /// the error card resolves accurate l10n instead of the blanket
  /// pathTraversal fatal misreport. 穷举 switch — 每个类别一个显式映射臂。
  ///
  /// 安全收敛（威胁模型 T-261009fiy-01）：controlCharacters 与
  /// pathTraversal 两个类别臂都显式返回 FileErrorCode.pathTraversal —
  /// 控制字符属注入特征，必须保留安全码与 fatal 语义（isFatal → 卡片
  /// 红色告警），此决策在此可见而非折叠进分类器内部。
  static PlayerError _playerErrorFor(ValidationErrorType type, String message) {
    return switch (type) {
      // 可用性错配类别 — 映射到最贴近的现有可恢复错误码。
      ValidationErrorType.empty => FileError(FileErrorCode.pathEmpty, message),
      ValidationErrorType.invalidUrl => FileError(
        FileErrorCode.invalidUrl,
        message,
      ),
      // 安全收敛臂 1: 控制字符注入 → pathTraversal 安全码 + fatal。
      ValidationErrorType.controlCharacters => FileError(
        FileErrorCode.pathTraversal,
        message,
      ),
      // 安全收敛臂 2: genuine 路径遍历 → pathTraversal 安全码 + fatal。
      ValidationErrorType.pathTraversal => FileError(
        FileErrorCode.pathTraversal,
        message,
      ),
      ValidationErrorType.unsupportedFormat => CodecError(
        CodecErrorCode.unsupportedFormat,
        message,
      ),
      // classify 现不产生 invalidPath（文件系统层校验未接入）——穷举保留臂,
      // 取最贴近现有值 fileNotFound。
      ValidationErrorType.invalidPath => FileError(
        FileErrorCode.fileNotFound,
        message,
      ),
    };
  }

  /// 网络流打开失败时异步补写本机接口摘要 (B5/9; N3 起改为回调后补齐).
  ///
  /// 调用 [_networkSnapshotProvider] 采集快照, 经 [ErrorContext.copyWith]
  /// 把 `networkInterfaceCount`/`networkHasNonLoopback` 附进错误上下文 —
  /// 富集走结构化 copyWith, 后继 ErrorContext 新增字段自动透传, 不再依赖
  /// 逐字段手工重建 (N4, 2026-10-09).
  /// [requestGen] 是发起打开请求时的代数 — await 返回后与
  /// [_openRequestGeneration] 比对 (T-261009-03): 快照等待跨越异步窗口,
  /// 窗口内的新打开/停止 (两处递增点) 均使本请求过期, 陈旧请求不得为
  /// 已被替代的媒体补写诊断. snapshot 为 null (降级/超时) 时无操作;
  /// 调用方负责 isUrl 门控与 unawaited 调度. error 无 context 时以全新
  /// ErrorContext 兜底 (`error.context ?? ErrorContext()`) — 纯
  /// `?.copyWith` 链会静默丢掉无 context 错误的富集, 语义必须保持
  /// "全新 context + 全新 timestamp + 诊断字段落位".
  Future<void> _enrichNetworkSnapshot(PlayerError error, int requestGen) async {
    final snapshot = await _networkSnapshotProvider();
    // generation 守卫: openAndPlay 入口与 stopCurrentMedia 两个递增点
    // 共用同一计数器, 不匹配即请求已被淘汰 — 放弃补写.
    if (requestGen != _openRequestGeneration) return;
    if (snapshot == null) return;
    error.context = (error.context ?? ErrorContext()).copyWith(
      networkInterfaceCount: snapshot.interfaceCount,
      networkHasNonLoopback: snapshot.hasNonLoopback,
    );
  }

  /// 构造装载队列: URL → 单元素; 本地文件 → 同目录视频扫描（文件名升序）.
  /// 目标不在扫描结果（权限/时序等异常）→ 退化为单元素队列, 打开绝不因此失败.
  static Future<List<String>> _buildQueuePaths(String path) async {
    // URL 早退 — 委托 PathValidator 的 URL 判定 (7-scheme 单一真相源:
    // http/https/rtmp/rtsp/srt/udp/tcp), 避免对 URL 做无意义的同目录扫描.
    if (PathValidator.isUrl(path)) return <String>[path];
    final scanned = await FolderScanner.scan(FolderScanner.directoryOf(path));
    if (scanned.isEmpty) return <String>[path];
    final paths = <String>[for (final file in scanned) file.path];
    if (_locateInQueue(paths, path) < 0) return <String>[path];
    return paths;
  }

  /// 在队列中定位目标文件（startIndex 来源）.
  /// 三层回退: 精确匹配 → 大小写不敏感（Windows 语义）→ 文件名匹配;
  /// 全部未命中返回 -1（调用方回退 0）.
  static int _locateInQueue(List<String> paths, String path) {
    var index = paths.indexOf(path);
    if (index >= 0) return index;
    final lowerPath = path.toLowerCase();
    index = paths.indexWhere(
      (candidate) => candidate.toLowerCase() == lowerPath,
    );
    if (index >= 0) return index;
    final base = PathUtils.basename(path).toLowerCase();
    return paths.indexWhere(
      (candidate) => PathUtils.basename(candidate).toLowerCase() == base,
    );
  }

  /// 停止并卸载当前媒体.
  ///
  /// 只有引擎确认媒体已卸载时才清空活动标题与路径；停止失败会保留标题，
  /// 使 UI 与仍可恢复的底层媒体状态保持一致.
  /// 递增请求代数 — 淘汰正卡在扫描窗口里的 [openAndPlay]（防"停止后又装回"）.
  Future<void> stopCurrentMedia() async {
    _openRequestGeneration++;
    await engine.stop();
    if (engine.hasMedia) return;
    currentFileName.value = '';
    currentPath.value = null;
  }

  /// 队列驱动的标题同步 (v0.0.6.1) — 引擎队列代数/状态变化时, 把
  /// currentFileName/currentPath 跟随到**实际装载**的条目.
  ///
  /// 门控: 仅在媒体已装载态 (playing/paused/completed) 跟随 —
  /// - opening/idle (装载中的乐观镜像) 不写入, 防止 OpenError 时标题
  ///   短暂指向打不开的文件 (乐观镜像随后被 stream 回流纠正);
  /// - error 不写入; idle 的标题清空仍由 [stopCurrentMedia] 保守处理
  ///   (停止失败保留标题的既有契约);
  /// - 值相同 (打开文件路径自身的 revision 抖动) 去重跳过.
  void _syncCurrentMediaFromQueue() {
    final state = engine.state.value;
    final loaded =
        state == MediaState.playing ||
        state == MediaState.paused ||
        state == MediaState.completed;
    if (!loaded) return;
    final paths = engine.queuePaths.value;
    final index = engine.queueIndex.value;
    if (index < 0 || index >= paths.length) return;
    final current = paths[index];
    if (current == currentPath.value) return;
    currentPath.value = current;
    currentFileName.value = PathUtils.basename(current);
  }

  // ── 生命周期 ──

  /// 释放运行时资源和状态通知器。
  void dispose() {
    engine.queueRevision.removeListener(_syncCurrentMediaFromQueue);
    engine.state.removeListener(_syncCurrentMediaFromQueue);
    currentFileName.dispose();
    currentPath.dispose();
    validationError.dispose();
  }
}
