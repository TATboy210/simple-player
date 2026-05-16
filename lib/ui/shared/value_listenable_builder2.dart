import 'package:flutter/material.dart';

/// 双 ValueNotifier 组合 Builder（避免嵌套）
class ValueListenableBuilder2<A, B> extends StatelessWidget {
  final ValueNotifier<A> first;
  final ValueNotifier<B> second;
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
