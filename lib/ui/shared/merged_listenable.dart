import 'package:flutter/foundation.dart';

/// 两个 int 值的配对
class TimePair {
  const TimePair(this.a, this.b);
  final int a, b;
}

/// 合并两个 `ValueListenable<int>` 为一个 `ValueNotifier<TimePair>`
///
/// 输入只需 ValueListenable(读 value + listen) — 路径B Commit1 修正:
/// 原 ValueNotifier 约束过严,vm 字段用 ValueListenable 抽象后暴露此 ISP 缺陷。
class MergedListenable extends ValueNotifier<TimePair> {
  MergedListenable(this._a, this._b) : super(TimePair(_a.value, _b.value)) {
    _a.addListener(_sync);
    _b.addListener(_sync);
  }

  final ValueListenable<int> _a;
  final ValueListenable<int> _b;

  void _sync() => value = TimePair(_a.value, _b.value);

  @override
  void dispose() {
    _a.removeListener(_sync);
    _b.removeListener(_sync);
    super.dispose();
  }
}
