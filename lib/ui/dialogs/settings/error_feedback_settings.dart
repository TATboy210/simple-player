/// 错误反馈设置存储 —— 便携 settings.json（D-01）的加载/保存/内存态单点。
///
/// UI-layer store owning the single error-feedback preference: the error-card
/// toggle (SET-01). State is exposed as a ValueNotifier (project convention,
/// no new state library). Persistence is a portable `settings.json` beside
/// the executable — debug runs keep it beside the project directory — with a
/// two-tier fallback mirroring the log location chain (WR-06/D-02): when the
/// primary directory is not writable (MSIX/ACL-protected install dirs),
/// settings move to Application Support for the session, probed once at load
/// and never per write. Every read/write failure silently keeps the defaults
/// (D-01) so startup and UI are never blocked.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:simple_player_flutter/kernel/diagnostics/error_log_location.dart';

/// 不可变错误反馈设置数据 —— settings.json 的内存形态（扁平 key + version）。
final class ErrorFeedbackSettingsData {
  /// 创建设置快照；字段携带 SET-01 的默认语义。
  const ErrorFeedbackSettingsData({this.errorCardEnabled = true});

  /// SET-01 错误卡片开关 —— 默认开；损坏/缺失文件回退到该值。
  final bool errorCardEnabled;

  /// 值相等 —— 损坏回退后的默认快照与初始态可比（不可变数据类契约）。
  @override
  bool operator ==(Object other) =>
      other is ErrorFeedbackSettingsData &&
      other.errorCardEnabled == errorCardEnabled;

  @override
  int get hashCode => errorCardEnabled.hashCode;
}

/// 错误反馈设置单例 store —— 组合根与设置 UI 的唯一数据源。
///
/// 同步构造零 I/O（先于 runApp 的任何时点都安全）；加载只发生在组合根的
/// unawaited 激活路径内（RESEARCH Pitfall 7：绝不阻塞 MediaKit/window/
/// runApp）。读写失败静默回退默认值（D-01）。
final class ErrorFeedbackSettings {
  ErrorFeedbackSettings._({File Function()? settingsFile})
    : _settingsFile = settingsFile ?? defaultSettingsFile;

  /// 测试专用：以注入 seam 构造独立实例（round-trip 重启模拟用），
  /// 不触碰单例 [I] 的内存态（循 ErrorReporterImpl.forTesting 惯例）。
  @visibleForTesting
  ErrorFeedbackSettings.forTesting({File Function()? settingsFile})
    : _settingsFile = settingsFile ?? defaultSettingsFile;

  /// 全局单例 —— 循 ErrorCaptureSnapshot.I 形态，跨层共享同一份内存态。
  static final ErrorFeedbackSettings I = ErrorFeedbackSettings._();

  /// D-01 默认文件位置策略：debug 存项目目录旁（flutter run 的 cwd）、
  /// release 存 exe 旁（便携哲学：设置跟着可执行文件走）。
  ///
  /// 构造 File 对象本身零 I/O；kDebugMode 是编译期常量，release 构建里
  /// debug 分支被摇树剔除。注意 flutter clean 会清掉 build/ 下的 debug 日志
  /// 与 build 旁设置，但项目目录（cwd）旁的 debug 设置不受影响。
  static File defaultSettingsFile() {
    final Directory base = kDebugMode
        ? Directory.current
        : File(Platform.resolvedExecutable).parent;
    return File('${base.path}${Platform.pathSeparator}settings.json');
  }

  /// 内存态 —— UI（卡片宿主、设置对话框）与组合根订阅此 notifier。
  final ValueNotifier<ErrorFeedbackSettingsData> state =
      ValueNotifier<ErrorFeedbackSettingsData>(
        const ErrorFeedbackSettingsData(),
      );

  /// settings 文件 seam —— 可被 [resetForTesting] 重绑以隔离测试。
  File Function() _settingsFile;

  /// 会话内已解析的生效设置文件（WR-06）—— [load] 时探测一次并缓存，
  /// 之后读写沿用同一层，绝不逐写探测（D-02 哲学：探测一次，记住层级）。
  File? _resolvedSettingsFile;

  /// 从生效层的 settings.json 加载设置；任何失败静默保持默认值（D-01）。
  ///
  /// [applicationSupportDirectory] 为回退层 provider（WR-06，D-02 哲学
  /// 镜像）：层 1（exe 旁，debug 为项目目录旁）目录经**单次**写入探测
  /// 不可写时（MSIX/ACL 保护目录），改用 Application Support 旁
  /// settings.json 并为本次会话记住该层；provider 未注入或两层都不可用
  /// 时维持层 1 文件对象（读写失败静默回默认值，绝不阻断启动）。
  /// Side effect: 层级探测的临时文件 I/O + settings.json 的读取；成功时
  /// 整体更新 [state]。
  /// 形状校验模板循 source_line_reader.dart:236-268（is! Map 守卫承重：
  /// `[1,2]` 解码为 List 而非 Map；空串/尾随垃圾抛 FormatException）。
  /// 未知键（如旧版本残留的第三键）逐字段校验天然忽略，向后兼容。
  Future<void> load({
    ApplicationSupportDirectoryProvider? applicationSupportDirectory,
  }) async {
    final file = await _resolveSettingsFile(applicationSupportDirectory);
    try {
      final text = await file.readAsString();
      final Object? decoded = jsonDecode(text);
      if (decoded is! Map<String, Object?>) {
        // 形状错误（List/null 等）→ 静默回退默认值。
        return;
      }
      // 逐字段独立类型校验：错型字段回退该字段默认值，不抛出。
      final cardEnabled = decoded['errorCardEnabled'];
      state.value = ErrorFeedbackSettingsData(
        errorCardEnabled: cardEnabled is bool ? cardEnabled : true,
      );
    } on FormatException {
      // 尾随垃圾/空串抛 FormatException（实测失败形态）→ 默认值。
    } on FileSystemException {
      // 无文件/不可读 → 默认值。
    } on Exception {
      // 兜底：任何意外异常都绝不阻断启动（D-01）。
    }
  }

  /// SET-01 开关写入：内存态立即生效，fire-and-forget 持久化。
  void setCardEnabled(bool enabled) {
    final next = ErrorFeedbackSettingsData(errorCardEnabled: enabled);
    state.value = next;
    _schedulePersist(next);
  }

  /// 排队一笔 fire-and-forget 持久化（WR-05 串行链）。
  ///
  /// 每笔写入接在前序之后，至多一个 [_atomicWrite] 在飞 —— 并发写同一
  /// settings.json 的共享冲突（Windows errno-32 sharing violation 静默
  /// 丢写）与三级降级「删活文件再 rename」竞态都被消除；前序失败（D-01
  /// 吞没）经 onError 适配器维持链活性，绝不中断后续写入。
  void _schedulePersist(ErrorFeedbackSettingsData next) {
    final pending = _persistFuture;
    _persistFuture = pending
        .then<void>((_) {}, onError: (Object _) {})
        .then((_) => _persist(next));
  }

  /// 最近一次 fire-and-forget 持久化的 Future —— 生产路径不等待；
  /// 测试经 [pendingPersist] 等待写入完成（无生产分支差异）。
  Future<void> _persistFuture = Future<void>.value();

  /// 测试等待点：等待最近一次持久化完成（含被吞没的失败）。
  @visibleForTesting
  Future<void> get pendingPersist => _persistFuture;

  /// 解析本次会话的生效设置文件（WR-06 两层回退，D-02 哲学镜像）。
  ///
  /// 层 1 exe 旁（debug 为项目目录旁）：对该目录做**一次**「create +
  /// 临时文件探测」（复用 kernel 的 validateConfiguredDirectory 单一
  /// 实现，无第二份探测逻辑），可写即用；层 2 Application Support：层 1
  /// 不可写且 provider 注入时改用 AS 旁 settings.json。两层都不可用 →
  /// 维持层 1 文件对象（D-01：读写失败静默回默认值，绝不阻断）。结果
  /// 缓存于 [_resolvedSettingsFile]，每会话至多探测一次。
  Future<File> _resolveSettingsFile(
    ApplicationSupportDirectoryProvider? applicationSupportDirectory,
  ) async {
    final cached = _resolvedSettingsFile;
    if (cached != null) {
      return cached;
    }
    final primary = _settingsFile();
    if (await _isDirectoryWritable(primary.parent)) {
      return _resolvedSettingsFile = primary;
    }
    final asProvider = applicationSupportDirectory;
    if (asProvider != null) {
      try {
        final supportDirectory = await asProvider();
        if (await _isDirectoryWritable(supportDirectory)) {
          return _resolvedSettingsFile = File(
            '${supportDirectory.path}${Platform.pathSeparator}settings.json',
          );
        }
      } on Exception {
        // AS provider 失败（插件/平台异常）→ 维持层 1（D-01 静默）。
      }
    }
    return _resolvedSettingsFile = primary;
  }

  /// 目录可写性的单次探测 —— 复用 kernel 的 validateConfiguredDirectory
  ///（「校验即证明可写」单一实现）；Valid 即可写，Invalid（含探测失败）
  /// 一律视为不可写。绝不抛出。
  static Future<bool> _isDirectoryWritable(Directory directory) async {
    final validation = await ErrorLogLocation.validateConfiguredDirectory(
      directory.path,
    );
    return validation is ConfiguredDirectoryValid;
  }

  /// 序列化并落盘当前设置：原子写 + 保存失败静默吞没（D-01）。
  ///
  /// 任何失败都不向调用方抛出、绝不回滚内存态（window_persistence.dart
  /// 的 on Exception 静默模板）。
  Future<void> _persist(ErrorFeedbackSettingsData next) async {
    try {
      await _atomicWrite(_effectiveSettingsFile(), _encode(next));
    } on Exception {
      // 保存失败静默（D-01）——残缺文件下次 load 静默回退默认值。
    }
  }

  /// 当前生效设置文件 —— 会话内已解析层级优先（WR-06）；未执行 [load] 的
  /// 路径（纯写场景与既有测试形态）退回层 1 默认对象，行为与既有单层一致。
  File _effectiveSettingsFile() => _resolvedSettingsFile ?? _settingsFile();

  /// 原子写：tmp(flush) → rename（replace-on-existing）+ 四级降级链。
  ///
  /// tmp 名唯一（WR-05）：pid + 微秒时间戳后缀 —— 任意两笔写入（含串行链
  /// 之外的多进程/多实例并发源）永不共享同一 .tmp，杜绝共享冲突写丢失；
  /// finally 清理只删本笔自己的 tmp，绝不误删他笔的有效文件。
  ///
  /// Windows 实测语义（RESEARCH Pattern 3 / Pitfall 1）：rename 覆盖已存在
  /// 目标成立，但瞬态 errno-5（杀软/扫描器句柄锁）可使同一操作间歇性
  /// PathAccessException —— 降级链逐级收窄 `on FileSystemException`，任何
  /// 一级成功即返回：
  /// 1. 直接 rename（覆盖已存在目标）；
  /// 2. errno-5 瞬态失败 → 单次重试 rename；
  /// 3. 仍失败 → 删除目标后重试 rename（实测有效的兜底形态）；
  /// 4. 最终兜底 → 直接 writeAsString 覆盖（非原子，但 D-01 使残缺无害）。
  Future<void> _atomicWrite(File target, String contents) async {
    final tmp = File(
      '${target.path}.tmp.$pid-${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      await tmp.writeAsString(contents, flush: true);
      // 第一级：直接 rename（覆盖已存在目标）。
      if (await _tryRename(tmp, target)) {
        return;
      }
      // 第二级：errno-5 瞬态失败 → 单次重试。
      if (await _tryRename(tmp, target)) {
        return;
      }
      // 第三级：删除目标后重试 rename。
      try {
        await target.delete();
      } on FileSystemException {
        // 目标可能本就不存在；rename 的 replace 语义仍可能成功。
      }
      if (await _tryRename(tmp, target)) {
        return;
      }
      // 第四级：最终兜底 —— 直接覆盖写。
      await target.writeAsString(contents, flush: true);
    } finally {
      // best-effort 清理 tmp：任何成功/失败路径都不留 settings.json.tmp。
      try {
        if (await tmp.exists()) {
          await tmp.delete();
        }
      } on FileSystemException {
        // 清理失败不致命（D-01：残缺文件下次 load 静默回退默认值）。
      }
    }
  }

  /// 单次 rename 尝试：失败吞 FileSystemException 返回 false（逐级收窄点）。
  static Future<bool> _tryRename(File tmp, File target) async {
    try {
      await tmp.rename(target.path);
      return true;
    } on FileSystemException {
      return false;
    }
  }

  /// 序列化为扁平 key + version 字段的 JSON（D-01 discretion 形态；
  /// G-04-1 后恰为两键 —— version + errorCardEnabled，无第三键）。
  static String _encode(ErrorFeedbackSettingsData data) =>
      jsonEncode(<String, Object?>{
        'version': 1,
        'errorCardEnabled': data.errorCardEnabled,
      });

  /// 测试隔离：复位内存态为默认值并可选重绑 settings 文件 seam。
  ///
  /// 会话层级缓存一并复位（跨用例残留会让后续用例写到错误层 —— 与
  /// notifier 同一复位理由）。
  /// 禁止生产路径调用（循 ErrorReporterImpl.resetForTesting 惯例）。
  @visibleForTesting
  void resetForTesting({File Function()? settingsFile}) {
    if (settingsFile != null) {
      _settingsFile = settingsFile;
    }
    _resolvedSettingsFile = null;
    state.value = const ErrorFeedbackSettingsData();
    // 串行持久化链一并复位：链头 Future 创建于**上一个用例的 FakeAsync
    // zone**，其完成事件只投递给同 zone 的监听器 —— 跨用例 `.then` 的续体
    // 会被排进已销毁 zone 的队列而永不执行（实测：下一用例的写入永远排在
    // 死链头之后，文件永不落盘）。重建于当前 zone 的空链恢复写入活性；
    // 生产路径无 FakeAsync zone 切换，不受影响。
    _persistFuture = Future<void>.value();
  }
}
