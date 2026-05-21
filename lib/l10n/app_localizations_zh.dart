// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Simple Player';

  @override
  String get brandName => 'S I M P L E   P L A Y E R';

  @override
  String get emptyStateSubtitle => '沉浸视听体验';

  @override
  String get openFile => '打开文件';

  @override
  String get openFileTooltip => '打开文件 (O)';

  @override
  String get dragHintIdle => '拖拽视频至窗口上松开即可播放视频';

  @override
  String get dragHint => '拖拽视频至窗口松开即可播放';

  @override
  String get playModeLoopAll => '顺序播放';

  @override
  String get playModeLoopSingle => '单曲循环';

  @override
  String get playModeShuffle => '随机播放';

  @override
  String get shortcutPlayPause => '播放 / 暂停';

  @override
  String get shortcutSeek => '后退 / 前进 5 秒';

  @override
  String get shortcutVolume => '音量 +/- 5%';

  @override
  String get shortcutFullscreen => '全屏切换';

  @override
  String get shortcutExitFullscreen => '退出全屏';

  @override
  String get shortcutMute => '静音切换';

  @override
  String get shortcutNext => '下一首';

  @override
  String get shortcutPrevious => '上一首';

  @override
  String get shortcutOpenFile => '打开文件';

  @override
  String get shortcutSubtitle => '字幕开关';

  @override
  String get shortcutSubtitleDelay => '字幕延迟 +/- 500ms';

  @override
  String get shortcutHelp => '显示帮助';

  @override
  String get shortcutMediaKeys => '播放/暂停/上一首/下一首';

  @override
  String get settings => '设置';

  @override
  String get generalTab => '通用';

  @override
  String get language => '语言';

  @override
  String get theme => '主题';

  @override
  String get shortcutsTab => '快捷键';

  @override
  String get aboutTab => '关于';

  @override
  String get equalizer => '均衡器';

  @override
  String get audioTrack => '音轨';

  @override
  String get videoTab => '视频';

  @override
  String get noAudioTracks => '无可用音轨';

  @override
  String get videoProcessingUnavailable => '画面处理不可用';

  @override
  String audioTrackN(int index) {
    return '音轨 $index';
  }

  @override
  String get eqOff => '关闭';

  @override
  String get eqBassBoost => '低音增强';

  @override
  String get eqVocalBoost => '人声增强';

  @override
  String get eqRock => '摇滚';

  @override
  String get eqClassical => '古典';

  @override
  String get colorCorrection => '色彩校正';

  @override
  String get brightness => '亮度';

  @override
  String get contrast => '对比度';

  @override
  String get saturation => '饱和度';

  @override
  String get hue => '色调';

  @override
  String get rotation => '旋转';

  @override
  String get aspectRatio => '宽高比';

  @override
  String get deinterlace => '去隔行';

  @override
  String get resetAll => '重置全部';

  @override
  String get enableDeinterlace => '启用去隔行';

  @override
  String get softwareDecoderOnly => '仅软件解码器生效';

  @override
  String get videoProcessing => '画面';

  @override
  String get shortcutsHelpTitle => '快捷键';

  @override
  String get close => '关闭';

  @override
  String get previousTrack => '上一首';

  @override
  String get nextTrack => '下一首';

  @override
  String get playlist => '播放列表';

  @override
  String get fullscreen => '全屏 (F)';

  @override
  String get exitFullscreen => '退出全屏 (F)';

  @override
  String get openSubtitle => '打开字幕';

  @override
  String get play => '播放';

  @override
  String get pause => '暂停';

  @override
  String get stop => '停止';

  @override
  String get rewind10 => '快退 10 秒';

  @override
  String get forward30 => '快进 30 秒';

  @override
  String get pin => '置顶';

  @override
  String get unpin => '取消置顶';

  @override
  String get minimize => '最小化';

  @override
  String get maximize => '最大化';

  @override
  String get restore => '还原';

  @override
  String get playlistEmpty => '播放列表为空';

  @override
  String get noHistory => '暂无播放记录';

  @override
  String get playlistTab => '播放列表';

  @override
  String get historyTab => '播放历史';

  @override
  String get clear => '清空';

  @override
  String get playAction => '播放';

  @override
  String get copyPath => '复制路径';

  @override
  String get properties => '属性';

  @override
  String get remove => '移除';

  @override
  String get pathCopied => '路径已复制';

  @override
  String breakpointAt(String time) {
    return '断点 $time';
  }

  @override
  String lastPlayedAt(String time) {
    return '上次播放到 $time';
  }

  @override
  String get justNow => '刚刚';

  @override
  String minutesAgo(int minutes) {
    return '$minutes分钟前';
  }

  @override
  String hoursAgo(int hours) {
    return '$hours小时前';
  }

  @override
  String daysAgo(int days) {
    return '$days天前';
  }

  @override
  String get propertiesDialog => '属性';

  @override
  String get fileSection => '文件';

  @override
  String get filePath => '路径';

  @override
  String get fileName => '文件名';

  @override
  String get videoSection => '视频';

  @override
  String get resolution => '分辨率';

  @override
  String get codec => '编码';

  @override
  String get pixelAspectRatio => '像素宽高比';

  @override
  String get aspectRatioLabel => '宽高比';

  @override
  String get durationSection => '时长';

  @override
  String get totalDuration => '总时长';

  @override
  String get audioSection => '音频';

  @override
  String get trackCount => '轨道数';

  @override
  String trackN(int index) {
    return '轨道 $index';
  }

  @override
  String get subtitleSection => '字幕';

  @override
  String get copied => '已复制';

  @override
  String get doubleClickToCopy => '双击复制';

  @override
  String get unknown => '未知';

  @override
  String get reopen => '重新打开';

  @override
  String get selectOtherFile => '选择其他文件';

  @override
  String get retry => '重试';

  @override
  String get unmute => '取消静音';

  @override
  String get mute => '静音';

  @override
  String get volume => '音量';

  @override
  String volumePercent(String percent) {
    return '音量 $percent%';
  }

  @override
  String get aspectRatioOriginal => '原始';

  @override
  String get aspectRatioStretch => '拉伸';

  @override
  String get aspectRatioCropFill => '裁剪填充';

  @override
  String get aspectRatioFree => '自由';

  @override
  String get progressBar => '播放进度';

  @override
  String get speedDecrease => '减速';

  @override
  String get speedReset => '倍速 (双击重置)';

  @override
  String get speedIncrease => '加速';

  @override
  String get folderTab => '文件夹';

  @override
  String get resumeAction => '继续播放';

  @override
  String get openFileLocation => '打开文件所在目录';

  @override
  String get clearHistory => '清空历史';

  @override
  String get scanFolder => '扫描文件夹';

  @override
  String get noVideosInFolder => '文件夹中无视频';

  @override
  String get themeMidnight => '午夜';

  @override
  String get themeOcean => '海洋';

  @override
  String get themeForest => '森林';

  @override
  String get version => '版本';

  @override
  String get techStack => '技术栈';

  @override
  String get licenses => '开源许可';

  @override
  String get copyright => '基于 Flutter + fvp (MDK/FFmpeg) 构建';

  @override
  String get resetShortcuts => '恢复默认';

  @override
  String get pressKeyToBind => '请按下新按键...';

  @override
  String get shortcutConflict => '按键已被占用';

  @override
  String get shortcutAspectCycle => '切换宽高比';

  @override
  String get currentTheme => '当前主题';

  @override
  String get ok => '确定';

  @override
  String get cancel => '取消';

  @override
  String get apply => '应用';
}
