/// 诊断日志落点解析 —— 配置目录 → exe 根 → Application Support 的三层回退链。
///
/// Resolves the durable diagnostic log target by walking a priority chain of
/// candidate directories and keeping the first provably writable one. The
/// composition root supplies all platform providers, keeping plugin work out
/// of kernel static initialization. Any external failure becomes a typed
/// result and never propagates to the caller.
library;

import 'dart:io';

/// Asynchronous platform seam that resolves the application support directory.
typedef ApplicationSupportDirectoryProvider = Future<Directory> Function();

/// Synchronous platform seam that resolves the executable's own directory.
///
/// 同步缝：运行中可执行文件的位置本身同步可得，但 kernel 不直接读进程位置
/// （保持 kernel 纯度、测试注入临时目录），一律由组合根提供该目录。
typedef ExecutableDirectoryProvider = Directory Function();

/// Injectable writability probe seam —— 缺省为真实临时文件探测。
///
/// Tests inject constant or path-selective probes so filesystem permission
/// behavior never leaks into hermetic assertions.
typedef WritableDirectoryProbe = Future<bool> Function(Directory directory);

/// Typed outcome for default diagnostic log target preparation.
sealed class ErrorLogLocationResult {
  const ErrorLogLocationResult();
}

/// Prepared diagnostic log target under the first writable chain tier.
final class ErrorLogLocationResolved extends ErrorLogLocationResult {
  const ErrorLogLocationResolved(this.file, {this.configuredFailure});

  /// The prepared `logs/error.log` target (configured tier: directly under it).
  final File file;

  /// 配置层被尝试且失败时携带的回退原因（该层收窄捕获的异常对象）；
  /// 配置层缺省或胜出时为 null。供设置 UI 行内呈现回退原因（D-04）。
  final Object? configuredFailure;
}

/// Unavailable default target with its contained external failure reason.
final class ErrorLogLocationUnavailable extends ErrorLogLocationResult {
  const ErrorLogLocationUnavailable(this.error, this.stackTrace);

  /// Provider or filesystem failure retained only for contained bootstrap logging.
  final Object error;

  /// Stack evidence paired with [error] for a non-recursive warning.
  final StackTrace stackTrace;
}

/// 一层候选的准备结果：成功返回 null，失败返回收窄捕获的异常与配对堆栈。
final class _TierFailure {
  const _TierFailure(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}

/// Walks the priority chain 配置目录 → exe 根 → Application Support and keeps
/// the first provably writable `logs/error.log` target.
///
/// 每层执行「幂等 create(recursive) + 临时文件探测」，首个可写层胜出；全部层
/// 失败返回 [ErrorLogLocationUnavailable]（携带最后一层的失败证据），绝不向
/// 调用方抛出。三层参数均可空：为空（或配置为空串）时该层跳过，保持向后
/// 兼容既有单层调用（Phase 2 形态）。
final class ErrorLogLocation {
  ErrorLogLocation._();

  /// Single source of truth for the default child directory.
  static const String logsDirectoryName = 'logs';

  /// Single source of truth for the default diagnostic filename.
  static const String logFileName = 'error.log';

  /// Resolves the first writable diagnostic log target along the chain.
  static Future<ErrorLogLocationResult> resolve({
    required ApplicationSupportDirectoryProvider applicationSupportDirectory,
    ExecutableDirectoryProvider? executableDirectory,
    String? configuredDirectory,
    WritableDirectoryProbe? writable,
  }) async {
    final probe = writable ?? _probeDirectoryWritable;
    try {
      // 层 1：配置目录（settings.logDirectory）——空串/null 跳层
      //（'' = 走默认链，D-01 语义），失败不阻断但携带回退原因（D-02/D-04）。
      final configured = configuredDirectory;
      if (configured != null && configured.isNotEmpty) {
        final configuredDirectory = Directory(configured);
        final failure = await _prepareTier(configuredDirectory, probe);
        if (failure == null) {
          return ErrorLogLocationResolved(_logFileUnder(configuredDirectory));
        }
        return await _resolveDefaultChain(
          probe,
          applicationSupportDirectory,
          executableDirectory,
          configuredFailure: failure.error,
        );
      }
      return await _resolveDefaultChain(
        probe,
        applicationSupportDirectory,
        executableDirectory,
      );
    } on FileSystemException catch (error, stackTrace) {
      return ErrorLogLocationUnavailable(error, stackTrace);
    } on IOException catch (error, stackTrace) {
      return ErrorLogLocationUnavailable(error, stackTrace);
    } on Exception catch (error, stackTrace) {
      return ErrorLogLocationUnavailable(error, stackTrace);
    }
  }

  /// 走默认两层链：exe 根 logs/ → Application Support logs/。
  ///
  /// [configuredFailure] 透传自失败的配置层，使成功层的结果仍携带回退原因。
  static Future<ErrorLogLocationResult> _resolveDefaultChain(
    WritableDirectoryProbe probe,
    ApplicationSupportDirectoryProvider applicationSupportDirectory,
    ExecutableDirectoryProvider? executableDirectory, {
    Object? configuredFailure,
  }) async {
    // 层 2：exe 根 logs/（D-02：exe 根优先于 AS；provider 未注入时跳层）。
    final executableDirectoryProvider = executableDirectory;
    if (executableDirectoryProvider != null) {
      final exeLogs = _logsDirectoryIn(executableDirectoryProvider());
      final failure = await _prepareTier(exeLogs, probe);
      if (failure == null) {
        return ErrorLogLocationResolved(
          _logFileUnder(exeLogs),
          configuredFailure: configuredFailure,
        );
      }
    }
    // 层 3：Application Support logs/（Phase 2 原行为，降为最后回退层）。
    final supportLogs = _logsDirectoryIn(await applicationSupportDirectory());
    final failure = await _prepareTier(supportLogs, probe);
    if (failure == null) {
      return ErrorLogLocationResolved(
        _logFileUnder(supportLogs),
        configuredFailure: configuredFailure,
      );
    }
    return ErrorLogLocationUnavailable(failure.error, failure.stackTrace);
  }

  /// 准备一个候选层：幂等 create(recursive) + 可写探测。
  ///
  /// 成功返回 null；失败返回收窄捕获的证据（供 configuredFailure/降级复用）。
  static Future<_TierFailure?> _prepareTier(
    Directory candidate,
    WritableDirectoryProbe probe,
  ) async {
    try {
      // Side effect: 幂等地准备该层目录后再探测（沿用既有 resolve 惯例）。
      await candidate.create(recursive: true);
      if (await probe(candidate)) {
        return null;
      }
      return _TierFailure(
        FileSystemException('writability probe failed', candidate.path),
        StackTrace.current,
      );
    } on FileSystemException catch (error, stackTrace) {
      return _TierFailure(error, stackTrace);
    } on IOException catch (error, stackTrace) {
      return _TierFailure(error, stackTrace);
    } on Exception catch (error, stackTrace) {
      return _TierFailure(error, stackTrace);
    }
  }

  /// 默认可写探测：带微秒时间戳的临时文件 create/write/flush/delete。
  ///
  /// 实测异常形态：目标段被同名文件占据 → PathExistsException(errno 183)；
  /// file-as-dir 下 writeAsString → PathNotFoundException(errno 3)。
  /// attrib +r 目录并不阻止写入（实测），目录只读属性不是有效探测目标。
  static Future<bool> _probeDirectoryWritable(Directory directory) async {
    // 时间戳防并发碰撞；探测操作与 sink 真正要做的 create/write 等价。
    final probeFile = File(
      '${directory.path}${Platform.pathSeparator}'
      '.write_probe_${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      await probeFile.writeAsString('probe', flush: true);
      return true;
    } on FileSystemException {
      return false;
    } finally {
      // best-effort 清理：delete 失败吞 FileSystemException，不改判可写性。
      try {
        if (await probeFile.exists()) {
          await probeFile.delete();
        }
      } on FileSystemException {
        // 清理失败不推翻探测结论。
      }
    }
  }

  /// 组合一个候选根下的 logs 子目录路径（不触碰文件系统）。
  static Directory _logsDirectoryIn(Directory base) => Directory(
        '${base.path}${Platform.pathSeparator}$logsDirectoryName',
      );

  /// 组合一个候选目录下的诊断日志文件路径（不触碰文件系统）。
  static File _logFileUnder(Directory directory) => File(
        '${directory.path}${Platform.pathSeparator}$logFileName',
      );
}
