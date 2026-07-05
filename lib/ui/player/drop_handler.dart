import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../../kernel/services/path_validator.dart';
import '../../l10n/app_localizations.dart';

/// 文件拖放处理器 — 使用 desktop_drop 接收 Windows Explorer 拖拽
///
/// Flutter 原生 DragTarget 不支持 OS 级文件拖放，
/// desktop_drop 通过平台通道监听窗口级 Drop 事件。
class DropHandler extends StatefulWidget {
  /// The widget subtree wrapped with drop detection.
  final Widget child;

  /// Called with validated file paths after a successful drop.
  ///
  /// Only paths that pass [PathValidator.validate] are included.
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
        // PathValidator 过滤逻辑：路径长度检查、空字节检查、合法字符验证
        // validate() 返回 null 表示通过，非 null 表示错误原因
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
                    color: Tokens.accent.withValues(alpha: 0.5),
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
                        AppLocalizations.of(context).dragHint,
                        style: const TextStyle(
                          color: Tokens.textPrimary,
                          fontSize: Tokens.fontBody,
                          fontWeight: Tokens.weightMedium,
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
