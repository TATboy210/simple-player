import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/player/controls_subtitle_padding.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';

import '../../helpers/fake_video_controls.dart';

void main() {
  const inset = EdgeInsets.only(
    bottom: Tokens.controlBarHeight + Tokens.controlBarMarginBottom,
  );

  testWidgets('控制栏可见时叠加 inset，隐藏时恢复基础值，重复值不空写', (tester) async {
    final video = FakeVideoControlsPort(
      subtitlePadding: const EdgeInsets.all(4),
    );
    final visible = ValueNotifier<bool>(true);
    var alive = true;
    final sync = SubtitlePaddingSync(
      readVideo: () => video,
      barVisible: visible,
      canWrite: () => alive,
    );
    addTearDown(() {
      visible.dispose();
      video.dispose();
    });

    sync.sync();
    sync.sync(); // 值未变 → 空写守卫
    expect(video.subtitlePaddingCallCount, 1);
    expect(video.lastSubtitlePadding, const EdgeInsets.all(4) + inset);

    visible.value = false;
    sync.sync();
    expect(video.lastSubtitlePadding, const EdgeInsets.all(4));
    expect(video.subtitlePaddingCallCount, 2);

    alive = false;
    visible.value = true;
    sync.sync();
    expect(video.subtitlePaddingCallCount, 2, reason: 'deactivate 后不写端口');
  });

  testWidgets('resetGuard 允许一次值相同的重放，resetForNewPort 重读基础值', (tester) async {
    final video = FakeVideoControlsPort();
    final visible = ValueNotifier<bool>(false);
    final sync = SubtitlePaddingSync(
      readVideo: () => video,
      barVisible: visible,
      canWrite: () => true,
    );
    addTearDown(() {
      visible.dispose();
      video.dispose();
    });

    sync.sync();
    sync.sync();
    expect(video.subtitlePaddingCallCount, 1);

    sync.resetGuard();
    sync.sync();
    expect(video.subtitlePaddingCallCount, 2);

    video.subtitlePadding = const EdgeInsets.all(9);
    sync.resetForNewPort();
    sync.sync();
    expect(video.lastSubtitlePadding, const EdgeInsets.all(9));
  });

  testWidgets('端口未挂载时跳过；schedule 在 idle 阶段立即同步', (tester) async {
    final video = FakeVideoControlsPort(isMounted: false);
    final visible = ValueNotifier<bool>(true);
    final sync = SubtitlePaddingSync(
      readVideo: () => video,
      barVisible: visible,
      canWrite: () => true,
    );
    addTearDown(() {
      visible.dispose();
      video.dispose();
    });

    sync.schedule();
    expect(video.subtitlePaddingCallCount, 0);

    video.isMounted = true;
    sync.schedule();
    expect(video.subtitlePaddingCallCount, 1);
  });
}
