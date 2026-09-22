import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../kernel/utils/path_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../shared/app_tooltip.dart';

/// 应用版本号 — 发版时随 pubspec.yaml `version` 同步更新。
const String kAppVersion = '0.0.8';

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

/// 特别鸣谢名单 — 支持本项目的用户昵称，一项一个名字，按展示顺序排列。
///
/// 在此列表追加字符串即可上屏（渲染为深色圆角鸣谢区的头像+姓名条目）；
/// 列表为空时显示占位文案。
const List<String> kSpecialThanks = [
  // 爱发电支持者（afdian.net/u/24f3f2729b0811f18cb252540025c377）
  '爱发电用户_24f3f',
];

/// 社交/赞助外链 — 品牌行右侧 logo 按钮组的数据源。
///
/// logo 为 assets/logos/ 下的真实品牌资产（SVG 经 colorFilter 白色 tint、
/// PNG 经 ColorFilter.srcIn 白色覆盖 —— 原素材全为黑色填充，深色面板上
/// 必须反转才可见）；tooltip 与跳转 URL 为国际通用专名，不做本地化。
typedef SocialLink = ({String asset, String tooltip, String url});

const List<SocialLink> kSocialLinks = [
  (
    asset: 'assets/logos/x.svg',
    tooltip: 'X (Twitter)',
    url: 'https://x.com/SimplePlayTeam',
  ),
  (
    asset: 'assets/logos/afdian.svg',
    tooltip: '爱发电',
    url: 'https://ifdian.net/a/SimplePlayerTeam',
  ),
  (
    asset: 'assets/logos/patreon.svg',
    tooltip: 'Patreon',
    url: 'https://www.patreon.com/cw/SimplePlayerTeam',
  ),
  (
    asset: 'assets/logos/github.svg',
    tooltip: 'GitHub',
    url: 'https://github.com/TATboy210/simple-player',
  ),
];

/// 「关于」分区内容 — 设置窗口右侧的静态信息页。
///
/// v0.0.4 段序：软件标识（品牌 + 社交 logo + 版本）→ **特别鸣谢**（深色
/// 圆角区域，上移至技术栈之前，支持者一进门即见）→ 开源技术全清单。
/// 社交 logo 点击经 [PathUtils.openUrl] 走系统浏览器。
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
        // 鸣谢区上移（v0.0.4）：支持者比技术栈更值得被先看见。
        _SectionLabel(l10n.specialThanks),
        const _SpecialThanksBody(),
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
      ],
    );
  }
}

/// 软件标识头部 — 品牌名 + 社交 logo 组 + 版本徽标 + 版权一句话。
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
            // 社交/赞助 logo 组 — 点击经 PathUtils.openUrl 走系统浏览器
            // （v0.0.4；外链常量收敛于 kSocialLinks 表）。
            for (final link in kSocialLinks) ...[
              _SocialLogoButton(link: link),
              const SizedBox(width: Tokens.spXs),
            ],
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

/// 社交 logo 按钮 — 与标题栏窗口按钮同款交互反馈（hover 底色 + 手型
/// 光标 + 按下色阶），tooltip 提示品牌名与跳转语义。
///
/// logo 渲染统一白色 tint（原素材全为黑色填充）：SVG 走 flutter_svg 的
/// colorFilter，PNG 走 ColorFilter.srcIn 白色覆盖（保留 alpha 通道形状）。
/// 视觉档位对齐 nav 图标 —— textSecondary（73% 白），与面板文字浑然一体。
class _SocialLogoButton extends StatelessWidget {
  final SocialLink link;

  const _SocialLogoButton({required this.link});

  /// logo 绘制尺寸 — 20px（v0.0.4 用户裁定放大一档），装在 30px 点击热区内。
  static const _logoSize = 20.0;

  /// 点击热区边长 — logo 外扩 10px 呼吸距，保持桌面易点性。
  static const _hitZone = 30.0;

  Widget _buildLogo() {
    return SvgPicture.asset(
      link.asset,
      width: _logoSize,
      height: _logoSize,
      // 统一 tint 到 textSecondary（73% 白）：原素材黑色或白色填充不一，
      // srcIn 以 alpha 形状为准替换色相，四枚 logo 视觉档位一致。
      colorFilter: const ColorFilter.mode(
        Tokens.textSecondary,
        BlendMode.srcIn,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppTooltip(
      message: link.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(Tokens.radiusBtn),
          child: InkWell(
            onTap: () => PathUtils.openUrl(link.url),
            mouseCursor: SystemMouseCursors.click,
            borderRadius: BorderRadius.circular(Tokens.radiusBtn),
            hoverColor: Tokens.bgHover,
            highlightColor: Tokens.titleBarPressed,
            splashColor: Colors.transparent,
            splashFactory: NoSplash.splashFactory,
            child: SizedBox(
              width: _hitZone,
              height: _hitZone,
              child: Center(child: _buildLogo()),
            ),
          ),
        ),
      ),
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

/// 特别鸣谢正文 — 深色圆角区域内渲染支持者条目（头像 + 姓名）。
///
/// v0.0.4：鸣谢从技术栈下方的胶囊墙上移为独立深色圆角区域
/// （bgDeep 底 + 玻璃描边 + radiusMd 圆角），与面板 chrome 形成层次。
/// 头像用「姓名首字 + accent 渐变圆」占位 —— 无网络依赖，将来接入
/// 真实头像 URL 时替换 [_SupporterAvatar] 内部实现即可。空名单仍回退
/// 占位文案。
class _SpecialThanksBody extends StatelessWidget {
  const _SpecialThanksBody();

  @override
  Widget build(BuildContext context) {
    if (kSpecialThanks.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return Container(
        padding: const EdgeInsets.all(Tokens.spMd),
        decoration: _thanksAreaDecoration,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            l10n.thanksPending,
            style: const TextStyle(
              color: Tokens.textSecondary,
              fontSize: Tokens.fontCaption,
            ),
          ),
        ),
      );
    }

    // 支持者条目墙 — 每位支持者一行（头像 + 姓名）；Wrap 自动换行。
    return Container(
      padding: const EdgeInsets.all(Tokens.spMd),
      decoration: _thanksAreaDecoration,
      child: Wrap(
        spacing: Tokens.spLg,
        runSpacing: Tokens.spSm,
        children: [
          for (final name in kSpecialThanks)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _SupporterAvatar(),
                const SizedBox(width: Tokens.spSm),
                Text(
                  name,
                  style: const TextStyle(
                    color: Tokens.textPrimary,
                    fontSize: Tokens.fontBody,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// 鸣谢区域底色 — 最深背景层 + 玻璃描边，圆角与色板方块同档。
const _thanksAreaDecoration = BoxDecoration(
  color: Tokens.bgDeep,
  borderRadius: BorderRadius.all(Radius.circular(Tokens.radiusMd)),
  border: Border.fromBorderSide(
    BorderSide(color: Tokens.glassBorderIdle, width: 1),
  ),
);

/// 支持者头像 — accent 渐变圆底 + 爱发电品牌图标（v0.0.4 用户裁定）。
///
/// 与品牌行的 afdian logo 同源资产（assets/logos/afdian.svg，白色 tint），
/// 32px 渐变圆内 18px 图标留呼吸边 —— 支持者头像与赞助品牌视觉同款。
class _SupporterAvatar extends StatelessWidget {
  const _SupporterAvatar();

  /// 头像内图标尺寸 — 32px 渐变圆内留呼吸边。
  static const _iconSize = 18.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Tokens.accent, Tokens.accentBlue],
        ),
      ),
      child: SvgPicture.asset(
        'assets/logos/afdian.svg',
        width: _iconSize,
        height: _iconSize,
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      ),
    );
  }
}
