import 'package:flutter/material.dart';

import '../../kernel/ui/theme/tokens.dart';
import '../shared/glass_container.dart';

/// OSD 消息数据
class OsdMessage {
  const OsdMessage({required this.text, this.icon});
  final String text;
  final IconData? icon;
}

/// OSD 服务 — 全局单例，任意模块可调用
///
/// ```dart
/// OsdService.I.show('75%');
/// OsdService.I.show('静音', icon: Icons.volume_off);
/// ```
class OsdService {
  OsdService._();
  static final I = OsdService._();

  final notifier = ValueNotifier<OsdMessage?>(null);
  int _generation = 0;

  void show(
    String text, {
    IconData? icon,
    Duration hold = const Duration(milliseconds: 600),
  }) {
    final gen = ++_generation;
    notifier.value = OsdMessage(text: text, icon: icon);
    Future.delayed(hold, () {
      if (gen == _generation) notifier.value = null;
    });
  }
}

/// OSD 覆盖层 — 放在 widget 树根部，浮在最上层
class OsdOverlay extends StatefulWidget {
  const OsdOverlay({super.key});

  @override
  State<OsdOverlay> createState() => _OsdOverlayState();
}

class _OsdOverlayState extends State<OsdOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _opacity = CurvedAnimation(
      parent: _anim,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeIn,
    );
    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _anim,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeIn,
      ),
    );
    OsdService.I.notifier.addListener(_onChanged);
  }

  @override
  void dispose() {
    OsdService.I.notifier.removeListener(_onChanged);
    _anim.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (OsdService.I.notifier.value != null) {
      _anim.animateTo(1.0);
    } else {
      _anim.animateTo(0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<OsdMessage?>(
      valueListenable: OsdService.I.notifier,
      builder: (_, msg, _) => IgnorePointer(
        child: Center(
          child: FadeTransition(
            opacity: _opacity,
            child: ScaleTransition(
              scale: _scale,
              alignment: Alignment.center,
              child: msg != null ? _OsdBubble(message: msg) : const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}

/// OSD 气泡 — 毛玻璃背景的浮动提示
class _OsdBubble extends StatelessWidget {
  final OsdMessage message;
  const _OsdBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      tier: GlassTier.thick,
      respectResizeState: true,
      borderRadius: BorderRadius.circular(Tokens.radiusPopup),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.icon != null) ...[
            Icon(message.icon, size: Tokens.iconSm, color: Tokens.textPrimary),
            const SizedBox(width: 6),
          ],
          Text(
            message.text,
            style: const TextStyle(
              color: Tokens.textPrimary,
              fontSize: Tokens.fontCaption,
              fontFeatures: [Tokens.tabularFigures],
            ),
          ),
        ],
      ),
    );
  }
}
