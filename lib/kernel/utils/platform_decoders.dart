import 'dart:io';

import 'package:flutter/foundation.dart';

/// 根据平台和架构返回最优硬件解码器列表。
///
/// 返回 null 表示使用 fvp 默认配置。
List<String>? getOptimalDecoders() {
  final isArm = _isArmArchitecture();
  return switch (defaultTargetPlatform) {
    TargetPlatform.windows => isArm
        ? ['MFT:d3d=11', 'D3D11:shader_resource=1', 'FFmpeg']
        : ['MFT:d3d=11', 'NVDEC', 'D3D11:shader_resource=1', 'FFmpeg'],
    TargetPlatform.linux => isArm
        ? ['V4L2M2M', 'RKMPP', 'VAAPI', 'FFmpeg']
        : ['VAAPI', 'VDPAU', 'NVDEC', 'FFmpeg'],
    TargetPlatform.macOS => ['VT', 'FFmpeg'],
    _ => null,
  };
}

bool _isArmArchitecture() {
  final arch = Platform.version.toLowerCase();
  return arch.contains('arm') || arch.contains('aarch64');
}
