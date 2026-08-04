import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/player/player_video_controls.dart';

import '../../helpers/fake_engine.dart';
import '../../helpers/fake_player_controls.dart';

/// 路径B 阶段1 核心闭环测试 — [PlayerControlsState] 订阅 [PlayerPort] stream
/// 转写为 ValueNotifier + 纯播放控制直写 port + volume/mute 写走 engine。
///
/// 8 个测试覆盖: init 快照 / playOrPause / seek 乐观更新 / setVolume 走 engine /
/// setRate / stream.playing 推送 / stream.position 推送 / stream.volume 转 0-1。
void main() {
  late FakeEngine engine;
  late FakePlayerControls port;
  late PlayerControlsState state;

  setUp(() {
    engine = FakeEngine();
    port = FakePlayerControls();
    state = PlayerControlsState(port, engine: engine);
    state.init();
  });

  tearDown(() {
    state.dispose();
    port.dispose();
    engine.dispose();
  });

  // 1. init 从 port 快照初始化 isPlaying 与 volume01
  test('init 从 port 快照初始化 isPlaying 与 volume01', () {
    // 默认 FakePlayerControls: isPlayingNow=false, volumeNow=100 → volume01=1.0
    expect(state.isPlaying.value, false);
    expect(state.volume01.value, 1.0);
  });

  // 2. playOrPause 直写 port(路径B 跳过 engine 中间层)
  test('playOrPause 直写 port(路径B)', () {
    state.playOrPause();
    expect(port.playOrPauseCallCount, 1);
  });

  // 3. seek 乐观更新 positionMs 再调 port.seek — 让 seek-hold 立即到达容差
  test('seek 乐观更新 positionMs 再调 port.seek', () {
    state.durationMs.value = 60000;
    state.seek(5000);
    expect(port.lastSeekPosition, const Duration(milliseconds: 5000));
    expect(state.positionMs.value, 5000); // 乐观更新立即生效,不等 stream
  });

  // 4. setVolume 写走 engine(保 _preMuteVolume 语义),不写 port
  test('setVolume 写走 engine,不写 port', () {
    state.setVolume(0.5);
    expect(engine.setVolumeCallCount, 1);
    expect(engine.lastSetVolumeValue, 0.5);
  });

  // 5. setRate 直写 port
  test('setRate 直写 port', () {
    state.setRate(2.0);
    expect(port.setRateCallCount, 1);
    expect(port.lastRate, 2.0);
  });

  // 6. stream.playing 推送 → isPlaying 更新(驱动播放/暂停图标)
  test('stream.playing 推送 → isPlaying 更新(驱动图标)', () async {
    port.emitPlaying(true);
    await Future<void>.delayed(Duration.zero);
    expect(state.isPlaying.value, true);
  });

  // 7. stream.position 推送 → positionMs 更新(驱动进度条)
  test('stream.position 推送 → positionMs 更新(驱动进度)', () async {
    port.emitPosition(const Duration(milliseconds: 3000));
    await Future<void>.delayed(Duration.zero);
    expect(state.positionMs.value, 3000);
  });

  // 8. stream.volume(0-100) 推送 → volume01(0-1) 转换
  test('stream.volume(0-100) 推送 → volume01(0-1) 转换', () async {
    port.emitVolume(75.0);
    await Future<void>.delayed(Duration.zero);
    expect(state.volume01.value, closeTo(0.75, 1e-9));
  });
}
