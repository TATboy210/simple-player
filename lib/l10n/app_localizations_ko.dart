// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'Simple Player';

  @override
  String get windowInitializationFailed => '창 초기화 실패';

  @override
  String get brandName => 'S I M P L E   P L A Y E R';

  @override
  String get emptyStateSubtitle => '몰입형 시청 경험';

  @override
  String get openFile => '파일 열기';

  @override
  String get openFileTooltip => '파일 열기 (O)';

  @override
  String get dragHint => '동영상을 창으로 끌어다 놓으면 재생됩니다';

  @override
  String get playModeLoopAll => '순차 재생';

  @override
  String get playModeLoopSingle => '한 곡 반복';

  @override
  String get playModeShuffle => '랜덤 재생';

  @override
  String get shortcutPlayPause => '재생 / 일시정지';

  @override
  String get shortcutSeek => '5초 뒤로 / 앞으로';

  @override
  String get shortcutVolume => '음량 +/- 5%';

  @override
  String get shortcutFullscreen => '전체 화면 전환';

  @override
  String get shortcutExitFullscreen => '전체 화면 종료';

  @override
  String get shortcutMute => '음소거 전환';

  @override
  String get shortcutNext => '다음 곡';

  @override
  String get shortcutPrevious => '이전 곡';

  @override
  String get shortcutOpenFile => '파일 열기';

  @override
  String get shortcutSubtitle => '자막 켜기/끄기';

  @override
  String get shortcutPlaylist => '재생 목록 켜기/끄기';

  @override
  String get shortcutSubtitleDelay => '자막 지연 +/- 500ms';

  @override
  String get shortcutHelp => '도움말 표시';

  @override
  String get shortcutMediaKeys => '재생/일시정지';

  @override
  String get settings => '설정';

  @override
  String get audioTab => '오디오';

  @override
  String get specialThanks => '특별 감사';

  @override
  String get thanksPending => '명단을 준비 중입니다';

  @override
  String get lgplNotice =>
      'mpv와 FFmpeg는 LGPL-2.1-or-later로 동적 링크됩니다 · 자세한 내용은 동봉된 NOTICE 파일을 참조하세요';

  @override
  String get generalTab => '일반';

  @override
  String get language => '언어';

  @override
  String get theme => '테마';

  @override
  String get shortcutsTab => '단축키';

  @override
  String get aboutTab => '정보';

  @override
  String get equalizer => '이퀄라이저';

  @override
  String get audioTrack => '오디오 트랙';

  @override
  String get videoTab => '비디오';

  @override
  String get noAudioTracks => '사용 가능한 오디오 트랙이 없습니다';

  @override
  String get videoProcessingUnavailable => '화면 처리를 사용할 수 없습니다';

  @override
  String audioTrackN(int index) {
    return '오디오 트랙 $index';
  }

  @override
  String get eqOff => '끄기';

  @override
  String get eqBassBoost => '저음 강화';

  @override
  String get eqVocalBoost => '보컬 강화';

  @override
  String get eqRock => '록';

  @override
  String get eqClassical => '클래식';

  @override
  String get colorCorrection => '색상 보정';

  @override
  String get brightness => '밝기';

  @override
  String get contrast => '대비';

  @override
  String get saturation => '채도';

  @override
  String get hue => '색조';

  @override
  String get rotation => '회전';

  @override
  String get aspectRatio => '화면 비율';

  @override
  String get deinterlace => '디인터레이스';

  @override
  String get resetAll => '모두 재설정';

  @override
  String get enableDeinterlace => '디인터레이스 사용';

  @override
  String get softwareDecoderOnly => '소프트웨어 디코더에서만 작동';

  @override
  String get videoProcessing => '화면';

  @override
  String get shortcutsHelpTitle => '단축키';

  @override
  String get close => '닫기';

  @override
  String get previousTrack => '이전';

  @override
  String get nextTrack => '다음';

  @override
  String get playlist => '재생 목록';

  @override
  String get fullscreen => '전체 화면 (F)';

  @override
  String get exitFullscreen => '전체 화면 종료 (F)';

  @override
  String get openSubtitle => '자막 열기';

  @override
  String get play => '재생';

  @override
  String get resumePlayback => '이어서 재생';

  @override
  String get pause => '일시정지';

  @override
  String get stop => '정지';

  @override
  String get rewind10 => '10초 뒤로';

  @override
  String get forward30 => '30초 앞으로';

  @override
  String get pin => '항상 위';

  @override
  String get unpin => '항상 위 해제';

  @override
  String get minimize => '최소화';

  @override
  String get maximize => '최대화';

  @override
  String get restore => '복원';

  @override
  String get playlistEmpty => '재생 목록이 비어 있습니다';

  @override
  String get resumeRememberPosition => '재생 위치 기억';

  @override
  String get audioDelay => '오디오 지연';

  @override
  String get subtitleDelay => '자막 지연';

  @override
  String get sortBy => '정렬';

  @override
  String get sortByAddedOrder => '추가한 순서';

  @override
  String get sortByName => '이름순';

  @override
  String get sortByLastPlayed => '마지막 재생순';

  @override
  String get sortByDuration => '길이순';

  @override
  String get sortAscending => '오름차순';

  @override
  String get sortDescending => '내림차순';

  @override
  String get noHistory => '재생 기록이 없습니다';

  @override
  String get playlistTab => '재생 목록';

  @override
  String get historyTab => '재생 기록';

  @override
  String get clear => '비우기';

  @override
  String get playAction => '재생';

  @override
  String get copyPath => '경로 복사';

  @override
  String get properties => '속성';

  @override
  String get remove => '제거';

  @override
  String get pathCopied => '경로가 복사되었습니다';

  @override
  String breakpointAt(String time) {
    return '이어보기 지점 $time';
  }

  @override
  String lastPlayedAt(String time) {
    return '지난 재생: $time';
  }

  @override
  String get justNow => '방금 전';

  @override
  String minutesAgo(int minutes) {
    return '$minutes분 전';
  }

  @override
  String hoursAgo(int hours) {
    return '$hours시간 전';
  }

  @override
  String daysAgo(int days) {
    return '$days일 전';
  }

  @override
  String get propertiesDialog => '속성';

  @override
  String get fileSection => '파일';

  @override
  String get filePath => '경로';

  @override
  String get fileName => '파일 이름';

  @override
  String get videoSection => '비디오';

  @override
  String get resolution => '해상도';

  @override
  String get codec => '코덱';

  @override
  String get pixelAspectRatio => '픽셀 화면비';

  @override
  String get aspectRatioLabel => '화면 비율';

  @override
  String get durationSection => '길이';

  @override
  String get totalDuration => '전체 길이';

  @override
  String get audioSection => '오디오';

  @override
  String get trackCount => '트랙 수';

  @override
  String trackN(int index) {
    return '트랙 $index';
  }

  @override
  String get subtitleSection => '자막';

  @override
  String get copied => '복사됨';

  @override
  String get doubleClickToCopy => '두 번 클릭하여 복사';

  @override
  String get unknown => '알 수 없음';

  @override
  String get reopen => '다시 열기';

  @override
  String get selectOtherFile => '다른 파일 선택';

  @override
  String get retry => '다시 시도';

  @override
  String get unmute => '음소거 해제';

  @override
  String get mute => '음소거';

  @override
  String get volume => '음량';

  @override
  String volumePercent(String percent) {
    return '음량 $percent%';
  }

  @override
  String get aspectRatioOriginal => '원본';

  @override
  String get aspectRatioStretch => '늘리기';

  @override
  String get aspectRatioCropFill => '가득 채우기';

  @override
  String get aspectRatioFree => '자유';

  @override
  String get progressBar => '재생 진행률';

  @override
  String get speedDecrease => '느리게';

  @override
  String get speedReset => '배속 (두 번 클릭하여 재설정)';

  @override
  String get speedIncrease => '빠르게';

  @override
  String get folderTab => '폴더';

  @override
  String get resumeAction => '이어서 재생';

  @override
  String get openFileLocation => '파일 위치 열기';

  @override
  String get clearHistory => '기록 비우기';

  @override
  String get scanFolder => '폴더 스캔';

  @override
  String get noVideosInFolder => '폴더에 동영상이 없습니다';

  @override
  String get themeMidnight => '미드나잇';

  @override
  String get themeOcean => '오션';

  @override
  String get themeForest => '포레스트';

  @override
  String get version => '버전';

  @override
  String get techStack => '기술 스택';

  @override
  String get licenses => '오픈 소스 라이선스';

  @override
  String get copyright => 'Flutter + media_kit (libmpv) 기반';

  @override
  String get resetShortcuts => '기본값 복원';

  @override
  String get pressKeyToBind => '새 키를 누르세요...';

  @override
  String get shortcutConflict => '이미 사용 중인 키입니다';

  @override
  String get currentTheme => '현재 테마';

  @override
  String get ok => '확인';

  @override
  String get cancel => '취소';

  @override
  String get apply => '적용';

  @override
  String get playerLoadError => '플레이어 모듈 로드 실패';

  @override
  String get playerInitFailed => '플레이어 초기화 실패';

  @override
  String get performanceTab => '성능';

  @override
  String get d3d11Rendering => 'D3D11 렌더링';

  @override
  String get d3d11Sync => 'D3D11 CPU 동기화';

  @override
  String get d3d11SyncDesc =>
      '매 프레임 CPU와 GPU를 동기화합니다. 끄면 지연이 줄지만 화면 찢어짐이 생길 수 있습니다.';

  @override
  String get decoderSettings => '디코더';

  @override
  String get hardwareDecoding => '하드웨어 디코딩';

  @override
  String get hardwareDecodingDesc => 'GPU로 비디오를 디코딩합니다. 화면 이상이 있으면 끄세요.';

  @override
  String get performanceHint => '변경 사항은 다음 파일을 열 때 적용됩니다.';

  @override
  String get resetToDefaults => '기본값 복원';

  @override
  String resetConfirmTitle(String tabName) {
    return '$tabName 설정을 재설정하시겠습니까?';
  }

  @override
  String get resetConfirmMessage => '다음 설정이 기본값으로 복원됩니다:';

  @override
  String get confirmReset => '재설정 확인';

  @override
  String get exportSettings => '내보내기';

  @override
  String get importSettings => '가져오기';

  @override
  String get importConfirmTitle => '설정을 가져오시겠습니까?';

  @override
  String get importConfirmMessage => '다음 설정이 덮어쓰여집니다:';

  @override
  String get importConfirmCategories => '재생, 비디오 효과, 자막, 창, 단축키, 테마, 언어';

  @override
  String get importSuccess => '설정을 가져왔습니다';

  @override
  String importError(String error) {
    return '가져오기 실패: $error';
  }

  @override
  String get exportError => '내보내기 실패';

  @override
  String get exportSuccess => '설정을 내보냈습니다';

  @override
  String importParseError(String error) {
    return '잘못된 JSON: $error';
  }

  @override
  String importFileReadError(String error) {
    return '파일을 읽을 수 없습니다: $error';
  }

  @override
  String get openingMedia => '미디어를 여는 중';

  @override
  String get bufferingMedia => '미디어를 버퍼링하는 중';

  @override
  String get errorFilePathEmpty => '파일 경로가 비어 있습니다';

  @override
  String get errorFileNotFound => '파일이 존재하지 않습니다';

  @override
  String get errorFilepathTraversal => '파일 경로가 잘못되었습니다';

  @override
  String get errorCodecUnsupportedFormat => '지원되지 않는 미디어 형식';

  @override
  String get errorCodecDecodeFailed => '미디어를 디코딩할 수 없습니다';

  @override
  String get errorCodecCodecUnsupported => '지원되지 않는 코덱';

  @override
  String get errorPlaybackPlayFailed => '재생 실패';

  @override
  String get errorPlaybackSeekFailed => '이동 실패';

  @override
  String get errorPlaybackTextureFailed => '비디오 렌더링 실패';

  @override
  String get errorPlaybackOpenTimeout => '열기 시간 초과';

  @override
  String get errorNetworkTimeout => '네트워크 시간 초과';

  @override
  String get errorNetworkConnectionLost => '연결이 끊겼습니다';

  @override
  String get errorUnknown => '알 수 없는 오류가 발생했습니다';

  @override
  String errorCardBadgeLabel(int count) {
    return '오류 $count개';
  }

  @override
  String get errorCardClose => '닫기';

  @override
  String get errorCardCopyTooltip => '진단 정보 복사';

  @override
  String get errorCardCopied => '복사됨';

  @override
  String get errorCardCopyFailed => '복사 실패';

  @override
  String get errorCardOpenLogTooltip => '로그 위치 열기';

  @override
  String get errorCardLogOpened => '로그 위치를 열었습니다';

  @override
  String get errorCardOpenLogFailed => '로그 위치 열기 실패';

  @override
  String get errorCardSectionLocation => '위치';

  @override
  String get errorCardSectionSource => '소스 줄';

  @override
  String get errorCardSectionStack => '호출 스택';

  @override
  String get errorCardSectionLogPath => '로그 파일';

  @override
  String errorCardSectionRepeats(int count) {
    return '$count회 반복';
  }

  @override
  String get errorCardLogUnavailable => '로그 파일을 사용할 수 없습니다';

  @override
  String get errorCardLocationUnavailable => '위치를 사용할 수 없습니다';

  @override
  String get errorCardCycleTooltip => '오류 순환 보기';

  @override
  String get errorCardToggleLabel => '오류 카드';

  @override
  String get languageLabel => '언어';

  @override
  String get languageSystem => '시스템 따르기';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChinese => '中文';
}
