/// ThumbnailFlightRegistry 单测 — join / identical 守卫 / epoch 失效 / force 查询.
library;

import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/services/thumbnail_flight_registry.dart';

void main() {
  late ThumbnailFlightRegistry registry;

  ThumbnailFlight flightFor(String path, String key, {bool isForce = false}) {
    final flight = registry.create(path: path, cacheKey: key, isForce: isForce);
    registry.register(flight);
    return flight;
  }

  setUp(() => registry = ThumbnailFlightRegistry());

  group('ThumbnailFlightRegistry', () {
    test('register 后同 key 可 join, remove 后消失', () {
      final flight = flightFor('/a.mp4', 'k1');

      expect(registry.forKey('k1'), same(flight));
      expect(registry.activeCount, 1);

      registry.remove(flight);
      expect(registry.forKey('k1'), isNull);
      expect(registry.activeCount, 0);
    });

    test('remove 的 identical 守卫 — 旧代完成不撤销新代 join 通道 (F4)', () {
      final old = flightFor('/a.mp4', 'k1');
      final fresh = flightFor('/a.mp4', 'k1'); // 同 key 新代覆盖注册

      registry.remove(old);

      expect(registry.forKey('k1'), same(fresh));
    });

    test('isCurrent — create 时捕获 epoch, 未失效前恒真', () {
      final flight = flightFor('/a.mp4', 'k1');
      expect(registry.isCurrent(flight), isTrue);
    });

    test('evictPath — 仅该 path 的 flight 失效并出 join 表', () {
      final a = flightFor('/a.mp4', 'ka');
      final b = flightFor('/b.mp4', 'kb');

      registry.evictPath('/a.mp4');

      expect(registry.isCurrent(a), isFalse);
      expect(registry.forKey('ka'), isNull, reason: '出 join 表');
      expect(registry.isCurrent(b), isTrue, reason: '他 path 不受影响');
      expect(registry.forKey('kb'), same(b));
    });

    test('evictPath 后新建 flight 捕获新 epoch 仍为 current', () {
      flightFor('/a.mp4', 'k1');
      registry.evictPath('/a.mp4');

      final fresh = flightFor('/a.mp4', 'k1');

      expect(registry.isCurrent(fresh), isTrue);
    });

    test('clear — globalEpoch++ 使全部 flight 失效且清空索引', () {
      final a = flightFor('/a.mp4', 'ka');
      final b = flightFor('/b.mp4', 'kb');

      registry.clear();

      expect(registry.isCurrent(a), isFalse);
      expect(registry.isCurrent(b), isFalse);
      expect(registry.activeCount, 0);
      expect(registry.forceFlightFor('/a.mp4'), isNull);
    });

    test('forceFlightFor — 只返回该 path 上在飞的 force flight (H5/F6)', () {
      flightFor('/a.mp4', 'normal');
      expect(registry.forceFlightFor('/a.mp4'), isNull);

      final force = flightFor('/a.mp4', 'forced', isForce: true);
      expect(registry.forceFlightFor('/a.mp4'), same(force));
      expect(registry.forceFlightFor('/other.mp4'), isNull);

      registry.remove(force);
      expect(registry.forceFlightFor('/a.mp4'), isNull);
    });

    test('flight.complete 交付结果, 重复 complete 抛 StateError (I11)', () async {
      final flight = flightFor('/a.mp4', 'k1');
      final image = MemoryImage(Uint8List.fromList([1, 2, 3]));

      flight.complete(image);

      expect(await flight.future, same(image));
      expect(() => flight.complete(null), throwsStateError);
    });
  });
}
