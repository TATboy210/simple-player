import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/features/player/file_picker_coordinator.dart';

void main() {
  group('FilePickerCoordinator', () {
    test('重复触发时只创建一个 picker 并请求已有窗口 attention', () async {
      // Arrange
      final picker = _FakeFilePickerGateway();
      final attention = _FakeFilePickerAttention();
      final player = _FakeMediaPathPlayer();
      final coordinator = FilePickerCoordinator(
        picker: picker,
        attention: attention,
        openAndPlay: player.openAndPlay,
      );

      // Act
      final firstOpen = coordinator.open();
      await Future<void>.delayed(Duration.zero);
      final duplicateOpen = coordinator.open();

      // Assert
      expect(picker.callCount, 1);
      expect(attention.callCount, 1);
      expect(coordinator.isPicking, isTrue);

      picker.complete(<String>['C:/media/one.mp4']);
      await Future.wait<void>(<Future<void>>[firstOpen, duplicateOpen]);

      expect(player.openedPaths, <String>['C:/media/one.mp4']);
      expect(coordinator.isPicking, isFalse);
    });

    test('按 picker 返回顺序串行打开多个文件', () async {
      // Arrange
      final picker = _FakeFilePickerGateway()
        ..complete(<String>[
          'C:/media/one.mp4',
          'C:/media/two.mkv',
          'C:/media/three.mp3',
        ]);
      final player = _FakeMediaPathPlayer();
      final coordinator = FilePickerCoordinator(
        picker: picker,
        attention: _FakeFilePickerAttention(),
        openAndPlay: player.openAndPlay,
      );

      // Act
      await coordinator.open();

      // Assert
      expect(player.openedPaths, <String>[
        'C:/media/one.mp4',
        'C:/media/two.mkv',
        'C:/media/three.mp3',
      ]);
      expect(player.maxConcurrentCalls, 1);
      expect(coordinator.isPicking, isFalse);
    });

    test('取消选择后释放 guard，允许后续再次打开', () async {
      // Arrange
      final picker = _FakeFilePickerGateway()..complete(null);
      final coordinator = FilePickerCoordinator(
        picker: picker,
        attention: _FakeFilePickerAttention(),
        openAndPlay: _FakeMediaPathPlayer().openAndPlay,
      );

      // Act
      await coordinator.open();
      picker.prepareNextResult();
      final retry = coordinator.open();
      await Future<void>.delayed(Duration.zero);

      // Assert
      expect(coordinator.isPicking, isTrue);
      expect(picker.callCount, 2);

      picker.complete(null);
      await retry;
      expect(coordinator.isPicking, isFalse);
    });

    test('空路径列表后释放 guard，允许后续再次打开', () async {
      // Arrange
      final picker = _FakeFilePickerGateway()..complete(<String>[]);
      final coordinator = FilePickerCoordinator(
        picker: picker,
        attention: _FakeFilePickerAttention(),
        openAndPlay: _FakeMediaPathPlayer().openAndPlay,
      );

      // Act
      await coordinator.open();
      picker.prepareNextResult();
      final retry = coordinator.open();
      await Future<void>.delayed(Duration.zero);

      // Assert
      expect(picker.callCount, 2);
      expect(coordinator.isPicking, isTrue);

      picker.complete(null);
      await retry;
      expect(coordinator.isPicking, isFalse);
    });

    test('播放失败后结束当前批次并释放 guard', () async {
      // Arrange
      final picker = _FakeFilePickerGateway()
        ..complete(<String>['C:/media/failing.mp4', 'C:/media/not-opened.mkv']);
      final openedPaths = <String>[];
      var shouldFail = true;
      final coordinator = FilePickerCoordinator(
        picker: picker,
        attention: _FakeFilePickerAttention(),
        openAndPlay: (path) async {
          openedPaths.add(path);
          if (shouldFail) {
            throw const FormatException('player rejected media');
          }
        },
      );

      // Act
      await coordinator.open();
      picker.prepareNextResult();
      shouldFail = false;
      final retry = coordinator.open();
      await Future<void>.delayed(Duration.zero);

      // Assert
      expect(openedPaths, <String>['C:/media/failing.mp4']);
      expect(coordinator.isPicking, isTrue);

      picker.complete(<String>['C:/media/retry.mp3']);
      await retry;
      expect(openedPaths, <String>[
        'C:/media/failing.mp4',
        'C:/media/retry.mp3',
      ]);
      expect(coordinator.isPicking, isFalse);
    });

    test('picker 异常后释放 guard，允许后续再次打开', () async {
      // Arrange
      final picker = _FakeFilePickerGateway()
        ..completeError(const FormatException('native picker failed'));
      final coordinator = FilePickerCoordinator(
        picker: picker,
        attention: _FakeFilePickerAttention(),
        openAndPlay: _FakeMediaPathPlayer().openAndPlay,
      );

      // Act
      await coordinator.open();
      picker.prepareNextResult();
      final retry = coordinator.open();
      await Future<void>.delayed(Duration.zero);

      // Assert
      expect(picker.callCount, 2);
      expect(coordinator.isPicking, isTrue);

      picker.complete(null);
      await retry;
      expect(coordinator.isPicking, isFalse);
    });

    test('销毁后忽略仍在进行的 picker 返回结果', () async {
      // Arrange
      final picker = _FakeFilePickerGateway();
      final player = _FakeMediaPathPlayer();
      final coordinator = FilePickerCoordinator(
        picker: picker,
        attention: _FakeFilePickerAttention(),
        openAndPlay: player.openAndPlay,
      );

      // Act
      final opening = coordinator.open();
      await Future<void>.delayed(Duration.zero);
      coordinator.dispose();
      picker.complete(<String>['C:/media/ignored.mp4']);
      await opening;

      // Assert
      expect(player.openedPaths, isEmpty);
      expect(coordinator.isPicking, isFalse);
    });

    test('多文件播放中销毁后不启动剩余路径', () async {
      // Arrange
      final picker = _FakeFilePickerGateway()
        ..complete(<String>['C:/media/playing.mp4', 'C:/media/ignored.mkv']);
      final player = _BlockingMediaPathPlayer();
      final coordinator = FilePickerCoordinator(
        picker: picker,
        attention: _FakeFilePickerAttention(),
        openAndPlay: player.openAndPlay,
      );

      // Act
      final opening = coordinator.open();
      await player.firstPlaybackStarted.future;
      coordinator.dispose();
      player.completeFirstPlayback();
      await opening;

      // Assert
      expect(player.openedPaths, <String>['C:/media/playing.mp4']);
      expect(coordinator.isPicking, isFalse);
    });

    test('attention 异常不会创建第二个 picker 或释放进行中的 guard', () async {
      // Arrange
      final picker = _FakeFilePickerGateway();
      final attention = _FakeFilePickerAttention()
        ..nextError = const FormatException('attention unavailable');
      final coordinator = FilePickerCoordinator(
        picker: picker,
        attention: attention,
        openAndPlay: _FakeMediaPathPlayer().openAndPlay,
      );

      // Act
      final firstOpen = coordinator.open();
      await Future<void>.delayed(Duration.zero);
      await coordinator.open();

      // Assert
      expect(picker.callCount, 1);
      expect(attention.callCount, 1);
      expect(coordinator.isPicking, isTrue);

      picker.complete(null);
      await firstOpen;
      expect(coordinator.isPicking, isFalse);
    });
  });
}

final class _FakeFilePickerGateway implements FilePickerGateway {
  Completer<List<String>?> _result = Completer<List<String>?>();
  int callCount = 0;

  @override
  Future<List<String>?> pickMediaPaths() {
    callCount++;
    return _result.future;
  }

  void complete(List<String>? paths) => _result.complete(paths);

  void completeError(Object error) => _result.completeError(error);

  void prepareNextResult() {
    _result = Completer<List<String>?>();
  }
}

final class _FakeFilePickerAttention implements FilePickerAttention {
  int callCount = 0;
  Object? nextError;

  @override
  Future<void> requestAttention() async {
    callCount++;
    final error = nextError;
    if (error != null) throw error;
  }
}

/// 阻塞首个播放，以便精确模拟播放进行中组件被销毁的时序。
final class _BlockingMediaPathPlayer {
  final List<String> openedPaths = <String>[];
  final Completer<void> firstPlaybackStarted = Completer<void>();
  final Completer<void> _allowFirstPlaybackToFinish = Completer<void>();

  /// 记录路径；第一项暂停至测试显式放行，后续调用无需阻塞。
  Future<void> openAndPlay(String path) async {
    openedPaths.add(path);
    if (openedPaths.length != 1) return;

    firstPlaybackStarted.complete();
    await _allowFirstPlaybackToFinish.future;
  }

  /// 放行首个播放，使协调器有机会在循环边界检查销毁状态。
  void completeFirstPlayback() {
    _allowFirstPlaybackToFinish.complete();
  }
}

final class _FakeMediaPathPlayer {
  final List<String> openedPaths = <String>[];
  int _activeCalls = 0;
  int maxConcurrentCalls = 0;

  Future<void> openAndPlay(String path) async {
    _activeCalls++;
    if (_activeCalls > maxConcurrentCalls) {
      maxConcurrentCalls = _activeCalls;
    }
    openedPaths.add(path);
    await Future<void>.delayed(Duration.zero);
    _activeCalls--;
  }
}
