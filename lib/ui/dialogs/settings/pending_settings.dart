// PendingSettingsState — 延迟应用状态容器（TABS-04）。
//
// 纯 Dart 类（非 ChangeNotifier/ValueNotifier），避免 IndexedStack 级联重建。
// 持有 _pending（用户修改）和 _originals（打开时快照）两个 map，
// 提供 register/update/current/commit/cancel 生命周期。

/// 延迟应用状态 — 管理设置面板中所有待提交的修改。
///
/// 设计意图：tab 内容通过 [update] 记录用户修改，按钮栏通过
/// [commit]/[cancel] 提交或回滚。Apply 后再 Cancel 以已提交值为基准
/// （非首次 register 的原始值）。
///
/// 纯数据容器，不触发 UI 重建 — 由调用方在合适时机 setState。
class PendingSettingsState {
  /// 待提交的修改值 — key 为设置项 ID（如 'locale'、'themeIndex'）。
  final Map<String, dynamic> _pending = {};

  /// 打开面板时的原始快照 — commit 后更新为已提交值。
  final Map<String, dynamic> _originals = {};

  /// 注册一个设置项的原始值（面板打开时调用）。
  ///
  /// 若 key 已存在则覆盖（重复 open 场景安全）。
  void register(String key, dynamic originalValue) {
    _originals[key] = originalValue;
  }

  /// 记录用户修改（tab 内容变更时调用）。
  void update(String key, dynamic value) {
    _pending[key] = value;
  }

  /// 返回当前显示值 — 优先 pending，回退 original。
  dynamic current(String key) => _pending[key] ?? _originals[key];

  /// 是否有未提交的修改。
  bool get hasChanges => _pending.isNotEmpty;

  /// 提交所有待修改值，返回变更 map。
  ///
  /// 副作用：清空 _pending，将已提交值写入 _originals（Apply-then-Cancel 基准更新）。
  Map<String, dynamic> commit() {
    final changes = Map<String, dynamic>.of(_pending);
    // 更新 originals — 后续 cancel 以已提交值为基准
    for (final entry in _pending.entries) {
      _originals[entry.key] = entry.value;
    }
    _pending.clear();
    return changes;
  }

  /// 回滚所有修改，返回原始值 map。
  ///
  /// 副作用：清空 _pending（tab 重新读取 current() 恢复显示）。
  Map<String, dynamic> cancel() {
    final originals = Map<String, dynamic>.of(_originals);
    _pending.clear();
    return originals;
  }

  /// 释放资源 — 清空两个 map。
  void dispose() {
    _pending.clear();
    _originals.clear();
  }
}
