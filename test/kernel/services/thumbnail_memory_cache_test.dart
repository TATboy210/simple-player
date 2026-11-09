/// ThumbnailMemoryCache / ThumbnailFailureMemo 单测 — LRU 淘汰与索引一致性 + TTL.
///
/// 假时钟注入, 无真实延时.
library;

import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/services/thumbnail_memory_cache.dart';

ImageProvider _img(int seed) => MemoryImage(Uint8List.fromList([seed]));

void main() {
  group('ThumbnailMemoryCache', () {
    test('超容量淘汰最久未访问者; get 触碰后免于淘汰', () {
      final cache = ThumbnailMemoryCache(maxSize: 2);
      cache
        ..put('/a', 'ka', _img(1))
        ..put('/b', 'kb', _img(2));

      expect(cache.get('ka'), isNotNull); // touch a → b 成为最旧
      cache.put('/c', 'kc', _img(3));

      expect(cache.keys.toList(), ['ka', 'kc']);
      expect(cache.get('kb'), isNull);
      expect(cache.length, 2);
    });

    test('evictPath 清除该 path 的全部 key (多版本共存), 他 path 不受影响', () {
      final cache = ThumbnailMemoryCache(maxSize: 10)
        ..put('/a', 'a-v1', _img(1))
        ..put('/a', 'a-v2', _img(2))
        ..put('/b', 'b-v1', _img(3));

      cache.evictPath('/a');

      expect(cache.keys.toList(), ['b-v1']);
    });

    test('LRU 淘汰同步清反向索引 — 之后 evictPath 不误伤同 path 新条目', () {
      final cache = ThumbnailMemoryCache(maxSize: 1)
        ..put('/a', 'a-v1', _img(1))
        ..put('/a', 'a-v2', _img(2)); // a-v1 被淘汰

      expect(cache.keys.toList(), ['a-v2']);
      cache.evictPath('/a');
      expect(cache.length, 0);
    });

    test('touch 不存在的 key 为 no-op; clear 清空', () {
      final cache = ThumbnailMemoryCache(maxSize: 3)..put('/a', 'ka', _img(1));
      cache.touch('missing');
      expect(cache.length, 1);

      cache.clear();
      expect(cache.length, 0);
      expect(cache.get('ka'), isNull);
    });
  });

  group('ThumbnailFailureMemo', () {
    test('TTL 内屏蔽, 过期回收并放行', () {
      var now = DateTime(2026, 1, 1);
      final memo = ThumbnailFailureMemo(
        ttl: const Duration(seconds: 10),
        now: () => now,
      );

      expect(memo.isBlocked('/a', 'ka'), isFalse);
      memo.record('/a', 'ka');
      expect(memo.isBlocked('/a', 'ka'), isTrue);

      now = now.add(const Duration(seconds: 9));
      expect(memo.isBlocked('/a', 'ka'), isTrue);

      now = now.add(const Duration(seconds: 2));
      expect(memo.isBlocked('/a', 'ka'), isFalse, reason: 'TTL 过期放行');
      expect(memo.isBlocked('/a', 'ka'), isFalse, reason: '已回收');
    });

    test('evictPath 仅清该 path 的失败记录 (无 prefix 碰撞)', () {
      final memo = ThumbnailFailureMemo(ttl: const Duration(minutes: 1))
        ..record('/a', 'ka')
        ..record('/a.bak', 'kab');

      memo.evictPath('/a');

      expect(memo.isBlocked('/a', 'ka'), isFalse);
      expect(memo.isBlocked('/a.bak', 'kab'), isTrue);

      memo.clear();
      expect(memo.isBlocked('/a.bak', 'kab'), isFalse);
    });
  });
}
