import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/services/playback_controller.dart';
import 'package:simple_player_flutter/kernel/playlist/playlist.dart';
import '../../helpers/fake_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeEngine engine;
  late Playlist playlist;
  late PlaybackController controller;
  int rebuildCount = 0;

  setUp(() {
    engine = FakeEngine();
    playlist = Playlist();
    rebuildCount = 0;
    controller = PlaybackController(
      engine: engine,
      playlist: playlist,
      onNeedRebuild: () => rebuildCount++,
    );
  });

  tearDown(() {
    controller.dispose();
    engine.dispose();
  });

  group('FileOperations', () {
    group('openAndPlay', () {
      test('rejects empty path and sets validationError', () async {
        final result = await controller.openAndPlay('');
        expect(result, false);
        expect(controller.validationError.value, isNotNull);
        expect(playlist.isEmpty, true);
      });

      test('rejects path traversal attempt', () async {
        final result =
            await controller.openAndPlay('C:/test/../../../etc/passwd.mp4');
        expect(result, false);
        expect(controller.validationError.value, contains('不安全'));
      });

      test('rejects unsupported extension', () async {
        final result = await controller.openAndPlay('C:/test/file.txt');
        expect(result, false);
        expect(controller.validationError.value, contains('不支持'));
      });

      test('clears validationError on success', () async {
        engine.configureMedia(durationMs: 60000);
        controller.validationError.value = 'previous error';
        final result = await controller.openAndPlay('C:/test/video.mp4');
        await Future(() {});
        expect(result, true);
        expect(controller.validationError.value, isNull);
      });

      test('reuses existing index if file already in playlist', () async {
        engine.configureMedia(durationMs: 60000);
        await controller.openAndPlay('C:/test/a.mp4');
        await Future(() {});
        expect(playlist.length, 1);
        final result = await controller.openAndPlay('C:/test/a.mp4');
        expect(result, true);
        expect(playlist.length, 1);
        expect(engine.openCallCount, 2); // opened twice for each play
      });
    });

    group('addFiles', () {
      test('returns 0 for all-invalid paths', () async {
        final count =
            await controller.addFiles(['', 'bad.txt', '../hack.mp4']);
        expect(count, 0);
        expect(playlist.isEmpty, true);
      });

      test('deduplicates against existing playlist items', () async {
        engine.configureMedia(durationMs: 60000);
        await controller.addFiles(['C:/a.mp4']);
        await Future(() {});
        final count = await controller.addFiles(['C:/a.mp4', 'C:/b.mp4']);
        expect(count, 1);
        expect(playlist.length, 2);
      });

      test('triggers onNeedRebuild after adding files', () async {
        engine.configureMedia(durationMs: 60000);
        rebuildCount = 0;
        await controller.addFiles(['C:/a.mp4', 'C:/b.mp4']);
        expect(rebuildCount, greaterThanOrEqualTo(1));
      });
    });
  });
}
