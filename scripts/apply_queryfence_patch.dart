#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

/// queryFence 补丁自动应用脚本
///
/// 功能:
///   1. 从 .dart_tool/package_config.json 定位 fvp 包路径
///   2. 检查补丁是否已应用（查找标记字符串）
///   3. 如未应用，将 patches/fvp_queryfence.patch 复制到 fvp 包目录
///   4. 输出操作摘要
///
/// 用法: dart run scripts/apply_queryfence_patch.dart
/// 退出码: 0=成功/已应用, 1=错误
void main(List<String> args) async {
  final projectRoot = _findProjectRoot();
  if (projectRoot == null) {
    print('ERROR: Could not find project root (pubspec.yaml not found)');
    exit(1);
  }

  // 1. 检查补丁文件是否存在
  final patchFile = File('$projectRoot/patches/fvp_queryfence.patch');
  if (!patchFile.existsSync()) {
    print('WARNING: Patch file not found: ${patchFile.path}');
    print('Skipping — this is non-fatal. Create the patch file to apply.');
    exit(0);
  }

  // 2. 从 package_config.json 定位 fvp 包
  final packageConfig = File('$projectRoot/.dart_tool/package_config.json');
  if (!packageConfig.existsSync()) {
    print('ERROR: .dart_tool/package_config.json not found.');
    print('Run "flutter pub get" first.');
    exit(1);
  }

  final configContent = jsonDecode(packageConfig.readAsStringSync()) as Map<String, dynamic>;
  final packages = configContent['packages'] as List<dynamic>?;

  if (packages == null) {
    print('ERROR: Invalid package_config.json format');
    exit(1);
  }

  String? fvpRoot;
  for (final pkg in packages) {
    final map = pkg as Map<String, dynamic>;
    if (map['name'] == 'fvp') {
      final rootUri = map['rootUri'] as String?;
      if (rootUri != null) {
        // 处理相对路径和 file:// URI
        if (rootUri.startsWith('file://')) {
          fvpRoot = Uri.parse(rootUri).toFilePath();
        } else if (rootUri.startsWith('/')) {
          fvpRoot = rootUri;
        } else {
          fvpRoot = '${packageConfig.parent.path}/$rootUri';
        }
      }
      break;
    }
  }

  if (fvpRoot == null) {
    print('ERROR: fvp package not found in package_config.json');
    print('Run "flutter pub get" first.');
    exit(1);
  }

  print('fvp package: $fvpRoot');

  // 3. 检查补丁是否已应用
  // 补丁标记: 在目标文件中查找特定注释
  const patchMarker = '// queryFence patched';
  final targetFile = File('$fvpRoot/src/fvp_plugin.cpp');

  if (targetFile.existsSync()) {
    final content = targetFile.readAsStringSync();
    if (content.contains(patchMarker)) {
      print('SKIP: queryFence patch already applied.');
      exit(0);
    }
  }

  // 4. 应用补丁 — 将补丁文件复制到 fvp 包目录供手动参考
  final patchDest = File('$fvpRoot/queryfence.patch');
  try {
    await patchFile.copy(patchDest.path);
    print('OK: Patch file copied to: ${patchDest.path}');
    print('');
    print('To apply manually:');
    print('  1. Review the patch: ${patchDest.path}');
    print('  2. Apply changes to: ${targetFile.path}');
    print('  3. Add "$patchMarker" to the patched file');
    print('');
    print('NOTE: Automatic patching not yet implemented.');
    print('The patch content must be confirmed via D3D11 research first.');
  } on Exception catch (e) {
    print('ERROR: Failed to copy patch file: $e');
    exit(1);
  }
}

/// 向上查找包含 pubspec.yaml 的目录
String? _findProjectRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 10; i++) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return null;
}
