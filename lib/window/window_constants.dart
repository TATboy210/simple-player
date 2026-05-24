import 'dart:ui';

// ═══════════════════════════════════════════════════════════════════════
// Enums
// ═══════════════════════════════════════════════════════════════════════

enum WindowMode { windowed, fullscreen }

enum WindowInteractionState { idle, resizing, moving }

// ═══════════════════════════════════════════════════════════════════════
// SharedPreferences keys
// ═══════════════════════════════════════════════════════════════════════

const kWWidth = 'windowWidth';
const kWHeight = 'windowHeight';
const kWPosX = 'windowX';
const kWPosY = 'windowY';
const kWMaximized = 'windowIsMaximized';
const kWFullscreen = 'windowIsFullscreen';

// ═══════════════════════════════════════════════════════════════════════
// Defaults
// ═══════════════════════════════════════════════════════════════════════

const kWDefaultWidth = 1280.0;
const kWDefaultHeight = 720.0;
const kWMinSize = Size(800, 450);
const kWMinVisible = 100.0;
const kWResizeDebounceMs = 500;
