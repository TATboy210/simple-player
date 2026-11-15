import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/kernel/window_bridge/window_bridge.dart';
import 'package:simple_player_flutter/ui/player/auto_hide_controller.dart';
import 'package:simple_player_flutter/ui/player/controls_host.dart';
import 'package:simple_player_flutter/ui/player/mpv_kit_player_port.dart';
import 'package:simple_player_flutter/ui/player/panel_workspace_controller.dart';
import 'package:simple_player_flutter/ui/player/player_actions.dart';
import 'package:simple_player_flutter/ui/player/workspace_focus_scope.dart';
import 'package:simple_player_flutter/ui/player/workspace_menu_session.dart';

/// [ControlsHost] 的可变测试替身 — 字段直接可写，无需构造完整 State。
///
/// 不依赖 libmpv：视频端口与引擎由调用方注入 fake。
class FakeControlsHost implements ControlsHost {
  FakeControlsHost({
    required this.video,
    required this.engine,
    required this.autoHide,
    required this.context,
    this.actions = const PlayerActions(),
  });

  @override
  VideoControlsPort video;
  @override
  MediaEngine engine;
  @override
  PlayerActions actions;
  @override
  ValueListenable<WindowMode> windowMode = ValueNotifier(WindowMode.windowed);
  @override
  WorkspaceMenuSession? menuSession;
  @override
  PanelWorkspaceController? workspace;
  @override
  WorkspaceFocusRegistry? workspaceFocus;
  @override
  ValueNotifier<bool>? legacySettingsVisible;
  @override
  ValueNotifier<bool>? playlistVisible;
  @override
  ValueListenable<bool>? resizing;
  @override
  AutoHideController autoHide;
  @override
  bool isAlive = true;
  @override
  BuildContext context;
}
