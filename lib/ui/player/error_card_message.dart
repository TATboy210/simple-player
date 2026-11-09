import '../../kernel/diagnostics/error_report.dart';
import '../../l10n/app_localizations.dart';

/// 错误卡片 message 解析（l10nKey → AppLocalizations 查找）.
///
/// 未知键 fallback 到原始 message（MIG-01 迁移基线 —— 与旧横幅（legacy
/// banner，03-04 已删除）的 13 key 枚举逐项一致，D-09 明确**不**迁移其动作
/// 按钮 switch）。
///
/// ErrorReport 不携带 PlayerError 对象，只携带 intake 快照的
/// `playerErrorCode`（`file:fileNotFound` 形态）——先还原为与旧横幅同构的
/// `error.file.fileNotFound` 键，再走完全一致的 switch，保证旧横幅删除后
/// 零解析能力缺口。非 player 来源（无 code）直接用 raw
/// message（全局钩子错误的 message 本身可读）。
String resolveErrorCardMessage(AppLocalizations l10n, ErrorReport report) {
  final code = report.playerErrorCode;
  if (code == null) return report.message;
  // 'file:fileNotFound' → 'error.file.fileNotFound'（unknown → error.unknown）。
  final l10nKey = 'error.${code.replaceFirst(':', '.')}';
  return switch (l10nKey) {
    'error.file.pathEmpty' => l10n.errorFilePathEmpty,
    'error.file.fileNotFound' => l10n.errorFileNotFound,
    'error.file.pathTraversal' => l10n.errorFilepathTraversal,
    'error.codec.unsupportedFormat' => l10n.errorCodecUnsupportedFormat,
    'error.codec.decodeFailed' => l10n.errorCodecDecodeFailed,
    'error.codec.codecUnsupported' => l10n.errorCodecCodecUnsupported,
    'error.playback.playFailed' => l10n.errorPlaybackPlayFailed,
    'error.playback.seekFailed' => l10n.errorPlaybackSeekFailed,
    'error.playback.textureFailed' => l10n.errorPlaybackTextureFailed,
    'error.playback.openTimeout' => l10n.errorPlaybackOpenTimeout,
    'error.network.timeout' => l10n.errorNetworkTimeout,
    'error.network.connectionLost' => l10n.errorNetworkConnectionLost,
    'error.unknown' => l10n.errorUnknown,
    _ => report.message, // fallback: 未知 l10nKey 用原始消息
  };
}
