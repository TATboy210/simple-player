import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../../kernel/services/path_validator.dart';

/// 文件拖放处理器 — 使用 desktop_drop 接收 Windows Explorer 拖拽
///
/// Flutter 原生 DragTarget 不支持 OS 级文件拖放，
/// desktop_drop 通过平台通道监听窗口级 Drop 事件。
class DropHandler extends StatefulWidget {
  final Widget child;
  final void Function(List<String> paths) onFilesDropped;

  /// 拖拽悬停状态回调（暴露给父组件，用于子组件联动动效）
  ///
  /// 当提供此回调时，DropHandler 不再显示自己的 overlay，
  /// 由子组件（如 EmptyState）自行处理拖拽视觉反馈。
  final void Function(bool hovering)? onHoverChanged;

  const DropHandler({
    super.key,
    required this.child,
    required this.onFilesDropped,
    this.onHoverChanged,
  });

  @override
  State<DropHandler> createState() => _DropHandlerState();
}

class _DropHandlerState extends State<DropHandler> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (_) {
        setState(() => _hovering = true);
        widget.onHoverChanged?.call(true);
      },
      onDragExited: (_) {
        setState(() => _hovering = false);
        widget.onHoverChanged?.call(false);
      },
      onDragDone: (detail) {
        setState(() => _hovering = false);
        widget.onHoverChanged?.call(false);
        final paths = detail.files
            .map((f) => f.path)
            .where((p) => PathValidator.validate(p) == null)
            .toList();
        if (paths.isNotEmpty) widget.onFilesDropped(paths);
      },
      child: Stack(
        children: [
          widget.child,
          // 有 onHoverChanged 时不显示 overlay（子组件自行处理）
          if (_hovering && widget.onHoverChanged == null)
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Tokens.bgGlass,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Tokens.accent.withAlpha(128),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.file_download_outlined,
                        size: 48,
                        color: Tokens.accent,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '释放以添加文件',
                        style: TextStyle(
                          color: Tokens.textPrimary,
                          fontSize: Tokens.fontBody,
                          fontWeight: Tokens.weightMedium,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '支持常见音视频格式',
                        style: TextStyle(
                          color: Tokens.textSecondary,
                          fontSize: Tokens.fontCaption,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
