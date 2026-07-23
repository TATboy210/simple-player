// PendingSettingsState 单元测试 — 覆盖 TABS-04 延迟应用状态管理。
//
// 纯 Dart 测试，无 Flutter 依赖。

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/pending_settings.dart';

void main() {
  group('PendingSettingsState', () {
    late PendingSettingsState pending;

    setUp(() {
      pending = PendingSettingsState();
    });

    tearDown(() {
      pending.dispose();
    });

    test('register stores original value', () {
      // Act
      pending.register('locale', 'zh');

      // Assert
      expect(pending.current('locale'), 'zh');
    });

    test('update stores pending value', () {
      // Arrange
      pending.register('locale', 'zh');

      // Act
      pending.update('locale', 'en');

      // Assert
      expect(pending.current('locale'), 'en');
    });

    test('current returns original when no pending value exists', () {
      // Arrange
      pending.register('themeIndex', 0);

      // Assert — no update, so returns original
      expect(pending.current('themeIndex'), 0);
    });

    test('current returns pending when available', () {
      // Arrange
      pending.register('themeIndex', 0);
      pending.update('themeIndex', 2);

      // Assert
      expect(pending.current('themeIndex'), 2);
    });

    test('hasChanges is true after update, false initially', () {
      // Assert — initially false
      expect(pending.hasChanges, isFalse);

      // Act
      pending.update('locale', 'en');

      // Assert — true after update
      expect(pending.hasChanges, isTrue);
    });

    test('hasChanges is false after commit', () {
      // Arrange
      pending.register('locale', 'zh');
      pending.update('locale', 'en');

      // Act
      pending.commit();

      // Assert
      expect(pending.hasChanges, isFalse);
    });

    test('hasChanges is false after cancel', () {
      // Arrange
      pending.register('locale', 'zh');
      pending.update('locale', 'en');

      // Act
      pending.cancel();

      // Assert
      expect(pending.hasChanges, isFalse);
    });

    test('commit returns pending map', () {
      // Arrange
      pending.register('locale', 'zh');
      pending.register('themeIndex', 0);
      pending.update('locale', 'en');
      pending.update('themeIndex', 2);

      // Act
      final changes = pending.commit();

      // Assert
      expect(changes, {'locale': 'en', 'themeIndex': 2});
    });

    test('commit updates originals for Apply-then-Cancel', () {
      // Arrange — register originals
      pending.register('locale', 'zh');
      pending.update('locale', 'en');

      // Act — Apply (commit)
      pending.commit();

      // Assert — current returns committed value
      expect(pending.current('locale'), 'en');

      // Act — now Cancel
      final originals = pending.cancel();

      // Assert — cancel returns committed values (not first register)
      expect(originals['locale'], 'en');
      expect(pending.current('locale'), 'en');
    });

    test('cancel returns originals and clears pending', () {
      // Arrange
      pending.register('locale', 'zh');
      pending.update('locale', 'en');

      // Act
      final originals = pending.cancel();

      // Assert
      expect(originals, {'locale': 'zh'});
      expect(pending.current('locale'), 'zh');
      expect(pending.hasChanges, isFalse);
    });

    test('dispose clears both maps', () {
      // Arrange
      pending.register('locale', 'zh');
      pending.update('locale', 'en');

      // Act
      pending.dispose();

      // Assert — after dispose, current returns null (maps cleared)
      expect(pending.current('locale'), isNull);
      expect(pending.hasChanges, isFalse);
    });

    test('empty state: commit on no-changes returns empty map', () {
      // Act
      final changes = pending.commit();

      // Assert
      expect(changes, isEmpty);
    });

    test('empty state: cancel on no-changes returns empty map', () {
      // Act
      final originals = pending.cancel();

      // Assert
      expect(originals, isEmpty);
    });

    test('register overwrites existing key (idempotent open)', () {
      // Arrange
      pending.register('locale', 'zh');
      pending.register('locale', 'en');

      // Assert — last register wins
      expect(pending.current('locale'), 'en');
    });
  });
}
