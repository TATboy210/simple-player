import 'package:flutter/foundation.dart';

/// 聚合监听槽位 — 每个槽位对应一个回调，可由多个源驱动。
enum ControlsSlot {
  /// 引擎状态 → decoration 切换 + 钉住同步。
  engineState,

  /// 窗口模式 → 全屏派生状态。
  mode,

  /// resize 信号。
  resize,

  /// 控制栏显隐 → 字幕安全区。
  subtitle,

  /// auto-hide hold 多源合成 (模态/播放列表/任务面板/菜单)。
  hold,

  /// 媒体身份 → 菜单失效。
  media,

  /// legacy 设置面板边沿 → 焦点归还。
  settingsFocus,

  /// 光标/语义派生信号的多源重算。
  derived,
}

/// 逐项 identity 比较两个源列表。
bool sameSources(List<Listenable?> a, List<Listenable?> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!identical(a[i], b[i])) return false;
  }
  return true;
}

/// 合并非空源；全为空时返回 null。
Listenable? mergeNonNull(List<Listenable?> sources) {
  final live = sources.whereType<Listenable>().toList(growable: false);
  return live.isEmpty ? null : Listenable.merge(live);
}

class _Slot {
  _Slot(this.sources, this.callback) : merged = mergeNonNull(sources);

  final List<Listenable?> sources;
  final VoidCallback callback;
  final Listenable? merged;
}

/// 控制层监听中枢 — 把原先 initState/didUpdateWidget 的双份注册收敛为
/// 单一 [bind] 路径。
///
/// 每个 [ControlsSlot] 用一个 `Listenable.merge` 承载其全部源，因此同一回调
/// 不会被 N 个 notifier 重复挂载。[bind] 幂等：源 identity 未变则零开销返回
/// false；变化时先解除旧合并监听再接新的 (仅在 [attach] 状态下真正挂接)。
/// [detach]/[attach] 对应 deactivate/activate：inactive 期间只记录源，不挂接。
class ControlsListenerHub {
  final Map<ControlsSlot, _Slot> _slots = {};
  bool _attached = false;

  /// 是否处于挂接状态。
  bool get isAttached => _attached;

  /// 设定槽位的源与回调。返回 true 表示源集合相对上次发生了变化。
  ///
  /// side effect: attached 时会对旧/新合并监听做 remove/add。
  bool bind(
    ControlsSlot slot,
    List<Listenable?> sources,
    VoidCallback callback,
  ) {
    final old = _slots[slot];
    if (old != null && sameSources(old.sources, sources)) return false;
    if (_attached) old?.merged?.removeListener(old.callback);
    final next = _Slot(List<Listenable?>.of(sources), callback);
    _slots[slot] = next;
    if (_attached) next.merged?.addListener(next.callback);
    return true;
  }

  /// 挂接全部槽位 (幂等)。
  void attach() {
    if (_attached) return;
    _attached = true;
    for (final s in _slots.values) {
      s.merged?.addListener(s.callback);
    }
  }

  /// 解除全部槽位 (幂等) — deactivate 即调用，防止 inactive 期间触碰祖先。
  void detach() {
    if (!_attached) return;
    _attached = false;
    for (final s in _slots.values) {
      s.merged?.removeListener(s.callback);
    }
  }
}
