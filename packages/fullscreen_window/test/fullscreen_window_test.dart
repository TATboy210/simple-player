import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fullscreen_window/fullscreen_window_platform_interface.dart';
import 'package:fullscreen_window/fullscreen_window_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFullscreenWindowPlatform extends FullScreenWindowPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<void> setFullScreen(bool isFullScreen) async {}

  @override
  Future<Size> getScreenSize(BuildContext? context) async {
    return const Size(1920, 1080);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final FullScreenWindowPlatform initialPlatform =
      FullScreenWindowPlatform.instance;

  test('默认实例是 MethodChannelFullscreenWindow', () {
    expect(initialPlatform, isA<MethodChannelFullscreenWindow>());
  });

  test('可以通过 setter 替换平台实例', () {
    final mock = MockFullscreenWindowPlatform();
    FullScreenWindowPlatform.instance = mock;
    expect(
        FullScreenWindowPlatform.instance, isA<MockFullscreenWindowPlatform>());
  });

  test('替换后可以恢复默认实例', () {
    final mock = MockFullscreenWindowPlatform();
    FullScreenWindowPlatform.instance = mock;
    expect(
        FullScreenWindowPlatform.instance, isA<MockFullscreenWindowPlatform>());

    FullScreenWindowPlatform.instance = initialPlatform;
    expect(FullScreenWindowPlatform.instance,
        isA<MethodChannelFullscreenWindow>());
  });
}
