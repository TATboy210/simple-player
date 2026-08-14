import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/scanner/folder_scanner.dart';

/// FolderScanner 单元测试 — 覆盖扫描行为与 async 化后的边界条件
///
/// 重点回归保护：
///   - 非递归：子目录内的视频文件不应出现在结果中
///   - 扩展名大小写不敏感
///   - 不存在的目录返回空列表（不抛异常）
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('folder_scanner_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('FolderScanner.scan', () {
    test('returns empty list for non-existent directory', () async {
      // 不存在的路径必须优雅返回空列表，而非抛异常
      final result = await FolderScanner.scan('${tempDir.path}/does_not_exist');
      expect(result, isEmpty);
    });

    test('returns empty list for empty directory', () async {
      final result = await FolderScanner.scan(tempDir.path);
      expect(result, isEmpty);
    });

    test('discovers supported video files in directory', () async {
      await File('${tempDir.path}/movie.mp4').create();
      await File('${tempDir.path}/clip.mkv').create();
      await File('${tempDir.path}/clip.webm').create();

      final result = await FolderScanner.scan(tempDir.path);

      expect(result.length, 3);
      // 每项必须是 VideoFile 且 folderPath 指向扫描目录
      for (final vf in result) {
        expect(vf.folderPath, tempDir.path);
        expect(vf.path, startsWith(tempDir.path));
      }
    });

    test('ignores non-video files', () async {
      await File('${tempDir.path}/movie.mp4').create();
      await File('${tempDir.path}/readme.txt').create();
      await File('${tempDir.path}/cover.jpg').create();
      await File('${tempDir.path}/notes.md').create();

      final result = await FolderScanner.scan(tempDir.path);

      expect(result.length, 1);
      expect(result.first.name, 'movie.mp4');
    });

    test('extension match is case-insensitive', () async {
      await File('${tempDir.path}/A.MP4').create();
      await File('${tempDir.path}/B.Mkv').create();

      final result = await FolderScanner.scan(tempDir.path);

      // 扩展名大小写不敏感 — Windows 文件系统不区分大小写
      expect(result.length, 2);
    });

    test('results are sorted by file name ascending', () async {
      await File('${tempDir.path}/c.mp4').create();
      await File('${tempDir.path}/a.mp4').create();
      await File('${tempDir.path}/b.mp4').create();

      final result = await FolderScanner.scan(tempDir.path);

      expect(result.map((vf) => vf.name).toList(), ['a.mp4', 'b.mp4', 'c.mp4']);
    });

    test('is non-recursive — ignores videos in subdirectories', () async {
      await File('${tempDir.path}/top.mp4').create();

      // 子目录内的视频文件不应被扫描到（非递归扫描）
      final subdir = Directory('${tempDir.path}/sub');
      await subdir.create();
      await File('${subdir.path}/nested.mp4').create();

      final result = await FolderScanner.scan(tempDir.path);

      expect(result.length, 1);
      expect(result.first.name, 'top.mp4');
    });

    test('VideoFile.name is basename, path is absolute', () async {
      await File('${tempDir.path}/movie.mp4').create();

      final result = await FolderScanner.scan(tempDir.path);

      expect(result.length, 1);
      final vf = result.first;
      expect(vf.name, 'movie.mp4');
      // path 必须是完整绝对路径，name 是 basename
      expect(vf.path, vf.folderPath + Platform.pathSeparator + vf.name);
    });
  });

  group('FolderScanner.directoryOf', () {
    test('returns parent directory of file path', () {
      final parent = FolderScanner.directoryOf('/a/b/c.mp4');
      expect(parent, '/a/b');
    });

    test('handles path without separator', () {
      // 根目录下的文件 — dirname 返回 '.'
      final parent = FolderScanner.directoryOf('c.mp4');
      expect(parent, '.');
    });
  });
}
