import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/models/playlist_item.dart';
import 'package:simple_player_flutter/kernel/services/thumbnail_disk_cache.dart';
import 'package:simple_player_flutter/kernel/services/thumbnail_service.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/playlist/playlist_tile.dart';

import '../../helpers/fake_thumbnail_provider.dart';

/// PlaylistTile 缩略图生命周期（P-Thumb v1.3.2 §26/§27 — T1-T7）
///
/// 模式：pumpWidget（FakeAsync 驱动 UI）→ runAsync（放行真实 stat IO）
/// → pumpAndSettle（UI 消化异步回写）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 禁用磁盘层 — T 组专注 Tile 生命周期（brokenDisk 永久降级，I9）
  final brokenDisk = ThumbnailDiskCache(
    resolveDirectory: () async => throw const FileSystemException('disabled'),
  );

  PlaylistTile buildTile(PlaylistItem item) {
    // 刻意空操作桩（DCM no-empty-block 明示豁免）— T 组只测缩略图
    // 生命周期，播放/续播/移除行为由 panel 测试覆盖
    return PlaylistTile(
      item: item,
      isCurrent: false,
      isResumeAnchor: false,
      // ignore: no-empty-block
      onPlay: () {},
      // ignore: no-empty-block
      onResume: () {},
      // ignore: no-empty-block
      onRemove: () {},
    );
  }

  Widget wrap(Widget child) => MaterialApp(
    // Tile build 依赖 AppLocalizations.of — delegates 必须就位
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SizedBox(width: 280, child: child)),
  );

  Future<void> settleIO(WidgetTester tester) async {
    // 放行 dart:io 真实异步（identity stat）— FakeAsync 不推进真实 IO
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
  }

  group('PlaylistTile thumbnail lifecycle (T1-T7)', () {
    late FakeThumbnailProvider fake;
    late Directory tempDir;
    late String pathA;
    late String pathB;

    setUp(() async {
      // 成功路径需要 Image 真解码 — 用可解码 1×1 JPEG
      fake = FakeThumbnailProvider(result: realJpegBytes);
      ThumbnailService.reset(provider: fake, diskCache: brokenDisk);
      // 真实绝对路径文件 — 相对路径在 identity 解析即被拒（X3）
      tempDir = await Directory.systemTemp.createTemp('pthumb_tile');
      pathA = p.join(tempDir.path, 'a.mp4');
      pathB = p.join(tempDir.path, 'b.mp4');
      await File(pathA).writeAsString('A' * 10);
      await File(pathB).writeAsString('B' * 10);
    });

    tearDown(() async {
      ThumbnailService.reset();
      try {
        await tempDir.delete(recursive: true);
      } on FileSystemException {
        // best effort
      }
    });

    testWidgets('T1: successful load reaches ready (no retry entry)', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(buildTile(PlaylistItem(path: pathA))));
      await settleIO(tester);

      // provider 非 null + 解码成功 → 无重试入口
      expect(find.byIcon(Icons.refresh_outlined), findsNothing);
      expect(tester.takeException(), isNull);
      // pending-timer 检查先于 tearDown — 测试体内取消启动清理 timer
      ThumbnailService.reset();
    });

    testWidgets('T2: A→B reuse — stale A result cannot surface (B wins)', (
      tester,
    ) async {
      fake.holdJobs = true;
      await tester.pumpWidget(wrap(buildTile(PlaylistItem(path: pathA))));
      await settleIO(tester); // job A 挂起

      // path A→B — didUpdateWidget 触发第二次 load（B）
      await tester.pumpWidget(wrap(buildTile(PlaylistItem(path: pathB))));
      await settleIO(tester);
      expect(fake.calls, equals(2));

      // A 晚完成（失败语义）— generation 拦截：不得进入 failed 态
      fake.failJob(pathA, const FileSystemException('late A'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.refresh_outlined), findsNothing);

      // B 完成 — 正常 ready
      fake.release(pathB);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.refresh_outlined), findsNothing);
      expect(tester.takeException(), isNull);
      ThumbnailService.reset();
    });

    testWidgets('T3: dispose before completion never setState-after-dispose', (
      tester,
    ) async {
      fake.holdJobs = true;

      await tester.pumpWidget(wrap(buildTile(PlaylistItem(path: pathA))));
      await settleIO(tester); // job 挂起

      await tester.pumpWidget(wrap(const SizedBox.shrink())); // dispose
      fake.release(pathA); // 完成晚于 dispose
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      ThumbnailService.reset();
    });

    testWidgets('T4: provider failure shows retry entry', (tester) async {
      fake.result = null; // 解帧失败 → failed phase

      await tester.pumpWidget(wrap(buildTile(PlaylistItem(path: pathA))));
      await settleIO(tester);

      expect(find.byIcon(Icons.refresh_outlined), findsOneWidget);
      ThumbnailService.reset();
    });

    testWidgets('T5: tapping retry recovers to ready', (tester) async {
      fake.result = null;
      await tester.pumpWidget(wrap(buildTile(PlaylistItem(path: pathA))));
      await settleIO(tester);
      expect(find.byIcon(Icons.refresh_outlined), findsOneWidget);

      // 修复（provider 恢复返回可解码 JPEG）→ 点重试
      fake.result = realJpegBytes;
      await tester.tap(find.byIcon(Icons.refresh_outlined));
      await settleIO(tester);

      expect(find.byIcon(Icons.refresh_outlined), findsNothing);
      expect(fake.calls, equals(2)); // 走了 ThumbnailService.retry force 路径
      ThumbnailService.reset();
    });

    testWidgets('T6: image decode error surfaces retry entry (errorBuilder)', (
      tester,
    ) async {
      // 非 JPEG 4 字节 — provider 成功（phase ready）但 Image 解码失败
      fake.result = Uint8List.fromList(const [0xFF, 0xD8, 0xFF, 0xD9]);

      await tester.pumpWidget(wrap(buildTile(PlaylistItem(path: pathA))));
      await settleIO(tester);

      // errorBuilder → post-frame 回写 decodeFailed → 重试入口可见
      expect(find.byIcon(Icons.refresh_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
      ThumbnailService.reset();
    });

    testWidgets('T7: didUpdateWidget path change triggers a fresh load', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(buildTile(PlaylistItem(path: pathA))));
      await settleIO(tester);
      expect(fake.calls, equals(1));

      await tester.pumpWidget(wrap(buildTile(PlaylistItem(path: pathB))));
      await settleIO(tester);

      // §26.0：path 变化必须触发新 load（触发器回归保护 — 契约 45）
      expect(fake.calls, equals(2));
      ThumbnailService.reset();
    });
  });
}
