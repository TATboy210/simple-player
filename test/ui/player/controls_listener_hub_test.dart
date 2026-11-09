import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/player/controls_listener_hub.dart';

void main() {
  group('ControlsListenerHub', () {
    test('多源槽位只挂一个回调，任一源变化触发一次', () {
      final a = ValueNotifier<int>(0);
      final b = ValueNotifier<int>(0);
      var calls = 0;
      final hub = ControlsListenerHub();
      hub.bind(ControlsSlot.hold, [a, null, b], () => calls++);
      hub.attach();

      a.value = 1;
      b.value = 1;

      expect(calls, 2);
      hub.detach();
      a.dispose();
      b.dispose();
    });

    test('源 identity 未变时 bind 幂等返回 false 且不重复挂接', () {
      final a = ValueNotifier<int>(0);
      var calls = 0;
      void cb() => calls++;
      final hub = ControlsListenerHub()..attach();

      expect(hub.bind(ControlsSlot.mode, [a], cb), isTrue);
      expect(hub.bind(ControlsSlot.mode, [a], cb), isFalse);
      a.value = 1;

      expect(calls, 1);
      hub.detach();
      a.dispose();
    });

    test('源替换时解除旧源并接新源', () {
      final oldSource = ValueNotifier<int>(0);
      final newSource = ValueNotifier<int>(0);
      var calls = 0;
      void cb() => calls++;
      final hub = ControlsListenerHub()..attach();
      hub.bind(ControlsSlot.resize, [oldSource], cb);

      expect(hub.bind(ControlsSlot.resize, [newSource], cb), isTrue);
      oldSource.value = 1;
      expect(calls, 0);
      newSource.value = 1;
      expect(calls, 1);

      hub.detach();
      oldSource.dispose();
      newSource.dispose();
    });

    test('detach 期间只记录源，attach 后统一挂接', () {
      final a = ValueNotifier<int>(0);
      var calls = 0;
      final hub = ControlsListenerHub();

      hub.bind(ControlsSlot.media, [a], () => calls++);
      a.value = 1;
      expect(calls, 0, reason: '未 attach 不应监听');

      hub.attach();
      a.value = 2;
      expect(calls, 1);

      hub.detach();
      a.value = 3;
      expect(calls, 1, reason: 'detach 后不再监听');
      expect(hub.isAttached, isFalse);
      a.dispose();
    });

    test('mergeNonNull 全空返回 null，sameSources 逐项 identity 比较', () {
      final a = ValueNotifier<int>(0);
      expect(mergeNonNull([null, null]), isNull);
      expect(mergeNonNull([a, null]), isNotNull);
      expect(sameSources([a, null], [a, null]), isTrue);
      expect(sameSources([a], [ValueNotifier<int>(0)]), isFalse);
      expect(sameSources([a], [a, null]), isFalse);
      a.dispose();
    });
  });
}
