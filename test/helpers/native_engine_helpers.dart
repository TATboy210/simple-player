/// native 引擎测试共用素材/等待工具 — 真实 libmpv (vo=null/ao=null) 场景.
///
/// Shared helpers for `@Tags(['native'])` engine tests: a Dart-generated
/// silent PCM WAV (exactly seekable, no codec dependency) and a notifier
/// wait utility.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// 写 [ms] 毫秒 8kHz 单声道 16-bit 静音 WAV.
File wavFile(Directory dir, String name, {int ms = 600}) {
  const rate = 8000;
  final data = rate * ms ~/ 1000 * 2;
  final b = ByteData(44 + data);
  void tag(int o, String s) {
    for (var i = 0; i < 4; i++) {
      b.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  b.setUint32(4, 36 + data, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little); // PCM
  b.setUint16(22, 1, Endian.little); // mono
  b.setUint32(24, rate, Endian.little);
  b.setUint32(28, rate * 2, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  b.setUint32(40, data, Endian.little);
  return File('${dir.path}${Platform.pathSeparator}$name')
    ..writeAsBytesSync(b.buffer.asUint8List());
}

/// 等待 notifier 满足条件 (先查当前值; 10s 超时).
Future<T> untilValue<T>(ValueListenable<T> n, bool Function(T) ok) {
  if (ok(n.value)) return Future.value(n.value);
  final c = Completer<T>();
  void l() {
    if (ok(n.value) && !c.isCompleted) c.complete(n.value);
  }

  n.addListener(l);
  return c.future
      .timeout(const Duration(seconds: 10))
      .whenComplete(() => n.removeListener(l));
}
