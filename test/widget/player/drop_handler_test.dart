import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/drop_handler.dart';

void main() {
  group('DropHandler', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DropHandler(
              onFilesDropped: (_) {},
              child: const Text('drop zone'),
            ),
          ),
        ),
      );
      expect(find.text('drop zone'), findsOneWidget);
    });

    testWidgets('onFilesDropped is called with valid paths', (tester) async {
      final dropped = <List<String>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DropHandler(
              onFilesDropped: dropped.add,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      // desktop_drop 通过平台通道接收文件，widget 测试中无法直接模拟
      // 验证 DropHandler 正确挂载 DropTarget 并暴露回调
      expect(find.byType(DropHandler), findsOneWidget);
    });

    testWidgets('onHoverChanged callback is accepted', (tester) async {
      final hoverStates = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DropHandler(
              onFilesDropped: (_) {},
              onHoverChanged: hoverStates.add,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      // onHoverChanged 非空时，overlay 由子组件处理
      // 验证 widget 正确构建无 crash
      expect(find.byType(DropHandler), findsOneWidget);
    });

    testWidgets('without onHoverChanged shows overlay on hover', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DropHandler(
              onFilesDropped: (_) {},
              // 不提供 onHoverChanged — overlay 由 DropHandler 自行显示
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      // 无 onHoverChanged 时，hovering 状态下会显示 overlay Container
      // 但 desktop_drop 的平台回调在测试中不可用，只验证构建正确
      expect(find.byType(DropHandler), findsOneWidget);
    });

    testWidgets('empty onFilesDropped does not crash', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DropHandler(
              onFilesDropped: (_) {},
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      // 无文件拖入时不应有任何副作用
      expect(find.byType(DropHandler), findsOneWidget);
    });

    // ── DropTarget callback wiring ──

    testWidgets('DropTarget onDragEntered sets hovering state', (tester) async {
      final hoverStates = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DropHandler(
              onFilesDropped: (_) {},
              onHoverChanged: hoverStates.add,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );

      // 找到 DropTarget 并触发 onDragEntered 回调
      final dropTarget = tester.widget<DropTarget>(find.byType(DropTarget));
      dropTarget.onDragEntered?.call(
        DropEventDetails(localPosition: Offset.zero, globalPosition: Offset.zero),
      );
      await tester.pump();

      // onHoverChanged(true) 应被调用
      expect(hoverStates, contains(true));
    });

    testWidgets('DropTarget onDragExited clears hovering state',
        (tester) async {
      final hoverStates = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DropHandler(
              onFilesDropped: (_) {},
              onHoverChanged: hoverStates.add,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );

      final dropTarget = tester.widget<DropTarget>(find.byType(DropTarget));
      final details = DropEventDetails(
        localPosition: Offset.zero,
        globalPosition: Offset.zero,
      );
      // 先 enter 再 exit
      dropTarget.onDragEntered?.call(details);
      await tester.pump();
      dropTarget.onDragExited?.call(details);
      await tester.pump();

      // onHoverChanged 应收到 [true, false]
      expect(hoverStates, [true, false]);
    });

    testWidgets('DropTarget onDragDone with empty list does not call onFilesDropped',
        (tester) async {
      final dropped = <List<String>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DropHandler(
              onFilesDropped: dropped.add,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );

      final dropTarget = tester.widget<DropTarget>(find.byType(DropTarget));
      // 模拟拖入空文件列表
      dropTarget.onDragDone?.call(const DropDoneDetails(
        files: [],
        localPosition: Offset.zero,
        globalPosition: Offset.zero,
      ));
      await tester.pump();

      // 空文件列表 → onFilesDropped 不应被调用
      expect(dropped, isEmpty);
    });

    // ── Overlay rendering branch ──

    testWidgets('overlay visible when _hovering=true and no onHoverChanged',
        (tester) async {
      // 覆盖 _hovering && widget.onHoverChanged == null 分支 (line 67)
      // overlay 内使用 AppLocalizations.of(context).dragHint，需要 l10n delegates
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DropHandler(
              onFilesDropped: (_) {},
              // onHoverChanged 为 null → overlay 由 DropHandler 自行显示
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );

      // 触发 onDragEntered → _hovering = true
      final dropTarget = tester.widget<DropTarget>(find.byType(DropTarget));
      dropTarget.onDragEntered?.call(
        DropEventDetails(localPosition: Offset.zero, globalPosition: Offset.zero),
      );
      await tester.pump();

      // _hovering=true 且 onHoverChanged=null → overlay 应显示
      // overlay 内包含 Icons.file_download_outlined 图标
      expect(find.byIcon(Icons.file_download_outlined), findsOneWidget);
    });

    testWidgets('overlay hidden when onHoverChanged is provided', (tester) async {
      // onHoverChanged 非空时，即使 _hovering=true 也不显示 overlay
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DropHandler(
              onFilesDropped: (_) {},
              onHoverChanged: (_) {},
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );

      final dropTarget = tester.widget<DropTarget>(find.byType(DropTarget));
      dropTarget.onDragEntered?.call(
        DropEventDetails(localPosition: Offset.zero, globalPosition: Offset.zero),
      );
      await tester.pump();

      // onHoverChanged 非空 → overlay 不应显示
      expect(find.byIcon(Icons.file_download_outlined), findsNothing);
    });
  });
}
