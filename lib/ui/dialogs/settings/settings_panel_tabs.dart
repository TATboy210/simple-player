part of 'settings_panel.dart';

/// 设置分区 —— 左侧导航的四个条目。
enum _SettingsTab { general, video, audio, about }

/// 面板层级 —— 两级覆盖导航（XMB 交叉模型，通用模式实现）：
/// L0 tag 层（竖排分区入口）→ L1 内容层（从右滑入覆盖，tag 层虚化后退）。
enum _PanelLevel { tags, content }

/// 键盘可达分区 — audio 已解灰（v0.0.8.1：audio delay 实现完整，仅 UI
/// 被灰显；261009-upn 起行级键盘亦可达，与 General 同模式），video 仍
/// 灰显（视频处理走控制层，无面板内容需求）.
const List<_SettingsTab> _enabledTabs = [
  _SettingsTab.general,
  _SettingsTab.audio,
  _SettingsTab.about,
];
