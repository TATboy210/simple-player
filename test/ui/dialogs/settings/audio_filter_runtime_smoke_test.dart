/// audio_filter_runtime_smoke_test.dart — Phase 33 Wave 0 运行时可用性冒烟检查。
///
/// **TARGET WINDOWS ONLY — 不要在 headless 环境运行。**
/// Headless `flutter test` 无 mdk.dll FFI 加载（见 memory
/// reference_mdk_dll_headless_test_failures），engine.open 会失败，此测试会
/// 误报。仅在目标 Windows 真机运行：
///   D:/flutter/bin/flutter test \
///     test/ui/dialogs/settings/audio_filter_runtime_smoke_test.dart --concurrency=1
///
/// 目的：在真实 fvp/MDK 运行时上，经现有 `setEqualizer(String)` 入口探测
/// pan/adelay/dynaudnorm 三滤镜的调用是否被接受（不抛异常→probe 标记可用），
/// 并验证 mdk.dll 可用 + engine.open 解码管线正常。
///
/// **重要局限**：FvpEngine.setEqualizer 内部经 _guardedAction 守卫（try-catch+
/// log），可恢复 Exception 被**静默吞掉**。因此 probe 即使在 MDK 拒绝某滤镜时
/// 仍可能返回 true。本测试通过仅证明"调用不崩 + 环境正常（mdk.dll 可用、
/// open 成功）"，**不证明滤镜在听感上真实生效**。滤镜应用的权威验证是
/// 人工听觉检查（Phase 33 运行时门）：用户在真机依次应用 pan/adelay/dynaudnorm
/// 并确认听感变化。仅在 3 个滤镜都听感生效时，Phase 33 方算完成（不允许
/// 部分遗漏——任何不可用须在完成前找到等效受支持路径）。
library;

import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/fvp_engine.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/audio_filter_compositor.dart';

/// fvp 纹理创建通道（镜像 fvp_engine_contract_test.dart 的 mock）。
///
/// Headless 无原生 fvp 通道处理器，CreateRT/ReleaseRT 会抛
/// MissingPluginException 导致 open 失败；此 mock 返回虚假纹理 id 绕过
/// 纹理注册 RPC，不动 FvpEngine/mdk 解码管线。
const _fvpChannel = MethodChannel('fvp');
int _nextFakeTextureId = 1;

void _installFvpTextureChannelMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_fvpChannel, (call) async {
    switch (call.method) {
      case 'CreateRT':
        return _nextFakeTextureId++;
      case 'ReleaseRT':
        return null;
      default:
        return null;
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _installFvpTextureChannelMock();

  /// 测试媒体路径——可用 AUDIO_SMOKE_MEDIA 环境变量覆盖（绝对路径）。
  final mediaPath =
      Platform.environment['AUDIO_SMOKE_MEDIA'] ?? 'test/fixtures/tiny_valid.mp4';

  test(
    'FvpEngine opens test media + probe reports pan/adelay/dynaudnorm callable',
    () async {
      final engine = FvpEngine();
      addTearDown(engine.dispose);

      // 1. open 测试媒体——验证 mdk.dll 可用 + 解码管线正常（target Windows）。
      //    headless 环境此处会因 mdk.dll FFI 加载失败而抛，故本测试仅限真机。
      await engine.open(mediaPath);

      // 2. 经现有 setEqualizer 入口探测 3 滤镜调用是否被接受（不抛异常）。
      //    注意：_guardedAction 会吞掉 MDK 拒绝异常，故全 true 不保证听感生效。
      final availability = AudioFilterAvailability.probe(
        applyFilter: engine.setEqualizer,
      );

      // 3. probe 全 true = 调用不崩 + 运行时基线建立。听感验证靠人工（见文件头）。
      expect(availability.pan, isTrue, reason: 'pan filter callable');
      expect(availability.adelay, isTrue, reason: 'adelay filter callable');
      expect(
        availability.dynaudnorm,
        isTrue,
        reason: 'dynaudnorm filter callable',
      );
    },
  );
}
