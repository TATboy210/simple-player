import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../kernel/bridge/win32/ime_bridge.dart';
import '../../theme/tokens.dart';

/// IME 治理验证输入框（debug-only UAT 工具，v0.0.8.2）。
///
/// IME governance verification text field — manual UAT harness.
///
/// 验证 Win32ImeBridge **焦点启停接线**（未来正式输入框同款契约，
/// 防 flutter/flutter#78796：窗口 IMC 被解除后 TextField 打不出中文，
/// 必须按焦点启停）。UAT 路径：
/// 1. 系统选中中文输入法 → 聚焦本输入框（自动恢复默认 IMC）→
///    输入拼音应正常组合、候选窗锚定光标（不再漂移左上角）
/// 2. 失焦（点击别处）→ 自动再解除 → 按字母键应直上屏字母且无候选窗
///
/// 仅 debug 构建且 Windows 挂载（调用方守卫）；[bridge] 可注入供
/// widget 测试断言启停消息（生产传 null 走真实 FFI）。
class ImeTestField extends StatefulWidget {
  const ImeTestField({super.key, this.bridge});

  /// 可注入桥 — 测试用 fake 函数束断言 enable/disable 投递；
  /// 生产传 null（内部自建真实桥）。
  final Win32ImeBridge? bridge;

  @override
  State<ImeTestField> createState() => _ImeTestFieldState();
}

class _ImeTestFieldState extends State<ImeTestField> {
  late final Win32ImeBridge _bridge;
  late final FocusNode _focusNode;
  final TextEditingController _controller = TextEditingController();

  /// 最后已知焦点态 — 整树卸载时 FocusManager 直接丢弃焦点层级,
  /// hasFocus 监听不可靠, dispose 兜底按此标记解除。
  bool _hadFocus = false;

  @override
  void initState() {
    super.initState();
    _bridge = widget.bridge ?? Win32ImeBridge();
    _focusNode = FocusNode(debugLabel: 'ImeTestField')
      ..addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    // 失焦解除兜底 — 组件卸载时（热重载/面板关闭/路由弹出）若仍处于
    // 启用态，恢复无文本框场景的默认禁用，防 IME 状态泄漏。
    if (_hadFocus) _bridge.disable();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// 焦点启停接线 — 聚焦恢复默认 IMC（enable），失焦再次解除（disable）。
  /// side effect：经 SendMessageTimeout 投递 platform 线程切换 IMC
  /// （见 Win32ImeBridge 文档）。
  void _onFocusChanged() {
    final focused = _focusNode.hasFocus;
    if (focused) _hadFocus = true;
    focused ? _bridge.enable() : _bridge.disable();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.imeTestTitle,
          style: const TextStyle(
            color: Tokens.textSecondary,
            fontSize: Tokens.fontCaption,
          ),
        ),
        const SizedBox(height: Tokens.spXs),
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          style: const TextStyle(color: Tokens.textPrimary),
          decoration: InputDecoration(
            hintText: l10n.imeTestHint,
            hintStyle: const TextStyle(color: Tokens.textDisabled),
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
