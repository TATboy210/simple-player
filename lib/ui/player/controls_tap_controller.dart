import 'dart:async';

import '../../kernel/engine/engine_state.dart';
import 'controls_host.dart';
import 'workspace_focus_scope.dart';

/// 视频区点击语义 — 点外关闭面板 → 双击全屏 → 单击立即隐藏控制栏。
///
/// 持有双击判定 Timer；由 State 在 dispose 时调用 [dispose]。
class ControlsTapController {
  ControlsTapController(this._host, {required this.toggleFullscreen});

  final ControlsHost _host;

  /// 双击触发的全屏切换。
  final void Function() toggleFullscreen;

  /// 单击/双击判定窗口 400ms。
  static const _clickDelayMs = 400;
  Timer? _clickTimer;

  /// 空白先独立取消菜单，再关闭一个中心任务并归还播放器焦点。
  /// 返回 true 表示本次点击已被消费。
  bool _closeWorkspaceFromBlank() {
    if (_host.menuSession?.cancel() == true) return true;
    final center = _host.workspace?.value.center;
    if (center == null) return false;
    _host.workspaceFocus?.close(center, WorkspaceCloseCause.blank);
    return true;
  }

  /// 关闭 legacy 设置面板；返回 true 表示它原本开着。
  bool _closeLegacySettings() {
    final settings = _host.legacySettingsVisible;
    if (settings == null || !settings.value) return false;
    settings.value = false;
    return true;
  }

  /// 空置态手势 — 只关闭浮层面板（设置 → 播放列表），不触发双击全屏/隐藏：
  /// 空置态控制栏钉住恒显、全屏无意义；仅补面板外点击的关闭通路。
  void handleEmptyAreaTap() {
    if (_closeWorkspaceFromBlank() || _closeLegacySettings()) return;
    final playlist = _host.playlistVisible;
    if (playlist != null && playlist.value) playlist.value = false;
  }

  /// 普通点击 — 面板可见时先关面板(逐个关闭，任务空后关播放列表)，
  /// 否则走单击/双击判定。
  void handleTap() {
    if (_closeWorkspaceFromBlank() || _closeLegacySettings()) return;
    final playlist = _host.playlistVisible;
    if (playlist != null && playlist.value) {
      playlist.value = false;
      return;
    }
    if (_clickTimer?.isActive ?? false) {
      // 第二次点击在延迟内 → 双击，切换全屏
      _clickTimer?.cancel();
      toggleFullscreen();
      return;
    }
    // D-04: 第一次点击 → 立即隐藏(不等延迟)
    if (_host.engine.state.value != MediaState.idle) _host.autoHide.hide();
    // Timer 仅作双击检测窗口 — 超时无动作，空回调刻意。
    // ignore: no-empty-block
    _clickTimer = Timer(const Duration(milliseconds: _clickDelayMs), () {});
  }

  /// 取消未决的双击窗口。
  void dispose() => _clickTimer?.cancel();
}
