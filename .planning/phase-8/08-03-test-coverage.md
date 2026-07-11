# 08-03: 测试覆盖率提升 — 补充 4 个测试缺口

## Context

逆向分析发现 4 个测试缺口:
- **TEST-01**: BusyTransition — 命令队列 busy 时拒绝新请求
- **TEST-02**: ForcedChange — 状态不一致时强制修正
- **TEST-03**: SyncCorrected — 修正后发出 SyncCorrected 事件
- **TEST-04**: DisplayEnumerator — 多显示器枚举

## 长期记忆约束

- **测试 Flakiness** [[reference_flutter_test_flakiness]]: 避免 timeout 依赖，用 Completer 同步
- **Singleton 重构** [[feedback_singleton_refactoring]]: 测试中用唯一 controller 名称
- **Comment while coding** [[feedback_comment_while_coding]]: 测试也要注释 *what* 和 *why*

## Task 1: TEST-01 — BusyTransition 测试

**文件**: `test/kernel/bridge/fullscreen_command_queue_test.dart`

**场景**: 命令队列 busy 时（有 in-flight 请求），新请求应被拒绝或排队。

```dart
test('rejects new command when queue is busy', () async {
  // Arrange: 入队一个慢命令（不完成 Completer）
  final slowCompleter = Completer<void>();
  queue.enqueue(
    FullscreenRequest.enter(windowId: 0),
    (_) => slowCompleter.future,
    currentFullscreen: false,
  );

  // Act: 在第一个命令完成前入队第二个
  final result = await queue.enqueue(
    FullscreenRequest.enter(windowId: 0),
    (_) async {},
    currentFullscreen: false,
  );

  // Assert: 第二个命令被合并或拒绝
  expect(result, isFalse);
});
```

## Task 2: TEST-02 — ForcedChange 测试

**文件**: `test/kernel/bridge/desktop_fullscreen_adapter_test.dart`

**场景**: 当 adapter 状态与驱动实际状态不一致时，应强制修正。

```dart
test('forces state correction when desync detected', () async {
  // Arrange: mock 驱动报告 fullscreen=true，但 adapter 状态为 windowed
  when(() => mockDriver.queryFullscreen()).thenAnswer((_) async => true);

  // Act: 触发状态检查
  await adapter.setFullscreen(false);

  // Assert: snapshot 被修正为实际状态
  final snapshot = adapter.snapshot(0).value;
  expect(snapshot.effectiveMode, FullscreenMode.borderless);
  expect(snapshot.phase, FullscreenPhase.error);
});
```

## Task 3: TEST-03 — SyncCorrected 事件测试

**文件**: `test/kernel/bridge/desktop_fullscreen_adapter_test.dart`

**场景**: 状态修正后应发出 `FullscreenEvent.syncCorrected` 事件。

```dart
test('emits SyncCorrected event after state correction', () async {
  // Arrange
  final events = <FullscreenEvent>[];
  adapter.events.listen(events.add);
  when(() => mockDriver.queryFullscreen()).thenAnswer((_) async => true);

  // Act
  await adapter.setFullscreen(false);

  // Assert: SyncCorrected 事件被发出
  expect(
    events.any((e) => e is FullscreenEvent && e.syncCorrected != null),
    isTrue,
  );
});
```

## Task 4: TEST-04 — DisplayEnumerator 测试

**文件**: `test/kernel/bridge/display_enumerator_test.dart` (新建)

**场景**: 多显示器枚举和主显示器识别。

```dart
group('DisplayEnumerator', () {
  test('returns at least one display', () async {
    // Arrange & Act
    final displays = await DisplayEnumerator.enumerate();

    // Assert: 至少有一个显示器
    expect(displays, isNotEmpty);
  });

  test('identifies primary display', () async {
    // Arrange & Act
    final displays = await DisplayEnumerator.enumerate();

    // Assert: 恰好一个主显示器
    final primary = displays.where((d) => d.isPrimary);
    expect(primary, hasLength(1));
  });
});
```

## 完成标准

- [ ] 4 个新测试全部通过
- [ ] 测试覆盖率从 ~85% 提升到 90%+
- [ ] 无 flaky 测试（3 次连续运行全部通过）
- [ ] `flutter test` 全部通过
