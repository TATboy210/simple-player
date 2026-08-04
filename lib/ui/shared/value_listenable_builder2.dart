import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 双 ValueListenable 组合 Builder（避免嵌套）
///
/// 输入只需 ValueListenable(读 value + listen) — 路径B Commit1 修正:
/// 原 ValueNotifier 约束过严,vm 字段用 ValueListenable 抽象后暴露此 ISP 缺陷。
class ValueListenableBuilder2<A, B> extends StatelessWidget {
  final ValueListenable<A> first;
  final ValueListenable<B> second;
  final Widget Function(BuildContext, A, B, Widget?) builder;

  const ValueListenableBuilder2({
    super.key,
    required this.first,
    required this.second,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<A>(
      valueListenable: first,
      builder: (_, a, _) => ValueListenableBuilder<B>(
        valueListenable: second,
        builder: (ctx, b, child) => builder(ctx, a, b, child),
      ),
    );
  }
}
