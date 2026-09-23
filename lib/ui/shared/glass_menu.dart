import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'control_bar_decoration.dart';
import 'glass_blur_layer.dart';
import 'glass_container.dart' show GlassTier;

/// 玻璃右键菜单 — 控制栏同款主题的上下文菜单 (v0.0.7).
///
/// Glass context menu aligned with the control bar theme:
/// [ControlBarDecoration.playing] 装饰 + [GlassTier.normal] 毛玻璃 +
/// 菜单行交互看齐控制栏小按钮 (hover 微亮 white 6%, 按下变暗 black 12%).
///
/// 用 [OverlayEntry] 替换 Material showMenu — 后者的白底/主题化样式与
/// Midnight 玻璃语言割裂. 全屏透明 barrier 拦截外部点击即关闭 (非强制).
class GlassMenu {
  GlassMenu._();

  /// 弹出玻璃菜单 — 返回选中项 [GlassMenuItem.value]，点外部关闭返回 null.
  ///
  /// - [position] 为右键点的全局坐标, 菜单自动 clamp 到视口内.
  static Future<String?> show(
    BuildContext context, {
    required Offset position,
    required List<GlassMenuItem> items,
  }) {
    final overlay =
        Overlay.of(context, rootOverlay: true).context.findRenderObject()
            as RenderBox?;
    if (overlay == null) return Future<String?>.value(null);
    final screenSize = overlay.size;

    // 尺寸预估 — 宽取标签最长者的估算值, 高 = 行高 × 项数 + 内边距.
    const rowHeight = 38.0;
    const verticalPadding = 8.0;
    final menuWidth = _estimateWidth(items);
    final menuHeight = items.length * rowHeight + verticalPadding * 2;

    // 视口 clamp — 右/下越界时向内收.
    var left = position.dx;
    var top = position.dy;
    if (left + menuWidth > screenSize.width) {
      left = screenSize.width - menuWidth - 8;
    }
    if (top + menuHeight > screenSize.height) {
      top = screenSize.height - menuHeight - 8;
    }
    left = left.clamp(8.0, screenSize.width - menuWidth - 8);
    top = top.clamp(8.0, screenSize.height - menuHeight - 8);

    final completer = Completer<String?>();
    late final OverlayEntry barrier;
    late final OverlayEntry menu;

    void close([String? value]) {
      if (completer.isCompleted) return;
      barrier.remove();
      menu.remove();
      completer.complete(value);
    }

    barrier = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: GestureDetector(
          // 透明 barrier — 外部点击/右键即关闭 (非强制式 UI).
          behavior: HitTestBehavior.opaque,
          onTap: () => close(),
          onSecondaryTap: () => close(),
        ),
      ),
    );

    menu = OverlayEntry(
      builder: (_) => Positioned(
        left: left,
        top: top,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: menuWidth,
            decoration: ControlBarDecoration.playing(
              borderRadius: BorderRadius.circular(Tokens.radiusLg),
            ),
            // v0.0.8.2 D1: 瞬态小组件降档 thin(8.0) — 菜单行自带高不透明
            // 装饰 (menuBg 同族), 模糊量减少不影响信息获取, 肉眼近无差.
            child: GlassBlurLayer(
              borderRadius: BorderRadius.circular(Tokens.radiusLg),
              filter: GlassTier.thin.blurFilter,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final item in items)
                      _GlassMenuRow(
                        item: item,
                        onSelected: () => close(item.value),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context, rootOverlay: true).insertAll([barrier, menu]);
    return completer.future;
  }

  /// 菜单宽度估算 — 图标块 + 间距 + 文本 (fontCaption 拉丁 ≈ 7px/字符,
  /// CJK ≈ 13px; 余量 32). 覆盖四语言混合场景.
  static double _estimateWidth(List<GlassMenuItem> items) {
    var maxLabelPx = 0.0;
    for (final item in items) {
      var px = 0.0;
      for (final rune in item.label.runes) {
        px += rune > 0x2E80 ? 13.0 : 7.0;
      }
      if (px > maxLabelPx) maxLabelPx = px;
    }
    return (24 + 8 + maxLabelPx + 32).clamp(150.0, 260.0);
  }
}

/// 菜单项数据 — icon + label + value; [isDestructive] 时图标呈 danger 红.
class GlassMenuItem {
  final IconData icon;
  final String label;
  final String value;
  final bool isDestructive;

  const GlassMenuItem(
    this.icon,
    this.label, {
    required this.value,
    this.isDestructive = false,
  });
}

/// 菜单行 — 交互三态看齐控制栏小按钮: 静置透明 / hover 微亮 (white 6%) /
/// 按下变暗 (black 12%, 即时反馈).
class _GlassMenuRow extends StatefulWidget {
  final GlassMenuItem item;
  final VoidCallback onSelected;

  const _GlassMenuRow({required this.item, required this.onSelected});

  @override
  State<_GlassMenuRow> createState() => _GlassMenuRowState();
}

class _GlassMenuRowState extends State<_GlassMenuRow> {
  bool _hovering = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.item.isDestructive
        ? Tokens.danger
        : Tokens.textSecondary;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onSelected,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100), // 即时反馈
          height: 38,
          color: _pressed
              ? Colors.black.withValues(alpha: 0.12)
              : _hovering
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(widget.item.icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Tokens.textPrimary,
                    fontSize: Tokens.fontCaption,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
