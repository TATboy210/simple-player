// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Simple Player';

  @override
  String get windowInitializationFailed => 'ウィンドウの初期化に失敗しました';

  @override
  String get brandName => 'S I M P L E   P L A Y E R';

  @override
  String get emptyStateSubtitle => '没入型の視聴体験';

  @override
  String get openFile => 'ファイルを開く';

  @override
  String get openFileTooltip => 'ファイルを開く (O)';

  @override
  String get dragHint => '動画をウィンドウにドラッグ＆ドロップで再生できます';

  @override
  String get playModeLoopAll => '順次再生';

  @override
  String get playModeLoopSingle => '1曲リピート';

  @override
  String get playModeShuffle => 'シャッフル再生';

  @override
  String get shortcutPlayPause => '再生 / 一時停止';

  @override
  String get shortcutSeek => '5秒 戻る / 進む';

  @override
  String get shortcutVolume => '音量 +/- 5%';

  @override
  String get shortcutFullscreen => '全画面切り替え';

  @override
  String get shortcutExitFullscreen => '全画面を終了';

  @override
  String get shortcutMute => 'ミュート切り替え';

  @override
  String get shortcutNext => '次の曲';

  @override
  String get shortcutPrevious => '前の曲';

  @override
  String get shortcutOpenFile => 'ファイルを開く';

  @override
  String get shortcutSubtitle => '字幕の切り替え';

  @override
  String get shortcutPlaylist => '再生リストの切り替え';

  @override
  String get shortcutSubtitleDelay => '字幕遅延 +/- 500ms';

  @override
  String get shortcutHelp => 'ヘルプを表示';

  @override
  String get shortcutMediaKeys => '再生/一時停止';

  @override
  String get settings => '設定';

  @override
  String get audioTab => 'オーディオ';

  @override
  String get specialThanks => 'スペシャルサンクス';

  @override
  String get thanksPending => 'リストは準備中です';

  @override
  String get lgplNotice =>
      'mpv と FFmpeg は LGPL-2.1-or-later で動的リンクされています · 詳細は同梱の NOTICE ファイルを参照してください';

  @override
  String get generalTab => '一般';

  @override
  String get language => '言語';

  @override
  String get theme => 'テーマ';

  @override
  String get shortcutsTab => 'ショートカット';

  @override
  String get aboutTab => '情報';

  @override
  String get equalizer => 'イコライザー';

  @override
  String get audioTrack => '音声トラック';

  @override
  String get videoTab => 'ビデオ';

  @override
  String get noAudioTracks => '利用可能な音声トラックがありません';

  @override
  String get videoProcessingUnavailable => '画面処理を利用できません';

  @override
  String audioTrackN(int index) {
    return '音声トラック $index';
  }

  @override
  String get eqOff => 'オフ';

  @override
  String get eqBassBoost => '低音ブースト';

  @override
  String get eqVocalBoost => 'ボーカルブースト';

  @override
  String get eqRock => 'ロック';

  @override
  String get eqClassical => 'クラシック';

  @override
  String get colorCorrection => 'カラーコレクション';

  @override
  String get brightness => '明るさ';

  @override
  String get contrast => 'コントラスト';

  @override
  String get saturation => '彩度';

  @override
  String get hue => '色合い';

  @override
  String get rotation => '回転';

  @override
  String get aspectRatio => 'アスペクト比';

  @override
  String get deinterlace => 'インターレース解除';

  @override
  String get resetAll => 'すべてリセット';

  @override
  String get enableDeinterlace => 'インターレース解除を有効化';

  @override
  String get softwareDecoderOnly => 'ソフトウェアデコーダーでのみ有効';

  @override
  String get videoProcessing => '映像';

  @override
  String get shortcutsHelpTitle => 'ショートカット';

  @override
  String get close => '閉じる';

  @override
  String get previousTrack => '前へ';

  @override
  String get nextTrack => '次へ';

  @override
  String get playlist => '再生リスト';

  @override
  String get fullscreen => '全画面 (F)';

  @override
  String get exitFullscreen => '全画面を終了 (F)';

  @override
  String get openSubtitle => '字幕を開く';

  @override
  String get play => '再生';

  @override
  String get resumePlayback => '続きから再生';

  @override
  String get pause => '一時停止';

  @override
  String get stop => '停止';

  @override
  String get rewind10 => '10秒戻る';

  @override
  String get forward30 => '30秒進む';

  @override
  String get pin => '常に最前面';

  @override
  String get unpin => '最前面を解除';

  @override
  String get minimize => '最小化';

  @override
  String get maximize => '最大化';

  @override
  String get restore => '元に戻す';

  @override
  String get playlistEmpty => '再生リストは空です';

  @override
  String get resumeRememberPosition => '再生位置を記憶する';

  @override
  String get audioDelay => '音声の遅延';

  @override
  String get subtitleDelay => '字幕の遅延';

  @override
  String get sortBy => '並べ替え';

  @override
  String get sortByAddedOrder => '追加順';

  @override
  String get sortByName => '名前順';

  @override
  String get sortByLastPlayed => '最終再生順';

  @override
  String get sortByDuration => '長さ順';

  @override
  String get sortAscending => '昇順';

  @override
  String get sortDescending => '降順';

  @override
  String get noHistory => '再生履歴はありません';

  @override
  String get playlistTab => '再生リスト';

  @override
  String get historyTab => '再生履歴';

  @override
  String get clear => 'クリア';

  @override
  String get playAction => '再生';

  @override
  String get copyPath => 'パスをコピー';

  @override
  String get properties => 'プロパティ';

  @override
  String get remove => '削除';

  @override
  String get pathCopied => 'パスをコピーしました';

  @override
  String breakpointAt(String time) {
    return '再開ポイント $time';
  }

  @override
  String lastPlayedAt(String time) {
    return '前回の再生: $time';
  }

  @override
  String get justNow => 'たった今';

  @override
  String minutesAgo(int minutes) {
    return '$minutes分前';
  }

  @override
  String hoursAgo(int hours) {
    return '$hours時間前';
  }

  @override
  String daysAgo(int days) {
    return '$days日前';
  }

  @override
  String get propertiesDialog => 'プロパティ';

  @override
  String get fileSection => 'ファイル';

  @override
  String get filePath => 'パス';

  @override
  String get fileName => 'ファイル名';

  @override
  String get videoSection => 'ビデオ';

  @override
  String get resolution => '解像度';

  @override
  String get codec => 'コーデック';

  @override
  String get pixelAspectRatio => 'ピクセルアスペクト比';

  @override
  String get aspectRatioLabel => 'アスペクト比';

  @override
  String get durationSection => '長さ';

  @override
  String get totalDuration => '合計時間';

  @override
  String get audioSection => 'オーディオ';

  @override
  String get trackCount => 'トラック数';

  @override
  String trackN(int index) {
    return 'トラック $index';
  }

  @override
  String get subtitleSection => '字幕';

  @override
  String get copied => 'コピーしました';

  @override
  String get doubleClickToCopy => 'ダブルクリックでコピー';

  @override
  String get unknown => '不明';

  @override
  String get reopen => '再度開く';

  @override
  String get selectOtherFile => '他のファイルを選択';

  @override
  String get retry => '再試行';

  @override
  String get unmute => 'ミュート解除';

  @override
  String get mute => 'ミュート';

  @override
  String get volume => '音量';

  @override
  String volumePercent(String percent) {
    return '音量 $percent%';
  }

  @override
  String get aspectRatioOriginal => 'オリジナル';

  @override
  String get aspectRatioStretch => '引き伸ばし';

  @override
  String get aspectRatioCropFill => '切り抜き填充';

  @override
  String get aspectRatioFree => '自由';

  @override
  String get progressBar => '再生の進行状況';

  @override
  String get speedDecrease => '減速';

  @override
  String get speedReset => '再生速度 (ダブルクリックでリセット)';

  @override
  String get speedIncrease => '加速';

  @override
  String get folderTab => 'フォルダー';

  @override
  String get resumeAction => '続きから再生';

  @override
  String get openFileLocation => 'ファイルの場所を開く';

  @override
  String get clearHistory => '履歴をクリア';

  @override
  String get scanFolder => 'フォルダーをスキャン';

  @override
  String get noVideosInFolder => 'フォルダーに動画がありません';

  @override
  String get themeMidnight => 'ミッドナイト';

  @override
  String get themeOcean => 'オーシャン';

  @override
  String get themeForest => 'フォレスト';

  @override
  String get version => 'バージョン';

  @override
  String get techStack => '技術スタック';

  @override
  String get licenses => 'オープンソースライセンス';

  @override
  String get copyright => 'Flutter + media_kit (libmpv) ベース';

  @override
  String get resetShortcuts => 'デフォルトに戻す';

  @override
  String get pressKeyToBind => '新しいキーを押してください...';

  @override
  String get shortcutConflict => 'このキーは使用中です';

  @override
  String get currentTheme => '現在のテーマ';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'キャンセル';

  @override
  String get apply => '適用';

  @override
  String get playerLoadError => 'プレーヤーモジュールの読み込みに失敗しました';

  @override
  String get playerInitFailed => 'プレーヤーの初期化に失敗しました';

  @override
  String get performanceTab => 'パフォーマンス';

  @override
  String get d3d11Rendering => 'D3D11 レンダリング';

  @override
  String get d3d11Sync => 'D3D11 CPU 同期';

  @override
  String get d3d11SyncDesc =>
      'フレームごとに CPU と GPU を同期します。オフにすると遅延が減りますが、画面のちらつきが生じる場合があります。';

  @override
  String get decoderSettings => 'デコーダー';

  @override
  String get hardwareDecoding => 'ハードウェアデコード';

  @override
  String get hardwareDecodingDesc => 'GPU で動画をデコードします。画面に異常がある場合はオフにしてください。';

  @override
  String get performanceHint => '変更は次のファイルを開くときに適用されます。';

  @override
  String get resetToDefaults => 'デフォルトに戻す';

  @override
  String resetConfirmTitle(String tabName) {
    return '$tabName設定をリセットしますか？';
  }

  @override
  String get resetConfirmMessage => '以下の設定がデフォルトに戻されます：';

  @override
  String get confirmReset => 'リセットを確認';

  @override
  String get exportSettings => 'エクスポート';

  @override
  String get importSettings => 'インポート';

  @override
  String get importConfirmTitle => '設定をインポートしますか？';

  @override
  String get importConfirmMessage => '以下の設定が上書きされます：';

  @override
  String get importConfirmCategories => '再生、映像効果、字幕、ウィンドウ、ショートカット、テーマ、言語';

  @override
  String get importSuccess => '設定をインポートしました';

  @override
  String importError(String error) {
    return 'インポート失敗：$error';
  }

  @override
  String get exportError => 'エクスポート失敗';

  @override
  String get exportSuccess => '設定をエクスポートしました';

  @override
  String importParseError(String error) {
    return '無効な JSON：$error';
  }

  @override
  String importFileReadError(String error) {
    return 'ファイルを読み取れません：$error';
  }

  @override
  String get openingMedia => 'メディアを開いています';

  @override
  String get bufferingMedia => 'メディアをバッファリングしています';

  @override
  String get errorFilePathEmpty => 'ファイルパスが空です';

  @override
  String get errorFileNotFound => 'ファイルが存在しません';

  @override
  String get errorFilepathTraversal => 'ファイルパスが無効です';

  @override
  String get errorCodecUnsupportedFormat => 'サポートされていないメディア形式';

  @override
  String get errorCodecDecodeFailed => 'メディアをデコードできません';

  @override
  String get errorCodecCodecUnsupported => 'サポートされていないコーデック';

  @override
  String get errorPlaybackPlayFailed => '再生に失敗しました';

  @override
  String get errorPlaybackSeekFailed => 'シークに失敗しました';

  @override
  String get errorPlaybackTextureFailed => '映像のレンダリングに失敗しました';

  @override
  String get errorPlaybackOpenTimeout => 'オープンがタイムアウトしました';

  @override
  String get errorNetworkTimeout => 'ネットワークがタイムアウトしました';

  @override
  String get errorNetworkConnectionLost => '接続が切断されました';

  @override
  String get errorUnknown => '不明なエラーが発生しました';

  @override
  String errorCardBadgeLabel(int count) {
    return 'エラー $count件';
  }

  @override
  String get errorCardClose => '閉じる';

  @override
  String get errorCardCopyTooltip => '診断情報をコピー';

  @override
  String get errorCardCopied => 'コピーしました';

  @override
  String get errorCardCopyFailed => 'コピーに失敗しました';

  @override
  String get errorCardOpenLogTooltip => 'ログの場所を開く';

  @override
  String get errorCardLogOpened => 'ログの場所を開きました';

  @override
  String get errorCardOpenLogFailed => 'ログの場所を開けませんでした';

  @override
  String get errorCardSectionLocation => '位置';

  @override
  String get errorCardSectionSource => 'ソース行';

  @override
  String get errorCardSectionStack => '呼び出しスタック';

  @override
  String get errorCardSectionLogPath => 'ログファイル';

  @override
  String errorCardSectionRepeats(int count) {
    return '$count回繰り返し';
  }

  @override
  String get errorCardLogUnavailable => 'ログファイルを利用できません';

  @override
  String get errorCardLocationUnavailable => '位置情報を利用できません';

  @override
  String get errorCardCycleTooltip => 'エラーを切り替えて表示';

  @override
  String get errorCardToggleLabel => 'エラーカード';

  @override
  String get languageLabel => '言語';

  @override
  String get languageSystem => 'システムに従う';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChinese => '中文';

  @override
  String get batchDelete => '一括削除';

  @override
  String batchSelectedCount(int count) {
    return '$count件選択中';
  }

  @override
  String get selectAll => 'すべて選択';

  @override
  String get batchDeleteConfirmTitle => '選択した動画項目を削除';

  @override
  String batchDeleteConfirmBody(int count) {
    return '再生リストから $count 件の動画項目を削除します。この操作は再生リストにのみ影響し、ローカルディスク上のファイルは削除されません。';
  }

  @override
  String get batchDeleteConfirmAction => '削除を確定';
}
