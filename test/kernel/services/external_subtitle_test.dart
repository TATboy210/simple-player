import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/services/playback_controller.dart';
import 'package:simple_player_flutter/kernel/services/subtitle_service.dart';

import '../../helpers/fake_engine.dart';

/// 在真实目录扫描结束时发出信号，避免测试依赖固定延迟等待后台字幕任务。
class _CompletingSubtitleService extends SubtitleService {
  _CompletingSubtitleService(super.engine);

  final Completer<void> _completed = Completer<void>();

  Future<void> get completed => _completed.future;

  @override
  Future<void> detectAndLoad(String mediaPath) async {
    await super.detectAndLoad(mediaPath);
    if (!_completed.isCompleted) _completed.complete();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  late FakeEngine engine;
  late PlaybackController controller;
  late _CompletingSubtitleService subtitleService;
  late Directory tempDir;

  setUp(() {
    // State manager disposal persists settings; provide the platform seam here
    // so these filesystem-focused tests remain independent of host plugins.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getApplicationSupportDirectory') {
              return Directory.systemTemp.createTempSync('app_support').path;
            }
            return null;
          },
        );
    SharedPreferences.setMockInitialValues({});

    engine = FakeEngine()..configureMedia(durationMs: 60000);
    subtitleService = _CompletingSubtitleService(engine);
    controller = PlaybackController(
      engine: engine,
      onError: (_) {},
      subtitleService: subtitleService,
    );
    tempDir = Directory.systemTemp.createTempSync('subtitle_test_');
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    controller.dispose();
    engine.dispose();
    tempDir.deleteSync(recursive: true);
  });

  /// Creates a fixture file inside the temporary media directory.
  File createFile(String name, [String content = '']) {
    final file = File('${tempDir.path}/$name');
    file.writeAsStringSync(content);
    return file;
  }

  /// Opens [mediaPath] through the public controller boundary and waits until
  /// its intentionally detached subtitle scan completes.
  Future<void> openAndWaitForSubtitleScan(String mediaPath) async {
    expect(await controller.openAndPlay(mediaPath), isTrue);
    await subtitleService.completed;
  }

  group('External subtitle auto-detection', () {
    test('detects .srt file with matching base name', () async {
      final media = createFile('video.mp4');
      createFile('video.srt');

      await openAndWaitForSubtitleScan(media.path);

      expect(engine.setExternalSubtitleCallCount, 1);
      expect(engine.lastExternalSubtitlePath, contains('video.srt'));
    });

    test('detects .ass file with matching base name', () async {
      final media = createFile('movie.mp4');
      createFile('movie.ass');

      await openAndWaitForSubtitleScan(media.path);

      expect(engine.setExternalSubtitleCallCount, 1);
      expect(engine.lastExternalSubtitlePath, contains('movie.ass'));
    });

    test('detects .ssa file with matching base name', () async {
      final media = createFile('film.mkv');
      createFile('film.ssa');

      await openAndWaitForSubtitleScan(media.path);

      expect(engine.setExternalSubtitleCallCount, 1);
      expect(engine.lastExternalSubtitlePath, contains('film.ssa'));
    });

    test('detects .vtt file with matching base name', () async {
      final media = createFile('clip.mp4');
      createFile('clip.vtt');

      await openAndWaitForSubtitleScan(media.path);

      expect(engine.setExternalSubtitleCallCount, 1);
      expect(engine.lastExternalSubtitlePath, contains('clip.vtt'));
    });

    test('detects subtitle with language tag', () async {
      final media = createFile('movie.mp4');
      createFile('movie.en.srt');

      await openAndWaitForSubtitleScan(media.path);

      expect(engine.setExternalSubtitleCallCount, 1);
      expect(engine.lastExternalSubtitlePath, contains('movie.en.srt'));
    });

    test('ignores subtitle files with different base name', () async {
      final media = createFile('video.mp4');
      createFile('other.srt');

      await openAndWaitForSubtitleScan(media.path);

      expect(engine.setExternalSubtitleCallCount, 0);
    });

    test('ignores non-subtitle extensions', () async {
      final media = createFile('video.mp4');
      createFile('video.txt');

      await openAndWaitForSubtitleScan(media.path);

      expect(engine.setExternalSubtitleCallCount, 0);
    });

    test('handles missing directory without blocking playback', () async {
      const missingMediaPath = 'Z:/nonexistent/path/video.mp4';

      await openAndWaitForSubtitleScan(missingMediaPath);

      expect(engine.setExternalSubtitleCallCount, 0);
      expect(engine.playCallCount, 1);
    });

    test('loads only the first matching subtitle', () async {
      final media = createFile('video.mp4');
      createFile('video.srt');
      createFile('video.ass');

      await openAndWaitForSubtitleScan(media.path);

      expect(engine.setExternalSubtitleCallCount, 1);
    });
  });
}
