import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';

/// 应用版本号 — 发版时随 pubspec.yaml `version` 同步更新。
const String kAppVersion = '0.0.1';

/// 开源组件条目 — 名称与 SPDX 许可证标识对。
///
/// 组件名与 License 是国际通用专名/标识符，不做本地化翻译。
typedef OpenSourceComponent = ({String name, String license});

/// 运行时真实使用的全部第三方开源组件 — 与实际 `import` / 打包二进制对齐；
/// pubspec 中未被代码引用的历史残留依赖不在此列。
///
/// 维护约定：更新依赖时同步维护本表；libmpv 与 FFmpeg 的 LGPL 合规法律
/// 文本以仓库根 NOTICE 文件为准，页面内仅作指引性注记。
const List<OpenSourceComponent> kOpenSourceComponents = [
  // ── 引擎与解码 — 随附二进制，LGPL 动态链接（见 NOTICE）──
  (name: 'mpv · libmpv', license: 'LGPL-2.1-or-later'),
  (name: 'FFmpeg', license: 'LGPL-2.1-or-later'),
  (name: 'media_kit', license: 'MIT'),
  // ── 框架与语言 ──
  (name: 'Flutter', license: 'BSD-3-Clause'),
  (name: 'Dart', license: 'BSD-3-Clause'),
  // ── 桌面集成 ──
  (name: 'window_manager', license: 'MIT'),
  (name: 'file_picker', license: 'MIT'),
  (name: 'desktop_drop', license: 'MIT'),
  // ── 数据与基础 ──
  (name: 'shared_preferences', license: 'BSD-3-Clause'),
  (name: 'path_provider', license: 'BSD-3-Clause'),
  // ── 字体 ──
  (name: 'Noto Sans SC（思源黑体）', license: 'SIL OFL 1.1'),
];

/// 特别鸣谢名单 — 支持本项目的网友昵称，一项一个名字，按展示顺序排列。
///
/// 在此列表追加字符串即可上屏（渲染为胶囊墙）；列表为空时显示占位文案。
const List<String> kSpecialThanks = [];

/// 「关于」分区内容 — 设置窗口右侧的静态信息页。
///
/// 三段式：软件标识（品牌 + 版本 + 一句话技术构成）→ 开源技术全清单 →
/// 特别鸣谢。纯展示视图，无任何交互或功能行为。
class AboutContent extends StatelessWidget {
  const AboutContent({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: Tokens.spLg),
      children: [
        _AppIdentity(l10n: l10n),
        const SizedBox(height: Tokens.spLg),
        _SectionLabel(l10n.techStack),
        for (final component in kOpenSourceComponents)
          _ComponentRow(component: component),
        const SizedBox(height: Tokens.spSm),
        Text(
          l10n.lgplNotice,
          style: const TextStyle(
            color: Tokens.textSecondary,
            fontSize: Tokens.fontCaption,
          ),
        ),
        const SizedBox(height: Tokens.spLg),
        _SectionLabel(l10n.specialThanks),
        const _SpecialThanksBody(),
        const SizedBox(height: Tokens.spLg),
      ],
    );
  }
}

/// 软件标识头部 — 品牌名 + 版本徽标 + 版权一句话。
class _AppIdentity extends StatelessWidget {
  final AppLocalizations l10n;
  const _AppIdentity({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.brandName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Tokens.textPrimary,
                  fontSize: Tokens.fontTitle,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: const BoxDecoration(
                color: Tokens.bgHover,
                borderRadius: BorderRadius.all(
                  Radius.circular(Tokens.radiusBtn),
                ),
              ),
              child: const Text(
                'v$kAppVersion',
                style: TextStyle(
                  color: Tokens.textPrimary,
                  fontSize: Tokens.fontCaption,
                  fontFeatures: [Tokens.tabularFigures],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Tokens.spSm),
        Text(
          l10n.copyright,
          style: const TextStyle(
            color: Tokens.textSecondary,
            fontSize: Tokens.fontCaption,
          ),
        ),
      ],
    );
  }
}

/// 分区小标题 — 与 media_info_dialog 的 `_Section` 同视觉语言（accent 强调色）。
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.spSm),
      child: Text(
        text,
        style: const TextStyle(
          color: Tokens.accent,
          fontSize: Tokens.fontCaption,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 开源组件行 — 左侧名称、右侧 License 徽标文本。
class _ComponentRow extends StatelessWidget {
  final OpenSourceComponent component;
  const _ComponentRow({required this.component});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              component.name,
              style: const TextStyle(
                color: Tokens.textPrimary,
                fontSize: Tokens.fontBody,
              ),
            ),
          ),
          Text(
            component.license,
            style: TextStyle(
              color: component.license.startsWith('LGPL')
                  ? Tokens.accent
                  : Tokens.textSecondary,
              fontSize: Tokens.fontCaption,
              fontFeatures: const [Tokens.tabularFigures],
            ),
          ),
        ],
      ),
    );
  }
}

/// 特别鸣谢正文 — 有名单渲染胶囊墙，空名单渲染占位文案。
class _SpecialThanksBody extends StatelessWidget {
  const _SpecialThanksBody();

  @override
  Widget build(BuildContext context) {
    if (kSpecialThanks.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          l10n.thanksPending,
          style: const TextStyle(
            color: Tokens.textSecondary,
            fontSize: Tokens.fontCaption,
          ),
        ),
      );
    }

    // 名单胶囊墙 — 每位支持者一枚轻量圆角胶囊；Wrap 自动换行。
    return Wrap(
      spacing: Tokens.spSm,
      runSpacing: Tokens.spSm,
      children: [
        for (final name in kSpecialThanks)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Tokens.bgHover,
              borderRadius: BorderRadius.circular(Tokens.radiusBtn),
            ),
            child: Text(
              name,
              style: const TextStyle(
                color: Tokens.textPrimary,
                fontSize: Tokens.fontCaption,
              ),
            ),
          ),
      ],
    );
  }
}
