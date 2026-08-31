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

  /// 配置层被尝试且失败时携带的回退原因：探测/创建失败为该层收窄捕获的
  /// 异常对象，形态拒绝（相对路径/UNC 等，WR-03）为封闭原因枚举值；
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

/// 用户配置目录校验的失败原因封闭集 —— 可被 UI 映射为本地化文案。
///
/// Closed set of configured-directory validation failures so the settings UI
/// can map each reason to localized inline copy (D-04) without string matching.
enum ConfiguredDirectoryFailure {
  /// 空串/纯空白或相对路径 —— 用户配置的是目录，必须是绝对路径。
  notAbsolute,

  /// 含 null 字节或控制字符（借 path_validator.dart:98-107 的拒绝哲学：
  /// 目录校验只做字符级防御，路径遍历交由探测与封闭写路径约束）。
  invalidCharacters,

  /// UNC 网络路径（\\server\share 与 //server/share 两种分隔符形态）——
  /// A3 采纳：v1 拒绝并文档化，用户可后续放开；断网的驱动器会让诊断
  /// 证据静默不可达，v1 选择拒收。
  uncPathUnsupported,

  /// 超过 [ErrorLogLocation.maxConfiguredPathLength] 的极端输入。
  pathTooLong,

  /// 形态合法但目录创建或写入探测失败（被同名文件占据/权限不足等），
  /// [ConfiguredDirectoryInvalid.error] 携带收窄捕获的原始异常。
  notWritable,
}

/// 用户配置目录的单层校验结果（sealed —— 调用方以 switch 穷举）。
sealed class ConfiguredDirectoryValidation {
  const ConfiguredDirectoryValidation();
}

/// 校验通过：目录已创建且经写入探测证明可写，可作为 sink 落点。
final class ConfiguredDirectoryValid extends ConfiguredDirectoryValidation {
  const ConfiguredDirectoryValid(this.directory);

  /// The prepared, probe-proven directory the sink may write into.
  final Directory directory;
}

/// 校验失败：携带封闭原因与收窄捕获的原始异常（仅作 contained 证据随行，
/// 不含报告正文，也绝不向调用方抛出）。
final class ConfiguredDirectoryInvalid extends ConfiguredDirectoryValidation {
  const ConfiguredDirectoryInvalid(this.reason, {this.error});

  /// The closed-set reason for UI localization mapping.
  final ConfiguredDirectoryFailure reason;

  /// The narrowed original exception, retained only as contained evidence.
  final Object? error;
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

  /// 用户配置目录的静态长度上界 —— 日志目录的常识上界（防极端输入占满
  /// 探测/写路径；远超任何合理盘符路径，普通用户不受影响）。
  static const int maxConfiguredPathLength = 1024;

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
      // 配置值与 UI 路径共用同一校验实现（WR-03）：trim/形态/UNC/长度/探测
      // 全部经 validateConfiguredDirectory，杜绝手编 settings.json 的空白、
      // 相对路径、UNC 等畸形值绕过校验直达文件系统；纯空白值按 '' 语义
      // 处理（与 store 的空配置同义，静默走默认链）。
      final configured = configuredDirectory;
      if (configured != null && configured.trim().isNotEmpty) {
        final validation = await validateConfiguredDirectory(
          configured,
          writable: probe,
        );
        switch (validation) {
          case ConfiguredDirectoryValid(:final directory):
            return ErrorLogLocationResolved(_logFileUnder(directory));
          case ConfiguredDirectoryInvalid(:final reason, :final error):
            return await _resolveDefaultChain(
              probe,
              applicationSupportDirectory,
              executableDirectory,
              // 形态拒绝（相对路径/UNC 等）无原始异常 —— 以封闭原因枚举
              // 本身作为 contained 回退证据，保证 D-04 回退通知对畸形配置
              // 同样触发（WR-03）。
              configuredFailure: error ?? reason,
            );
        }
      }
      return await _resolveDefaultChain(
        probe,
        applicationSupportDirectory,
        executableDirectory,
      );
    } on IOException catch (error, stackTrace) {
      // FileSystemException extends IOException —— 单一子句覆盖（IN-05）。
      return ErrorLogLocationUnavailable(error, stackTrace);
    } on Exception catch (error, stackTrace) {
      return ErrorLogLocationUnavailable(error, stackTrace);
    }
  }

  /// 单层校验用户配置的日志目录 —— 「校验即证明 sink 可用」（SET-02/T-04-02-01）。
  ///
  /// 校验顺序（形态拒绝先行，探测收尾）：
  /// 1. trim 后为空 → [ConfiguredDirectoryFailure.notAbsolute]；
  /// 2. 含 null 字节/控制字符（codeUnits < 0x20 或 == 0x7F）→
  ///    [ConfiguredDirectoryFailure.invalidCharacters]；
  /// 3. 以 `\\` 或 `//` 开头的 UNC →
  ///    [ConfiguredDirectoryFailure.uncPathUnsupported]
  ///    （A3：v1 拒绝并文档化；两种分隔符形态都拦截 —— WR-04。置于
  ///    isAbsolute 判定**之前**：`//server/share` 在 Dart 3.13 Windows 下
  ///    isAbsolute=false，若先查绝对性会误报 notAbsolute 而非 UNC 原因）；
  /// 4. 非绝对路径 → [ConfiguredDirectoryFailure.notAbsolute]；
  /// 5. 长度超过 [maxConfiguredPathLength] →
  ///    [ConfiguredDirectoryFailure.pathTooLong]；
  /// 6. 复用链层的「create(recursive) + 临时文件探测」私有帮助函数做单层
  ///    准备与探测，任何 FileSystemException/IOException →
  ///    [ConfiguredDirectoryFailure.notWritable]（原始异常 contained 随行）。
  ///
  /// 绝不抛出：所有外部失败折叠为 typed Invalid；探测失败永不作为可用落点。
  static Future<ConfiguredDirectoryValidation> validateConfiguredDirectory(
    String configuredDirectory, {
    WritableDirectoryProbe? writable,
  }) async {
    final trimmed = configuredDirectory.trim();
    if (trimmed.isEmpty) {
      return const ConfiguredDirectoryInvalid(
        ConfiguredDirectoryFailure.notAbsolute,
      );
    }
    if (_containsControlCharacter(trimmed)) {
      return const ConfiguredDirectoryInvalid(
        ConfiguredDirectoryFailure.invalidCharacters,
      );
    }
    if (trimmed.startsWith('\\\\') || trimmed.startsWith('//')) {
      // A3：UNC 网络路径拒绝 —— 两种分隔符形态统一拦截（WR-04）：
      // 断网的共享会让诊断证据静默不可达，v1 拒收并文档化。
      return const ConfiguredDirectoryInvalid(
        ConfiguredDirectoryFailure.uncPathUnsupported,
      );
    }
    if (!Directory(trimmed).isAbsolute) {
      return const ConfiguredDirectoryInvalid(
        ConfiguredDirectoryFailure.notAbsolute,
      );
    }
    if (trimmed.length > maxConfiguredPathLength) {
      return const ConfiguredDirectoryInvalid(
        ConfiguredDirectoryFailure.pathTooLong,
      );
    }
    final directory = Directory(trimmed);
    final failure = await _prepareTier(
      directory,
      writable ?? _probeDirectoryWritable,
    );
    if (failure != null) {
      return ConfiguredDirectoryInvalid(
        ConfiguredDirectoryFailure.notWritable,
        error: failure.error,
      );
    }
    return ConfiguredDirectoryValid(directory);
  }

  /// 扫描 null 字节与控制字符（C0 全段 + DEL；\x00 空字节即含于 < 0x20）。
  static bool _containsControlCharacter(String value) {
    for (final unit in value.codeUnits) {
      if (unit < 0x20 || unit == 0x7F) {
        return true;
      }
    }
    return false;
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
    } on IOException catch (error, stackTrace) {
      // FileSystemException extends IOException —— 单一子句覆盖（IN-05）。
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
