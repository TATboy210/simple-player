import 'package:flutter/foundation.dart';

import '../models/fullscreen_capability.dart';
import '../models/fullscreen_event.dart';
import '../models/fullscreen_snapshot.dart';

/// 全屏管理抽象接口 — UI 层依赖此接口，不依赖具体实现。
///
/// 实现方:
/// - DesktopFullscreenAdapter — Windows/macOS/Linux 真实实现 (Phase B)
/// - FakeFullscreenAdapter — 测试替身
///
/// 设计约束:
/// - 与 WindowBridge 并列，不继承不依赖
/// - 内部组合 WindowService 通用方法 + fullscreen_window 插件
/// - per-window 状态容器，默认 windowId = 0
/// - error 不是锁死态，下次合法操作自动清理
abstract class FullscreenAdapter {
  // ─── 状态查询 ───

  /// 获取指定窗口的全屏状态快照。
  ///
  /// 单窗口使用 windowId = 0。返回的 ValueNotifier 在整个窗口生命周期内有效。
  ValueNotifier<FullscreenSnapshot> snapshot([int windowId = 0]);

  /// 全屏生命周期事件流。
  ///
  /// 业务层监听此流获取全屏过渡通知，不直接依赖 _WindowListener。
  Stream<FullscreenEvent> get events;

  // ─── 能力查询 ───

  /// 查询当前平台的全屏能力。
  ///
  /// 返回值描述平台支持的全屏特性（多窗口/多显示器/手势限制等）。
  Future<FullscreenCapability> capabilities();

  // ─── 命令 ───

  /// 设置全屏状态。
  ///
  /// - [fullscreen] true 进入全屏，false 退出全屏
  /// - [windowId] 目标窗口，默认 0
  /// - [mode] 全屏模式，默认 borderless
  ///
  /// 如果当前正在过渡中（entering/leaving），返回 BusyTransition 错误。
  /// 如果平台不支持，返回 Unsupported 错误。
  /// error 状态下调用会自动清理为 stable 并重走流程。
  Future<void> setFullscreen(
    bool fullscreen, {
    int windowId = 0,
    FullscreenMode mode = FullscreenMode.borderless,
  });

  /// 切换全屏状态。
  ///
  /// 等效于 `setFullscreen(!snapshot(windowId).value.isFullscreen)`。
  /// [preferredMode] 指定切换到全屏时的模式，null 时使用 borderless。
  Future<void> toggle({
    int windowId = 0,
    FullscreenMode? preferredMode,
  });

  // ─── Lifecycle ───

  /// 释放资源 — 关闭 StreamController，清理 per-window 状态。
  void dispose();
}
