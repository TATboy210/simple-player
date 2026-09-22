import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import 'control_bar_decoration.dart';
import 'edge_glow.dart';
import 'glass_container.dart';

/// 共享对话框包装器 — 统一视觉风格和关闭按钮
///
/// v0.0.4 设计语言同步：对话框壳从实色 bgElevated 升级为控制栏同款
/// 毛玻璃面板 —— [ControlBarDecoration.playing] 4-shadow 分层装饰
/// （顶部内高光 / 底部内阴影 / 外层投影 / 蓝色外环）+ [EdgeGlow]
/// 渐变描边辉光 + [GlassTier.thick] 背景模糊，标题区新增 accent 竖条
/// 与渐变分隔线两个质感细节。
///
/// 仍支持 LayoutBuilder 响应式：宽屏用指定尺寸，窄屏自适应。
class AppDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget>? actions;
  final double width;
  final double height;

  /// 关闭回调 — 非 route 场景（Stack 内嵌浮动面板）由调用方提供，
  /// Close 按钮走它而非 Navigator.pop；null 保持旧 route 语义（向后兼容）。
  final VoidCallback? onClose;

  const AppDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions,
    this.onClose,
    this.width = 400,
    this.height = 350,
  });

  /// 面板圆角 — v0.0.5 绑定控制栏单一事实源 ([Tokens.controlBarRadius]
  /// 22px, 与控制栏/播放列表面板同款); 替代旧 radiusLarge(12) 与值巧合的
  /// radiusLg 引用 — 控制栏改圆角时本面板自动跟随.
  static final _panelRadius = BorderRadius.circular(Tokens.controlBarRadius);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth * 0.9;
        final maxH = constraints.maxHeight * 0.85;
        final w = width.clamp(200.0, maxW).toDouble();
        final h = height.clamp(150.0, maxH).toDouble();

        return Dialog(
          // 透明底 + 零 elevation：投影/辉光由 playing 装饰的 shadow 层承担。
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: ClipRRect(
            borderRadius: _panelRadius,
            child: BackdropFilter(
              // v0.0.5: 与控制栏同档模糊 (GlassTier.normal) — thick 已与
              // normal 合并同值, 引用收敛到控制栏单一档位, 消除档位分叉.
              filter: GlassTier.normal.blurFilter,
              child: EdgeGlow(
                borderRadius: _panelRadius,
                child: Container(
                  width: w,
                  // 面板 chrome 恒用 playing 装饰（视觉对齐，非状态对齐；
                  // 对话框无 playing/idle 状态机 — ControlBarDecoration
                  // 头注释预留的复用语义在此落地）。
                  decoration: ControlBarDecoration.playing(
                    borderRadius: _panelRadius,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    // maxH 约束整个对话框（含标题/动作行）—— 小窗口下
                    // 内容区经 Flexible 收缩，滚动型内容（ListView）转入
                    // 滚动而非把面板顶出裁剪边界（v0.0.4 最小窗口 854×480
                    // 绘制不完整的根因修复）。
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: maxH),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _DialogTitle(title),
                          Flexible(
                            child: SizedBox(
                              width: w,
                              height: h,
                              child: content,
                            ),
                          ),
                          _DialogActions(actions: actions, onClose: onClose),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 对话框标题行 — accent 竖条 + 标题 + 渐变分隔线（两端透明中段实色）。
///
/// accent 竖条与渐变分隔线是控制栏设计语言在面板 chrome 上的两个质感
/// 细节：竖条呼应播放中图标/滑块的 accent 强调；渐变分隔线模拟毛玻璃
/// 边缘的光线收束，比纯色实线更轻。
class _DialogTitle extends StatelessWidget {
  final String title;

  const _DialogTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Tokens.spLg,
        Tokens.spMd,
        Tokens.spLg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // accent 竖条 — 3px 宽、radiusBtn 圆角，高度与标题字号对齐。
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: Tokens.accent,
                  borderRadius: BorderRadius.circular(Tokens.radiusBtn),
                ),
              ),
              const SizedBox(width: Tokens.spSm),
              // Expanded — 长标题 (如批量删除正式文案) 溢出防护:
              // 超宽时 ellipsis 而非渲染报错 (v0.0.7).
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Tokens.textPrimary,
                    fontSize: Tokens.fontBody,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.spSm),
          // 渐变分隔线 — 两端透明 → borderHighlight → 透明。
          Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.transparent,
                  Tokens.borderHighlight,
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 对话框底部动作行 — 自定义 actions + 统一关闭按钮，右对齐。
class _DialogActions extends StatelessWidget {
  final List<Widget>? actions;

  /// 关闭回调 — 非 null 时 Close 按钮走它（Stack 内嵌场景无 route 可 pop）；
  /// null 走 Navigator.pop（route 弹出的既有语义）。
  final VoidCallback? onClose;

  const _DialogActions({this.actions, this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: Tokens.spSm,
        right: Tokens.spSm,
        bottom: Tokens.spXs,
      ),
      // Wrap 替代 Row — 多按钮 (外部 actions + 统一 Close) 超宽时
      // 自动换行而非溢出报错 (v0.0.7 长文案场景).
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: Tokens.spXs,
        children: [
          ...?actions,
          TextButton(
            // onClose 优先 — Stack 内嵌面板无 route 可 pop，由调用方收口。
            onPressed: onClose ?? () => Navigator.of(context).pop(),
            child: Text(
              AppLocalizations.of(context).close,
              style: const TextStyle(color: Tokens.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
