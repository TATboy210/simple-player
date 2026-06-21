import 'dart:ui';

/// 窗口命令 — UI → WindowFeature
sealed class WindowCommand {
  const WindowCommand();
}

final class ToggleFullscreenCommand extends WindowCommand {
  const ToggleFullscreenCommand();
}

final class SetFullscreenCommand extends WindowCommand {
  const SetFullscreenCommand(this.value);
  final bool value;
}

final class ToggleMaximizeCommand extends WindowCommand {
  const ToggleMaximizeCommand();
}

final class SetAlwaysOnTopCommand extends WindowCommand {
  const SetAlwaysOnTopCommand(this.value);
  final bool value;
}

final class MinimizeCommand extends WindowCommand {
  const MinimizeCommand();
}

final class RestoreCommand extends WindowCommand {
  const RestoreCommand();
}

final class CloseCommand extends WindowCommand {
  const CloseCommand();
}

final class StartDraggingCommand extends WindowCommand {
  const StartDraggingCommand();
}

/// 窗口事件 — WindowFeature → UI
sealed class WindowEvent {
  const WindowEvent();
}

final class FullscreenChanged extends WindowEvent {
  const FullscreenChanged(this.value);
  final bool value;
}

final class MaximizeChanged extends WindowEvent {
  const MaximizeChanged(this.value);
  final bool value;
}

final class AlwaysOnTopChanged extends WindowEvent {
  const AlwaysOnTopChanged(this.value);
  final bool value;
}

final class WindowSizeChanged extends WindowEvent {
  const WindowSizeChanged(this.size);
  final Size size;
}
