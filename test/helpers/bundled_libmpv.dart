import 'dart:io';

import 'package:mpv_kit_video/mpv_kit_video.dart' show MpvLibrary;

/// 测试进程加载 mpv_kit_libs 构建钩子下载的 libmpv — 不依赖系统 mpv.
///
/// `flutter test` 跑完构建钩子后, libmpv 解压在钩子共享缓存
/// `.dart_tool/hooks_runner/shared/mpv_kit_libs/build/<tag>/<target>/lib/`,
/// 但 Linux/macOS 的动态加载器不搜索该目录 (Windows 偶然经 DLL 搜索序
/// 找到). 这里按平台库名显式定位并交给 [MpvLibrary.open] 缓存, 之后
/// Player 构造复用同一实例. 刻意不回退到系统 libmpv: CI 不装 libmpv-dev,
/// 测试必须证明随包库自给自足 — 找不到时 MpvLibrary 照常抛出.
///
/// 多个 tag 并存时取修改时间最新的 (pubspec 升级后旧缓存会残留).
void loadBundledLibmpvForTests() {
  final root = Directory('.dart_tool/hooks_runner/shared/mpv_kit_libs/build');
  final names = MpvLibrary.defaultNames.map((n) => n.split('/').last).toSet();
  final candidates = root.existsSync()
      ? root
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .where((f) => names.contains(f.uri.pathSegments.last))
            .toList()
      : <File>[];
  candidates.sort(
    (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
  );
  MpvLibrary.open(path: candidates.isEmpty ? null : candidates.first.path);
}
