import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/player/panel_workspace_controller.dart';
import 'package:simple_player_flutter/ui/player/panel_workspace_host.dart';

void main() {
  testWidgets('standalone host listens resize without role notification', (
    tester,
  ) async {
    final controller = PanelWorkspaceController()..toggle('settings');
    final resizing = ValueNotifier(false);
    addTearDown(controller.dispose);
    addTearDown(resizing.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: PanelWorkspaceHost(
          controller: controller,
          resizeSignal: resizing,
          tasks: [
            WorkspaceTask(
              id: 'settings',
              builder: (_, visible, role) => const Text('task'),
            ),
          ],
        ),
      ),
    );
    expect(
      tester
          .widget<AnimatedPositioned>(find.byType(AnimatedPositioned))
          .duration,
      const Duration(milliseconds: 150),
    );
    resizing.value = true;
    await tester.pump();
    expect(
      tester
          .widget<AnimatedPositioned>(find.byType(AnimatedPositioned))
          .duration,
      Duration.zero,
    );
    resizing.value = false;
    await tester.pump();
    expect(
      tester
          .widget<AnimatedPositioned>(find.byType(AnimatedPositioned))
          .duration,
      const Duration(milliseconds: 150),
    );
  });
  testWidgets('task builder is not re-run on resize frames, only on role or '
      'task-list change', (tester) async {
    final controller = PanelWorkspaceController();
    addTearDown(controller.dispose);
    var builds = 0;
    List<WorkspaceTask> makeTasks() => [
      WorkspaceTask(
        id: 'settings',
        builder: (_, visible, role) {
          builds++;
          return Text('task-$builds');
        },
      ),
    ];

    Future<void> pumpAt(double width, List<WorkspaceTask> tasks) =>
        tester.pumpWidget(
          MaterialApp(
            home: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                height: 600,
                child: PanelWorkspaceHost(controller: controller, tasks: tasks),
              ),
            ),
          ),
        );

    final tasks = makeTasks();
    await pumpAt(1000, tasks);
    expect(builds, 1);

    // 拖窗缩放：约束逐帧变化、任务清单实例不变 → 隐藏面板不重建。
    await pumpAt(960, tasks);
    await pumpAt(920, tasks);
    expect(builds, 1, reason: '约束变化不得重复调用 builder');

    // 角色翻转（隐藏 → 显示）必须重新构建。
    controller.toggle('settings');
    await tester.pump();
    expect(builds, 2);

    // 宿主父级换入新的任务清单（闭包可能捕获新数据）→ 缓存作废。
    await pumpAt(920, makeTasks());
    expect(builds, 3);
  });

  testWidgets('role changes retain fake task state and exclude hidden focus', (
    tester,
  ) async {
    final workspace = PanelWorkspaceController();
    addTearDown(workspace.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 854,
          height: 480,
          child: PanelWorkspaceHost(
            controller: workspace,
            tasks: [
              for (final id in ['settings', 'second', 'third'])
                WorkspaceTask(
                  id: id,
                  builder: (_, visible, role) =>
                      _FakeTask(key: ValueKey(id), id: id),
                ),
            ],
          ),
        ),
      ),
    );
    workspace.toggle('settings');
    await tester.pumpAndSettle();
    expect(find.text('settings 0'), findsOneWidget);
    await tester.tap(find.text('settings 0'));
    await tester.pump();
    workspace.toggle('second');
    await tester.pumpAndSettle();
    expect(find.text('settings 1'), findsOneWidget);
    workspace.promote('settings');
    await tester.pumpAndSettle();
    expect(find.text('settings 1'), findsOneWidget);
    workspace.toggle('third');
    workspace.toggle('second');
    await tester.pumpAndSettle();
    expect(find.text('settings 1'), findsNothing);
    final hidden = find.text('settings 1', skipOffstage: false);
    expect(hidden, findsOneWidget);
    final focus = tester.widget<ExcludeFocus>(
      find.ancestor(of: hidden, matching: find.byType(ExcludeFocus)).first,
    );
    expect(focus.excluding, isTrue);
    workspace.toggle('settings');
    await tester.pumpAndSettle();
    expect(find.text('settings 1'), findsOneWidget);
  });
}

class _FakeTask extends StatefulWidget {
  const _FakeTask({super.key, required this.id});
  final String id;
  @override
  State<_FakeTask> createState() => _FakeTaskState();
}

class _FakeTaskState extends State<_FakeTask> {
  int count = 0;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => setState(() => count += 1),
    child: Text('${widget.id} $count'),
  );
}
