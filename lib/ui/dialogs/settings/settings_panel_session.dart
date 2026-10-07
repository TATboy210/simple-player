import 'package:flutter/foundation.dart';

/// 设置展示状态 — 跨全屏共享纯数据，焦点与滚动控制器仍属于各 route。
@immutable
class SettingsPanelPresentation {
  const SettingsPanelPresentation({
    this.section = 'about',
    this.isContent = false,
    this.scrollOffsets = const {},
  });
  final String section;
  final bool isContent;
  final Map<String, double> scrollOffsets;
}

/// 单次播放器会话的设置展示记忆，不落盘。
class SettingsPanelSession extends ValueNotifier<SettingsPanelPresentation> {
  SettingsPanelSession() : super(const SettingsPanelPresentation());

  /// 保存层级与分区；不改变其他分区的滚动位置。
  void navigate(String section, bool isContent) {
    // Exact equality avoids invalidation without changing navigation semantics.
    if (value.section == section && value.isContent == isContent) return;
    value = SettingsPanelPresentation(
      section: section,
      isContent: isContent,
      scrollOffsets: value.scrollOffsets,
    );
  }

  /// 保存滚动位置的不可变副本。
  void recordScroll(String section, double offset) {
    // A missing zero is still recorded; every distinct real-time offset survives.
    if (value.scrollOffsets[section] == offset) return;
    value = SettingsPanelPresentation(
      section: value.section,
      isContent: value.isContent,
      scrollOffsets: Map.unmodifiable({
        ...value.scrollOffsets,
        section: offset,
      }),
    );
  }
}
