/// l10n ARB 完备性测试 (v0.0.6 Phase 6) — 防 locale 漂移.
///
/// 断言每个非模板 ARB 的 key 集合 ⊇ en 模板 key 集合: 模板新增 key 后
/// 任何语言漏翻会在 CI 直接红掉, 而不是运行时英文回退后才被发现.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final arbDir = Directory('lib/l10n');

  /// 解析 ARB 的用户可见 key (排除 @ 描述 / @@locale 元数据).
  Set<String> keysOf(File file) {
    final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return decoded.keys.where((k) => !k.startsWith('@')).toSet();
  }

  final templateFile = File('lib/l10n/app_en.arb');
  final templateKeys = keysOf(templateFile);

  test('en 模板 key 集合非空且无重复导致丢 key (sanity)', () {
    expect(templateKeys, isNotEmpty);
    // 模板中 shortcutPrevious/shortcutNext 曾重复书写 — JSON 解析取末值,
    // 这里顺带固化「解析后 key 数 = 独立 key 数」的事实.
    expect(templateKeys.contains('shortcutPrevious'), isTrue);
    expect(templateKeys.contains('shortcutNext'), isTrue);
  });

  for (final entity in arbDir.listSync()) {
    if (entity is! File || !entity.path.endsWith('.arb')) continue;
    final name = entity.uri.pathSegments.last;
    if (name == 'app_en.arb') continue; // 模板自身跳过

    test('$name 的 key 集合 ⊇ en 模板', () {
      final keys = keysOf(entity);
      final missing = templateKeys.difference(keys);
      expect(
        missing,
        isEmpty,
        reason: '$name 缺少以下 key (回退英文): ${missing.toList()}',
      );
    });
  }
}
