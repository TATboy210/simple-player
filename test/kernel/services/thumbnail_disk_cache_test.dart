import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:simple_player_flutter/kernel/services/thumbnail_disk_cache.dart';
import 'package:simple_player_flutter/kernel/services/thumbnail_service.dart';

import '../../helpers/fake_thumbnail_provider.dart';

void main() {
  group('ThumbnailDiskCache (P-Thumb v1.3.2 D1-D12)', () {
    late Directory tempDir;
    late ThumbnailDiskCache cache;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('pthumb_disk');
      cache = ThumbnailDiskCache(
        resolveDirectory: () async => tempDir,
        now: DateTime.now,
      );
    });

    tearDown(() async {
      try {
        await tempDir.delete(recursive: true);
      } on FileSystemException {
        // best effort — 临时目录清理失败不影响测试结论
      }
    });

    /// 直接落盘一个 .jpg 文件（绕过 write 的校验 — 模拟损坏/历史文件）
    Future<File> seedFile(String name, List<int> bytes) async {
      final file = File(p.join(tempDir.path, name));
      await file.writeAsBytes(bytes);
      return file;
    }

    test('D1: read on missing key returns null', () async {
      final key = 'a' * 64;
      expect(await cache.read(key), isNull);
    });

    test('D2: valid JPEG round-trips through write/read (disk hit)', () async {
      final key = hexKey('ab');
      final file = await cache.write(
        key,
        makeJpegBytes(seed: 1),
        replaceExisting: false,
      );

      expect(file, isNotNull);
      final provider = await cache.read(key);
      expect(provider, isA<FileImage>());
    });

    test('D3: zero-byte jpg is rejected and deleted on read', () async {
      final file = await seedFile('${hexKey('ac')}.jpg', const []);
      expect(await cache.read(hexKey('ac')), isNull);
      expect(await file.exists(), isFalse);
    });

    test('D4: invalid SOI head is rejected and deleted on read', () async {
      // 首两字节 00 D8 — 非 FF D8
      final file = await seedFile('${hexKey('ad')}.jpg', [
        0x00,
        0xD8,
        0x01,
        0x02,
        0xFF,
        0xD9,
      ]);
      expect(await cache.read(hexKey('ad')), isNull);
      expect(await file.exists(), isFalse);
    });

    test('D5: invalid EOI tail is rejected and deleted on read', () async {
      // 尾两字节 FF 00 — 非 FF D9
      final file = await seedFile('${hexKey('ae')}.jpg', [
        0xFF,
        0xD8,
        0x01,
        0x02,
        0xFF,
        0x00,
      ]);
      expect(await cache.read(hexKey('ae')), isNull);
      expect(await file.exists(), isFalse);
    });

    test('D6a: write without replaceExisting keeps old content', () async {
      final key = hexKey('af');
      final oldBytes = makeJpegBytes(seed: 1, payload: 4);
      final newBytes = makeJpegBytes(seed: 2, payload: 4);

      await cache.write(key, oldBytes, replaceExisting: false);
      await cache.write(key, newBytes, replaceExisting: false);

      final stored = await (await cache.fileFor(key))!.readAsBytes();
      expect(stored, equals(oldBytes));
    });

    test('D6b: write with replaceExisting publishes new content', () async {
      final key = hexKey('ba');
      final oldBytes = makeJpegBytes(seed: 1, payload: 4);
      final newBytes = makeJpegBytes(seed: 2, payload: 4);

      await cache.write(key, oldBytes, replaceExisting: false);
      await cache.write(key, newBytes, replaceExisting: true);

      final stored = await (await cache.fileFor(key))!.readAsBytes();
      expect(stored, equals(newBytes));
    });

    test(
      'D7: directory resolve failure degrades to null (no disk layer)',
      () async {
        final broken = ThumbnailDiskCache(
          resolveDirectory: () async =>
              throw const FileSystemException('denied'),
        );

        expect(
          await broken.write(
            hexKey('bb'),
            makeJpegBytes(),
            replaceExisting: false,
          ),
          isNull,
        );
        expect(await broken.read(hexKey('bb')), isNull);
        expect(await broken.fileFor(hexKey('bb')), isNull);
      },
    );

    test('write rejects non-safe hash keys (path traversal guard)', () async {
      expect(
        await cache.write(
          r'..\..\evil',
          makeJpegBytes(),
          replaceExisting: false,
        ),
        isNull,
      );
    });

    test('D11: write rejects non-JPEG bytes (SOI symmetry, 30.6)', () async {
      // FF 开头但第二字节非 D8 — write 侧直接拒收
      final result = await cache.write(
        hexKey('bc'),
        Uint8List.fromList([0xFF, 0x00, 0x01, 0xFF, 0xD9]),
        replaceExisting: false,
      );
      expect(result, isNull);
      expect(await cache.read(hexKey('bc')), isNull);
    });

    test(
      'D12: legacy 0xFF-head corrupted file rejected + self-healed',
      () async {
        // 旧实现只查首字节 0xFF 会放行的垃圾文件
        final file = await seedFile('${hexKey('bd')}.jpg', [
          0xFF,
          0x00,
          0x01,
          0x02,
          0xFF,
          0xD9,
        ]);
        expect(await cache.read(hexKey('bd')), isNull);
        expect(await file.exists(), isFalse);
      },
    );

    test('D8: stale .part leftovers are removed by cleanup', () async {
      final stale = await seedFile('${hexKey('be')}.jpg.123-1.part', [1, 2, 3]);
      final fresh = await seedFile('${hexKey('bf')}.jpg.456-2.part', [4, 5, 6]);

      // stale 拨到 2 小时前，fresh 保持 1 分钟前
      await stale.setLastModified(
        DateTime.now().subtract(const Duration(hours: 2)),
      );
      await fresh.setLastModified(
        DateTime.now().subtract(const Duration(minutes: 1)),
      );

      await cache.scheduleCleanup();

      expect(await stale.exists(), isFalse);
      expect(await fresh.exists(), isTrue);
    });

    test(
      'D10: entries older than maxAge are purged (clock injection)',
      () async {
        final writtenAt = DateTime(2026, 1, 1, 12);
        var fakeNow = writtenAt;
        final aging = ThumbnailDiskCache(
          resolveDirectory: () async => tempDir,
          now: () => fakeNow,
        );

        await aging.write(
          hexKey('c1'),
          makeJpegBytes(),
          replaceExisting: false,
        );

        // 对齐 mtime 与注入时钟基准 — fs mtime 由 OS 管理，需手动拨到
        // 写入时刻，注入的 now 才能驱动 age 判定
        await (await aging.fileFor(hexKey('c1')))!.setLastModified(writtenAt);

        // 拨快 31 天
        fakeNow = writtenAt.add(const Duration(days: 31));
        await aging.scheduleCleanup();

        expect(await (await aging.fileFor(hexKey('c1')))!.exists(), isFalse);
      },
    );

    test(
      'D9: watermark eviction kicks in over byte cap (shrunk limits)',
      () async {
        final tight = ThumbnailDiskCache(
          resolveDirectory: () async => tempDir,
          now: DateTime.now,
          limits: const ThumbnailDiskCacheLimits(
            maxEntries: 10,
            maxBytes: 100,
            targetEntries: 4,
            targetBytes: 40,
          ),
        );

        // 3 个 40 字节文件 = 120 bytes > 100 cap → 删到 ≤ 40 bytes
        for (var i = 0; i < 3; i++) {
          await tight.write(
            '${'a$i'.padLeft(63, '0')}0',
            makeJpegBytes(payload: 36, seed: i),
            replaceExisting: false,
          );
        }

        await tight.scheduleCleanup();

        final remaining = tempDir.listSync().whereType<File>().toList();
        expect(remaining.length, equals(1));
      },
    );
  });

  group('ThumbnailService disk integration (B2)', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('pthumb_svc_disk');
    });

    tearDown(() async {
      ThumbnailService.reset();
      try {
        await tempDir.delete(recursive: true);
      } on FileSystemException {
        // best effort
      }
    });

    test('disk hit serves second request without re-decode', () async {
      final file = File(p.join(tempDir.path, 'video.mp4'));
      await file.writeAsString('v' * 10);

      ThumbnailService.reset(
        provider: FakeThumbnailProvider(),
        diskCache: ThumbnailDiskCache(resolveDirectory: () async => tempDir),
      );

      final first = await ThumbnailService.getThumbnail(file.path);
      expect(first, isNotNull);
      expect(ThumbnailService.metrics.providerCalls, equals(1));

      ThumbnailService.evict(file.path); // 清内存层 — 强制走磁盘

      final second = await ThumbnailService.getThumbnail(file.path);
      expect(second, isNotNull);
      expect(ThumbnailService.metrics.diskHits, equals(1));
      // 未再解帧 — 磁盘命中零 native decode
      expect(ThumbnailService.metrics.providerCalls, equals(1));
    });
  });
}
