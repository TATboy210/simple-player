import 'package:flutter/foundation.dart';

/// 两个 int 值的配对
class TimePair {
  const TimePair(this.a, this.b);
  final int a, b;
}

/// 合并两个 `ValueNotifier<int>` 为一个 `ValueNotifier<TimePair>`
class MergedListenable extends ValueNotifier<TimePair> {
  MergedListenable(this._a, this._b) : super(TimePair(_a.value, _b.value)) {
    _a.addListener(_sync);
    _b.addListener(_sync);
  }

  final ValueNotifier<int> _a;
  final ValueNotifier<int> _b;

  void _sync() => value = TimePair(_a.value, _b.value);

  @override
  void dispose() {
    _a.removeListener(_sync);
    _b.removeListener(_sync);
    super.dispose();
  }
}
