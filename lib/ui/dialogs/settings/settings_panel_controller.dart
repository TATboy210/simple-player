// SettingsPanelController — Phase 23 PANEL-02 生命周期控制器。
//
// 经 SettingsPanelPlayback 服务边界协调视频暂停/恢复（D-03），不直碰
// MediaEngine，避免与 openGeneration 打开守卫产生竞态。构造注入
// （D-02），由组合根（app.dart / PlayerServices）装配，不使用 DI 框架
// 或 BuildContext 取依赖。

import 'dart:ui';

import '../../../kernel/services/playback_controller.dart';
import 'settings_panel_state.dart';

/// 设置面板控制器 — 持有 [SettingsPanelState]，实现 open/close/toggle
/// 生命周期，并在打开前后经 [SettingsPanelPlayback] 协调播放暂停/恢复。
///
/// 打开前快照 `wasPlaying`（在暂停之前读取，保证同步 open() 调用内
/// 无并发交叠语义），仅当快照为 true 时才在 close() 时恢复播放。
class SettingsPanelController {
  SettingsPanelController(this._playback);

  /// 播放服务边界 — 仅暴露 pause()/play()/isPlaying（D-03）.
  final SettingsPanelPlayback _playback;

  /// 面板状态模型（PANEL-01）.
  final SettingsPanelState state = SettingsPanelState();

  /// 打开面板前的播放状态快照 — 仅当为 true 时 close() 才恢复播放.
  bool _wasPlaying = false;

  /// 打开面板 — 已打开时 no-op（幂等）。
  ///
  /// 顺序：先读取 [SettingsPanelPlayback.isPlaying] 快照，再调用
  /// [SettingsPanelPlayback.pause]（仅当快照为 true），最后翻转 [state.isOpen]。
  /// 快照必须先于 pause() 读取，因为 pause() 会改变引擎状态。
  void open() {
    if (state.isOpen.value) return;
    _wasPlaying = _playback.isPlaying;
    if (_wasPlaying) {
      _playback.pause();
    }
    state.isOpen.value = true;
  }

  /// 关闭面板 — 已关闭时 no-op（幂等）。
  ///
  /// 仅当 [_wasPlaying] 为 true 时才调用 [SettingsPanelPlayback.play] 恢复播放，
  /// 并将 [state.dragOffset] 重置为 [Offset.zero]（面板下次打开时居中）。
  void close() {
    if (!state.isOpen.value) return;
    state.isOpen.value = false;
    if (_wasPlaying) {
      _playback.play();
    }
    state.dragOffset.value = Offset.zero;
  }

  /// 切换面板开关状态 — 等价于 open()/close() 二选一。
  void toggle() {
    if (state.isOpen.value) {
      close();
    } else {
      open();
    }
  }

  /// 释放面板状态资源.
  void dispose() => state.dispose();
}
