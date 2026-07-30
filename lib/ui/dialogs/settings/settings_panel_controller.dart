// SettingsPanelController — Phase 23 PANEL-02 生命周期控制器。
//
// 经 SettingsPanelPlayback 服务边界协调视频暂停/恢复（D-03），不直碰
// MediaEngine，避免与 openGeneration 打开守卫产生竞态。构造注入
// （D-02），由组合根（app.dart / PlayerServices）装配，不使用 DI 框架
// 或 BuildContext 取依赖。

import 'dart:ui';

import '../../../kernel/engine/media_state.dart';
import '../../../kernel/services/playback_controller.dart';
import 'audio_filter_compositor.dart';
import 'pending_settings.dart';
import 'settings_panel_state.dart';

/// 设置面板控制器 — 持有 [SettingsPanelState]，实现 open/close/toggle
/// 生命周期，并在打开前后经 [SettingsPanelPlayback] 协调播放暂停/恢复。
///
/// 打开前快照 [_preOpenState]（[MediaState] 语义，在暂停之前读取，保证
/// 同步 open() 调用内无并发交叠语义），仅当快照为 [MediaState.playing]
/// 时才在 close() 时恢复播放。
class SettingsPanelController {
  SettingsPanelController(
    this._playback, {
    AudioSettings audioDefaults = const AudioSettings(),
    AudioCommitCallback? onAudioCommit,
  })  : _audioDefaults = audioDefaults,
        _audioCommitCallback = onAudioCommit;

  /// 播放服务边界 — 仅暴露 pause()/play()/isPlaying（D-03）.
  final SettingsPanelPlayback _playback;

  /// 音频偏好基准快照——open() 注册 4 个原始键的基准值（Phase 33, AUDIO-07）。
  /// 由 PlayerFeature 组合根从 SettingsStore 加载后经构造注入。
  final AudioSettings _audioDefaults;

  /// 音频提交回调——commitPending() 构造 [AudioSettings] 快照后调用一次
  /// （Q2 Option A）。PlayerFeature 组合根实现：组合 af 串 → setEqualizer → 持久化。
  final AudioCommitCallback? _audioCommitCallback;

  /// 面板状态模型（PANEL-01）.
  final SettingsPanelState state = SettingsPanelState();

  /// 延迟应用状态（TABS-04）— 持有用户待提交的修改.
  final PendingSettingsState pending = PendingSettingsState();

  /// 打开面板前的播放状态快照 — 仅当为 [MediaState.playing] 时 close()
  /// 才恢复播放；其余状态（idle/opening/paused/completed/error）一律不恢复.
  MediaState _preOpenState = MediaState.idle;

  /// Tab 总数 — 用于 nextTab/prevTab 首尾循环的模数.
  static const int tabCount = 7;

  /// 默认 tab 索引 — General 在七 tab 序列 [EQ, Audio, Video, General, Shortcuts,
  /// About, Performance] 中位于 index 3（D-01：General 为中间/默认打开项）.
  static const int defaultTabIndex = 3;

  /// 打开面板 — 已打开时 no-op（幂等）。
  ///
  /// 顺序：先重置 selectedTab 为 0（D-03），再快照播放状态（[MediaState]），
  /// 无条件暂停播放（PAUSE-01 安全策略），最后翻转 [state.isOpen]。
  /// 快照必须先于 pause() 读取，因为 pause() 会改变引擎状态；无条件 pause
  /// 确保面板打开期间播放始终暂停，无论快照为何种状态.
  void open() {
    if (state.isOpen.value) return;
    // D-01: 每次打开重置到 General tab（index 3，七 tab 序列中间）
    state.selectedTab.value = defaultTabIndex;
    // PAUSE-02: 经窄接缝 isPlaying 投影为 MediaState 快照——playing 可恢复，
    // 其余状态统一记为 paused（非 playing 的安全代表），close() 只认 playing.
    _preOpenState = _playback.isPlaying ? MediaState.playing : MediaState.paused;
    // PAUSE-01: 无条件暂停——面板打开期间播放始终暂停，避免设置面板后续
    // 阶段在 opening/completed/manual-pause 状态期间产生播放竞态.
    _playback.pause();
    // 注册已知设置项的原始值（TABS-04）— 后续 tab 内容替换时扩展
    pending.register('locale', 'zh');
    pending.register('themeIndex', 0);
    // Phase 33: 注册 4 个音频原始键——基准值来自 PlayerFeature 注入的持久化默认
    pending.register('eqPresetIndex', _audioDefaults.eqPresetIndex);
    pending.register('balance', _audioDefaults.balance);
    pending.register('syncMs', _audioDefaults.syncMs);
    pending.register('normalization', _audioDefaults.normalization);
    state.isOpen.value = true;
  }

  /// 切换到下一个 tab（首尾循环：6→0）。
  void nextTab() {
    state.selectedTab.value = (state.selectedTab.value + 1) % tabCount;
  }

  /// 切换到上一个 tab（首尾循环：0→6）。
  void prevTab() {
    state.selectedTab.value =
        (state.selectedTab.value - 1 + tabCount) % tabCount;
  }

  /// 关闭面板 — 已关闭时 no-op（幂等）。
  ///
  /// PAUSE-03 安全恢复规则：仅当打开前快照为 [MediaState.playing] 时才调用
  /// [SettingsPanelPlayback.play] 恢复播放。非 playing 快照（idle/opening/
  /// paused/completed/error，以及由独立 ValueNotifier 跟踪的 buffering/seeking）
  /// 一律不恢复——这些状态代表媒体不可恢复或不应自动续播，避免设置面板在
  /// 加载、完成、手动暂停期间产生播放竞态。
  ///
  /// 无论是否恢复，都将 [state.dragOffset] 重置为 [Offset.zero]（面板下次
  /// 打开时居中），并释放延迟应用状态（TABS-04）。
  void close() {
    if (!state.isOpen.value) return;
    state.isOpen.value = false;
    // PAUSE-03: 仅 playing 快照可恢复；opening/completed/manual-pause 等不恢复.
    final shouldResume = _preOpenState == MediaState.playing;
    if (shouldResume) {
      _playback.play();
    }
    state.dragOffset.value = Offset.zero;
    // 释放延迟应用状态 — 下次 open() 重新注册（TABS-04）
    pending.dispose();
  }

  /// 切换面板开关状态 — 等价于 open()/close() 二选一。
  void toggle() {
    if (state.isOpen.value) {
      close();
    } else {
      open();
    }
  }

  /// 提交所有待修改值（TABS-04）— 返回变更 map.
  ///
  /// Phase 33: 提交后从已提交值构造 [AudioSettings] 快照，调用音频提交回调
  /// 一次（Q2 Option A）。current() 在 commit() 后返回 _originals（已更新为
  /// 已提交值），即"已提交或当前值"。Cancel 走 cancelPending()，不经此路径，
  /// 故回调零调用（AUDIO-06）。
  Map<String, dynamic> commitPending() {
    final changes = pending.commit();
    _audioCommitCallback?.call(AudioSettings(
      eqPresetIndex: pending.current('eqPresetIndex') as int? ?? 0,
      balance: pending.current('balance') as double? ?? 0.0,
      syncMs: pending.current('syncMs') as int? ?? 0,
      normalization: pending.current('normalization') as bool? ?? false,
    ));
    return changes;
  }

  /// 回滚所有修改（TABS-04）— 返回原始值 map.
  Map<String, dynamic> cancelPending() => pending.cancel();

  /// 释放面板状态资源.
  void dispose() {
    pending.dispose();
    state.dispose();
  }
}
