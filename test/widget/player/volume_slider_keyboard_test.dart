import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/volume_controls.dart';
import 'package:simple_player_flutter/ui/shared/osd_overlay.dart';

import '../../helpers/fake_engine.dart';

void main() {
  late FakeEngine engine;

  setUp(() {
    engine = FakeEngine();
  });

  tearDown(() {
    OsdService.I.hide();
    engine.dispose();
  });

  Widget buildSubject() => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: VolumeSlider(volume: engine.volume, onSetVolume: engine.setVolume),
    ),
  );

  /// Slider 生效的焦点节点 — 修复后 [VolumeSlider] 传入 State 自持节点
  /// （widget.focusNode 非空，直接取）；修复前 Slider 走内部自建节点，
  /// 从其 FocusableActionDetector 内建 Focus 上取。子树里 Shortcuts 也挂
  /// 一个 focusNode 为 null 的锚点 Focus，必须按「携带非空节点」过滤。
  /// 两种状态都能持焦，保证 RED 的失败原因落在「引擎调用未发生」而非
  /// 空指针崩溃。
  FocusNode effectiveFocusNode(WidgetTester tester) {
    final slider = tester.widget<Slider>(find.byType(Slider));
    final explicit = slider.focusNode;
    if (explicit != null) return explicit;
    final internal = tester.widget<Focus>(
      find
          .descendant(
            of: find.byType(Slider),
            matching: find.byWidgetPredicate(
              (w) => w is Focus && w.focusNode != null,
            ),
          )
          .first,
    );
    return internal.focusNode!;
  }

  group('VolumeSlider keyboard path', () {
    testWidgets('focused bare onChanged commits via throttle', (tester) async {
      engine.volume.value = 0.5;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // Material 键盘调节的回调序列只含 onChanged — 绝不调 onChangeStart/End。
      effectiveFocusNode(tester).requestFocus();
      await tester.pump();
      tester.widget<Slider>(find.byType(Slider)).onChanged!(0.7);

      // 节流窗口内不应调用引擎
      expect(engine.setVolumeCallCount, 0);

      // 推进 100ms 让共享节流定时器触发
      await tester.pump(const Duration(milliseconds: 100));
      expect(engine.setVolumeCallCount, 1);
      expect(engine.lastSetVolumeValue, 0.7);

      // Release global feedback before widget-test timer invariants. Its real
      // monotonic clock is deliberately independent of fake throttle time.
      OsdService.I.hide();
    });

    testWidgets('keyboard path clamps to slider bounds', (tester) async {
      engine.volume.value = 0.5;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // 防御纵深（威胁 T-261009fit-01）：故意送入越界值，引擎必须收到 1.0。
      effectiveFocusNode(tester).requestFocus();
      await tester.pump();
      tester.widget<Slider>(find.byType(Slider)).onChanged!(1.4);

      await tester.pump(const Duration(milliseconds: 100));
      expect(engine.setVolumeCallCount, 1);
      expect(engine.lastSetVolumeValue, 1.0);

      // Release global feedback before widget-test timer invariants. Its real
      // monotonic clock is deliberately independent of fake throttle time.
      OsdService.I.hide();
    });

    testWidgets('unfocused bare onChanged never commits', (tester) async {
      engine.volume.value = 0.5;
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // 不请求焦点 — 模拟被替换手势的残留 tearoff 直接打回回调（
      // volume_drag_feedback_test 的「captured callbacks cannot resurrect
      // a timer」契约在新键盘路径下的钉子）。
      final slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChanged?.call(0.9);
      slider.onChangeEnd?.call(0.9);

      await tester.pump(const Duration(milliseconds: 200));
      expect(
        engine.setVolumeCallCount,
        0,
        reason: '无焦点裸 onChanged 绝不提交音量',
      );
    });

    testWidgets(
      'arrow key end-to-end through Material Slider',
      (tester) async {
        engine.volume.value = 0.5;
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        // 机制先例：keyboard_handler_global_dispatch_test 的「Slider keeps
        // arrow-key adjustment while focused」（focusNode + sendKeyDownEvent
        // → onChanged 触发），照抄该编排。
        effectiveFocusNode(tester).requestFocus();
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);

        await tester.pump(const Duration(milliseconds: 100));
        expect(engine.setVolumeCallCount, 1);
        expect(engine.lastSetVolumeValue, greaterThan(0.5));
        expect(engine.lastSetVolumeValue, lessThanOrEqualTo(1.0));

        // Release global feedback before widget-test timer invariants. Its real
        // monotonic clock is deliberately independent of fake throttle time.
        OsdService.I.hide();
      },
    );
  });
}
