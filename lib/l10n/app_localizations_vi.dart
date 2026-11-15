// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get moveToCenter => 'Chuyển về giữa';

  @override
  String get appTitle => 'Simple Player';

  @override
  String get windowInitializationFailed => 'Khởi tạo cửa sổ thất bại';

  @override
  String get brandName => 'S I M P L E   P L A Y E R';

  @override
  String get emptyStateSubtitle => 'Trải nghiệm nghe nhìn đắm chìm';

  @override
  String get openFile => 'Mở tệp';

  @override
  String get openFileTooltip => 'Mở tệp (O)';

  @override
  String get dragHint => 'Thả video vào đây để phát';

  @override
  String get playModeLoopAll => 'Phát tuần tự';

  @override
  String get playModeLoopSingle => 'Lặp một video';

  @override
  String get playModeShuffle => 'Phát ngẫu nhiên';

  @override
  String get shortcutPlayPause => 'Phát / Tạm dừng';

  @override
  String get shortcutSeek => 'Tua lùi/tới 5 giây';

  @override
  String get shortcutVolume => 'Âm lượng +/- 5%';

  @override
  String get shortcutFullscreen => 'Bật/tắt toàn màn hình';

  @override
  String get shortcutExitFullscreen => 'Thoát toàn màn hình';

  @override
  String get shortcutMute => 'Bật/tắt im lặng';

  @override
  String get shortcutNext => 'Tiếp theo';

  @override
  String get shortcutPrevious => 'Trước đó';

  @override
  String get shortcutOpenFile => 'Mở tệp';

  @override
  String get shortcutSubtitle => 'Bật/tắt phụ đề';

  @override
  String get shortcutPlaylist => 'Bật/tắt danh sách phát';

  @override
  String get shortcutSubtitleDelay => 'Độ trễ phụ đề +/- 500ms';

  @override
  String get shortcutHelp => 'Hiện trợ giúp';

  @override
  String get shortcutMediaKeys => 'Phát/Tạm dừng';

  @override
  String get settings => 'Cài đặt';

  @override
  String get back => 'Quay lại';

  @override
  String get settingsSummaryGeneral => 'Ngôn ngữ · Thẻ lỗi · Phát tiếp';

  @override
  String get settingsSummaryVideo =>
      'Độ sáng · Tương phản · Xoay · Tỷ lệ khung hình';

  @override
  String get settingsSummaryAudio => 'Độ trễ âm thanh · Độ trễ phụ đề';

  @override
  String get settingsSummaryAbout => 'Thành phần · Lời cảm ơn · Công nghệ';

  @override
  String get audioTab => 'Âm thanh';

  @override
  String get specialThanks => 'Cảm ơn đặc biệt';

  @override
  String get thanksPending => 'Danh sách đang được chuẩn bị — hãy đón xem';

  @override
  String get lgplNotice =>
      'mpv và FFmpeg được liên kết động theo LGPL-2.1-or-later — chi tiết tuân thủ nằm trong tệp NOTICE đính kèm';

  @override
  String get generalTab => 'Chung';

  @override
  String get language => 'Ngôn ngữ';

  @override
  String get theme => 'Giao diện';

  @override
  String get shortcutsTab => 'Phím tắt';

  @override
  String get aboutTab => 'Giới thiệu';

  @override
  String get equalizer => 'Bộ chỉnh âm';

  @override
  String get audioTrack => 'Track âm thanh';

  @override
  String get videoTab => 'Video';

  @override
  String get noAudioTracks => 'Không có track âm thanh nào';

  @override
  String get videoProcessingUnavailable => 'Xử lý video không khả dụng';

  @override
  String audioTrackN(int index) {
    return 'Track $index';
  }

  @override
  String get eqOff => 'Tắt';

  @override
  String get eqBassBoost => 'Tăng âm trầm';

  @override
  String get eqVocalBoost => 'Tăng giọng người hát';

  @override
  String get eqRock => 'Rock';

  @override
  String get eqClassical => 'Cổ điển';

  @override
  String get colorCorrection => 'Chỉnh màu';

  @override
  String get brightness => 'Độ sáng';

  @override
  String get contrast => 'Tương phản';

  @override
  String get saturation => 'Độ bão hòa';

  @override
  String get hue => 'Sắc độ';

  @override
  String get rotation => 'Xoay';

  @override
  String get aspectRatio => 'Tỷ lệ khung hình';

  @override
  String get deinterlace => 'Khử xen kẽ';

  @override
  String get resetAll => 'Đặt lại tất cả';

  @override
  String get enableDeinterlace => 'Bật khử xen kẽ';

  @override
  String get softwareDecoderOnly => 'Chỉ với bộ giải mã phần mềm';

  @override
  String get videoProcessing => 'Video';

  @override
  String get shortcutsHelpTitle => 'Phím tắt bàn phím';

  @override
  String get close => 'Đóng';

  @override
  String get previousTrack => 'Trước';

  @override
  String get nextTrack => 'Tiếp';

  @override
  String get playlist => 'Danh sách phát';

  @override
  String get fullscreen => 'Toàn màn hình (F)';

  @override
  String get exitFullscreen => 'Thoát toàn màn hình (F)';

  @override
  String get openSubtitle => 'Mở phụ đề';

  @override
  String get play => 'Phát';

  @override
  String get resumePlayback => 'Phát tiếp từ điểm dừng';

  @override
  String get pause => 'Tạm dừng';

  @override
  String get stop => 'Dừng';

  @override
  String get rewind10 => 'Tua lùi 10 giây';

  @override
  String get forward30 => 'Tua tới 30 giây';

  @override
  String get pin => 'Luôn hiển thị trên cùng';

  @override
  String get unpin => 'Bỏ ghim trên cùng';

  @override
  String get minimize => 'Thu nhỏ';

  @override
  String get maximize => 'Phóng to';

  @override
  String get restore => 'Khôi phục';

  @override
  String get playlistEmpty => 'Danh sách phát trống';

  @override
  String get resumeRememberPosition => 'Ghi nhớ vị trí phát';

  @override
  String get audioDelay => 'Độ trễ âm thanh';

  @override
  String get subtitleDelay => 'Độ trễ phụ đề';

  @override
  String get sortBy => 'Sắp xếp';

  @override
  String get sortByAddedOrder => 'Theo thứ tự thêm';

  @override
  String get sortByName => 'Theo tên';

  @override
  String get sortByLastPlayed => 'Theo lần phát cuối';

  @override
  String get sortByDuration => 'Theo thời lượng';

  @override
  String get sortAscending => 'Tăng dần';

  @override
  String get sortDescending => 'Giảm dần';

  @override
  String get noHistory => 'Không có lịch sử phát';

  @override
  String get playlistTab => 'Danh sách phát';

  @override
  String get historyTab => 'Lịch sử';

  @override
  String get clear => 'Xóa hết';

  @override
  String get playAction => 'Phát';

  @override
  String get copyPath => 'Sao chép đường dẫn';

  @override
  String get properties => 'Thuộc tính';

  @override
  String get remove => 'Gỡ bỏ';

  @override
  String get pathCopied => 'Đã sao chép đường dẫn';

  @override
  String breakpointAt(String time) {
    return 'Điểm dừng $time';
  }

  @override
  String lastPlayedAt(String time) {
    return 'Đã phát đến $time';
  }

  @override
  String get justNow => 'Vừa xong';

  @override
  String minutesAgo(int minutes) {
    return '$minutes phút trước';
  }

  @override
  String hoursAgo(int hours) {
    return '$hours giờ trước';
  }

  @override
  String daysAgo(int days) {
    return '$days ngày trước';
  }

  @override
  String get propertiesDialog => 'Thuộc tính';

  @override
  String get fileSection => 'Tệp';

  @override
  String get filePath => 'Đường dẫn';

  @override
  String get fileName => 'Tên tệp';

  @override
  String get videoSection => 'Video';

  @override
  String get resolution => 'Độ phân giải';

  @override
  String get codec => 'Codec';

  @override
  String get pixelAspectRatio => 'Tỷ lệ điểm ảnh';

  @override
  String get aspectRatioLabel => 'Tỷ lệ khung hình';

  @override
  String get durationSection => 'Thời lượng';

  @override
  String get totalDuration => 'Tổng thời lượng';

  @override
  String get audioSection => 'Âm thanh';

  @override
  String get trackCount => 'Số track';

  @override
  String trackN(int index) {
    return 'Track $index';
  }

  @override
  String get subtitleSection => 'Phụ đề';

  @override
  String get copied => 'Đã sao chép';

  @override
  String get doubleClickToCopy => 'Nhấp đúp để sao chép';

  @override
  String get unknown => 'Không rõ';

  @override
  String get reopen => 'Mở lại';

  @override
  String get selectOtherFile => 'Chọn tệp khác';

  @override
  String get retry => 'Thử lại';

  @override
  String get unmute => 'Bỏ im lặng';

  @override
  String get mute => 'Im lặng';

  @override
  String get volume => 'Âm lượng';

  @override
  String volumePercent(String percent) {
    return 'Âm lượng $percent%';
  }

  @override
  String get aspectRatioOriginal => 'Gốc';

  @override
  String get aspectRatioStretch => 'Kéo giãn';

  @override
  String get aspectRatioCropFill => 'Cắt để lấp đầy';

  @override
  String get aspectRatioFree => 'Tự do';

  @override
  String get progressBar => 'Tiến trình phát';

  @override
  String get speedDecrease => 'Giảm tốc độ';

  @override
  String get speedReset => 'Tốc độ (nhấp đúp để đặt lại)';

  @override
  String get speedIncrease => 'Tăng tốc độ';

  @override
  String get folderTab => 'Thư mục';

  @override
  String get resumeAction => 'Phát tiếp';

  @override
  String get openFileLocation => 'Mở vị trí tệp';

  @override
  String get clearHistory => 'Xóa lịch sử';

  @override
  String get scanFolder => 'Quét thư mục';

  @override
  String get noVideosInFolder => 'Không có video trong thư mục';

  @override
  String get themeMidnight => 'Nửa đêm';

  @override
  String get themeOcean => 'Đại dương';

  @override
  String get themeForest => 'Rừng';

  @override
  String get version => 'Phiên bản';

  @override
  String get techStack => 'Công nghệ';

  @override
  String get licenses => 'Giấy phép';

  @override
  String get copyright => 'Xây dựng bằng Flutter + mpv_kit (libmpv)';

  @override
  String get resetShortcuts => 'Đặt lại mặc định';

  @override
  String get pressKeyToBind => 'Nhấn một phím...';

  @override
  String get shortcutConflict => 'Phím đã được gán';

  @override
  String get currentTheme => 'Giao diện';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Hủy';

  @override
  String get apply => 'Áp dụng';

  @override
  String get playerLoadError => 'Không tải được mô-đun trình phát';

  @override
  String get playerInitFailed => 'Khởi tạo trình phát thất bại';

  @override
  String get performanceTab => 'Hiệu suất';

  @override
  String get d3d11Rendering => 'Kết xuất D3D11';

  @override
  String get d3d11Sync => 'Đồng bộ CPU D3D11';

  @override
  String get d3d11SyncDesc =>
      'Đồng bộ CPU và GPU theo từng khung hình. Tắt đi để giảm độ trễ; có thể gây xé hình.';

  @override
  String get decoderSettings => 'Bộ giải mã';

  @override
  String get hardwareDecoding => 'Giải mã bằng phần cứng';

  @override
  String get hardwareDecodingDesc =>
      'Dùng GPU để giải mã video. Tắt đi nếu gặp lỗi hình ảnh.';

  @override
  String get performanceHint => 'Thay đổi có hiệu lực khi mở tệp tiếp theo.';

  @override
  String get resetToDefaults => 'Khôi phục mặc định';

  @override
  String resetConfirmTitle(String tabName) {
    return 'Đặt lại cài đặt của $tabName?';
  }

  @override
  String get resetConfirmMessage =>
      'Các cài đặt sau sẽ được khôi phục về mặc định:';

  @override
  String get confirmReset => 'Đặt lại';

  @override
  String get exportSettings => 'Xuất';

  @override
  String get importSettings => 'Nhập';

  @override
  String get importConfirmTitle => 'Nhập cài đặt?';

  @override
  String get importConfirmMessage => 'Các cài đặt sau sẽ bị ghi đè:';

  @override
  String get importConfirmCategories =>
      'Phát, Video, Phụ đề, Cửa sổ, Phím tắt, Giao diện, Ngôn ngữ';

  @override
  String get importSuccess => 'Đã nhập cài đặt';

  @override
  String importError(String error) {
    return 'Nhập thất bại: $error';
  }

  @override
  String get exportError => 'Xuất thất bại';

  @override
  String get exportSuccess => 'Đã xuất cài đặt';

  @override
  String importParseError(String error) {
    return 'JSON không hợp lệ: $error';
  }

  @override
  String importFileReadError(String error) {
    return 'Không thể đọc tệp: $error';
  }

  @override
  String get openingMedia => 'Đang mở nội dung';

  @override
  String get bufferingMedia => 'Đang đệm nội dung';

  @override
  String get errorFilePathEmpty => 'Đường dẫn tệp trống';

  @override
  String get errorFileNotFound => 'Không tìm thấy tệp';

  @override
  String get errorFilepathTraversal => 'Đường dẫn tệp không hợp lệ';

  @override
  String get errorCodecUnsupportedFormat =>
      'Định dạng đa phương tiện không được hỗ trợ';

  @override
  String get errorCodecDecodeFailed => 'Không giải mã được nội dung';

  @override
  String get errorCodecCodecUnsupported => 'Codec không được hỗ trợ';

  @override
  String get errorPlaybackPlayFailed => 'Phát thất bại';

  @override
  String get errorPlaybackSeekFailed => 'Tua thất bại';

  @override
  String get errorPlaybackTextureFailed => 'Kết xuất video thất bại';

  @override
  String get errorPlaybackOpenTimeout => 'Mở nội dung bị quá thời gian chờ';

  @override
  String get errorNetworkTimeout => 'Mạng quá thời gian chờ';

  @override
  String get errorNetworkConnectionLost => 'Mất kết nối';

  @override
  String get errorUnknown => 'Đã xảy ra lỗi không mong muốn';

  @override
  String errorCardBadgeLabel(int count) {
    return '$count lỗi';
  }

  @override
  String get errorCardClose => 'Đóng';

  @override
  String get errorCardCopyTooltip => 'Sao chép thông tin chẩn đoán';

  @override
  String get errorCardCopied => 'Đã sao chép';

  @override
  String get errorCardCopiedPathInLog =>
      'Đã sao chép — đường dẫn đầy đủ trong error.log';

  @override
  String get errorCardCopyFailed => 'Sao chép thất bại';

  @override
  String get errorCardOpenLogTooltip => 'Mở vị trí nhật ký';

  @override
  String get errorCardLogOpened => 'Đã mở nhật ký';

  @override
  String get errorCardOpenLogFailed => 'Mở nhật ký thất bại';

  @override
  String get errorCardSectionLocation => 'Vị trí';

  @override
  String get errorCardSectionSource => 'Dòng mã nguồn';

  @override
  String get errorCardSectionStack => 'Vết ngăn xếp';

  @override
  String get errorCardSectionLogPath => 'Tệp nhật ký';

  @override
  String errorCardSectionRepeats(int count) {
    return 'Lặp lại: $count';
  }

  @override
  String get errorCardLogUnavailable => 'Nhật ký không khả dụng';

  @override
  String get errorCardLocationUnavailable => 'Vị trí không khả dụng';

  @override
  String get errorCardCycleTooltip => 'Chuyển giữa các lỗi';

  @override
  String get errorCardToggleLabel => 'Thẻ lỗi';

  @override
  String get languageLabel => 'Ngôn ngữ';

  @override
  String get languageSystem => 'Theo hệ thống';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChinese => '中文';

  @override
  String get batchDelete => 'Xóa hàng loạt';

  @override
  String batchSelectedCount(int count) {
    return 'Đã chọn $count';
  }

  @override
  String get selectAll => 'Chọn tất cả';

  @override
  String get batchDeleteConfirmTitle => 'Xóa video đã chọn';

  @override
  String batchDeleteConfirmBody(int count) {
    return '$count mục video sẽ bị gỡ khỏi danh sách phát. Thao tác này chỉ ảnh hưởng đến danh sách phát và sẽ không xóa bất kỳ tệp nào trên ổ đĩa của bạn.';
  }

  @override
  String get batchDeleteConfirmAction => 'Xác nhận xóa';

  @override
  String get playlistEntriesGone => 'Các mục không còn trong danh sách phát';
}
