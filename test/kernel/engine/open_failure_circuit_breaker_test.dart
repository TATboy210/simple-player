/// OpenFailureCircuitBreaker 纯逻辑测试 (v0.0.6.1).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/open_failure_circuit_breaker.dart';

void main() {
  group('OpenFailureCircuitBreaker', () {
    test('连续失败达到阈值即熔断', () {
      final breaker = OpenFailureCircuitBreaker(threshold: 3);
      expect(breaker.registerFailure(), isFalse);
      expect(breaker.registerFailure(), isFalse);
      expect(breaker.registerFailure(), isTrue); // 第 3 次 → 熔断
    });

    test('成功装载复位 — 少量坏文件不熔断', () {
      final breaker = OpenFailureCircuitBreaker(threshold: 3);
      expect(breaker.registerFailure(), isFalse);
      expect(breaker.registerFailure(), isFalse);
      breaker.reset(); // 好条目装载成功
      expect(breaker.registerFailure(), isFalse);
      expect(breaker.registerFailure(), isFalse);
      expect(breaker.count, 2); // 重新累计
    });

    test('熔断后继续登记保持触发 (调用方负责停止)', () {
      final breaker = OpenFailureCircuitBreaker(threshold: 3);
      breaker.registerFailure();
      breaker.registerFailure();
      expect(breaker.registerFailure(), isTrue);
      expect(breaker.registerFailure(), isTrue); // 未复位则持续触发
    });

    test('默认阈值 = 3', () {
      expect(OpenFailureCircuitBreaker().threshold, 3);
    });
  });
}
