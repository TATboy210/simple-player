import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../kernel/models/media_state.dart';
import '../../kernel/bridge/window_bridge.dart';
import '../theme/tokens.dart';

/// 极光呼吸背景 — 3 个椭圆光团沿 Lissajous 曲线缓慢漂移
///
/// 灵感来源：Apple iOS 锁屏光效 + Spotify 渐变背景。
/// 性能优化：光团预渲染为 Image 缓存，每帧只做 drawImage 平移/缩放。
/// 窗口失焦时自动暂停 Ticker。
///
/// [engineState] 可选的播放引擎状态。当非 idle 时暂停 Ticker 以节省 GPU。
/// 视频播放期间极光背景被遮挡，无需持续渲染。
class AuroraBackground extends StatefulWidget {
  /// 3 个光团的颜色（通常是 theme 的 primary / accent / secondary）
  final List<Color> blobColors;

  /// 3 个光团的不透明度
  final List<double> blobOpacities;

  /// 播放引擎状态 — 非 idle 时暂停 Ticker
  final ValueNotifier<MediaState>? engineState;

  const AuroraBackground({
    super.key,
    this.blobColors = const [
      Color(0xFF3B82F6), // primary blue
      Color(0xFF1130A3), // accent blue (logo)
      Color(0xFF5578DC), // light accent blue
    ],
    this.blobOpacities = const [0.08, 0.06, 0.05],
    this.engineState,
  });

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  final _repaint = _RepaintNotifier();
  double _time = 0;
  bool _isRunning = true;

  // 预渲染的光团 Image 缓存
  ui.Image? _blobImage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick);
    _ticker.start();
    _generateBlobImage();
    widget.engineState?.addListener(_onEngineStateChanged);
    WindowBridge.I.interaction.addListener(_syncTicker);
  }

  @override
  void didUpdateWidget(AuroraBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.engineState != widget.engineState) {
      oldWidget.engineState?.removeListener(_onEngineStateChanged);
      widget.engineState?.addListener(_onEngineStateChanged);
      _syncTicker();
    }
  }

  @override
  void dispose() {
    widget.engineState?.removeListener(_onEngineStateChanged);
    WindowBridge.I.interaction.removeListener(_syncTicker);
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _repaint.dispose();
    _blobImage?.dispose();
    super.dispose();
  }

  /// 引擎状态变化时同步 Ticker 生命周期
  void _onEngineStateChanged() {
    _syncTicker();
  }

  /// 根据 app 前后台 + 引擎状态决定 Ticker 启停
  void _syncTicker() {
    final engineIdle =
        widget.engineState?.value == MediaState.idle ||
        widget.engineState == null;
    final resizing = WindowBridge.I.interaction.value != WindowInteractionState.idle;
    final shouldRun = _isRunning && engineIdle && !resizing;

    if (shouldRun && !_ticker.isActive) {
      _ticker.start();
    } else if (!shouldRun && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isRunning = state == AppLifecycleState.resumed;
    _syncTicker();
  }

  void _onTick(Duration elapsed) {
    _time = elapsed.inMicroseconds / 1e6;
    _repaint.markDirty();
  }

  /// 预渲染一个光团的 RadialGradient 为 Image（256×256）
  Future<void> _generateBlobImage() async {
    const size = 256;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(size / 2, size / 2),
        size / 2,
        [const Color(0xFFFFFFFF), const Color(0x00FFFFFF)],
        [0.0, 1.0],
      );
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, paint);
    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    if (mounted) {
      setState(() => _blobImage = image);
    } else {
      image.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _repaint,
          builder: (_, _) => CustomPaint(
            painter: _AuroraPainter(
              time: _time,
              blobColors: widget.blobColors,
              blobOpacities: widget.blobOpacities,
              blobImage: _blobImage,
            ),
          ),
        ),
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double time;
  final List<Color> blobColors;
  final List<double> blobOpacities;
  final ui.Image? blobImage;

  // Lissajous 参数 — 质数比避免同步
  static const _lissajous = [
    _LissajousParams(freqX: 0.04, freqY: 0.053, phaseX: 0, phaseY: 0),
    _LissajousParams(
      freqX: 0.031,
      freqY: 0.039,
      phaseX: pi / 3,
      phaseY: pi / 4,
    ),
    _LissajousParams(
      freqX: 0.027,
      freqY: 0.047,
      phaseX: pi / 6,
      phaseY: pi / 2,
    ),
  ];

  // 呼吸缩放参数
  static const _breathFreqs = [0.16, 0.13, 0.11]; // 周期 ~6-9s
  static const _breathPhases = [0.0, pi / 3, 2 * pi / 3];

  _AuroraPainter({
    required this.time,
    required this.blobColors,
    required this.blobOpacities,
    required this.blobImage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Layer 0: 深色底
    canvas.drawRect(Offset.zero & size, Paint()..color = Tokens.bgBase);

    if (blobImage == null) return;

    for (var i = 0; i < 3; i++) {
      final params = _lissajous[i];

      // Lissajous 坐标（归一化 -1 ~ 1）
      final lx = sin(time * params.freqX + params.phaseX);
      final ly = cos(time * params.freqY + params.phaseY);

      // 映射到屏幕坐标（中心 + 偏移）
      final cx = size.width * 0.5 + lx * size.width * 0.25;
      final cy = size.height * 0.5 + ly * size.height * 0.25;

      // 呼吸缩放
      final breathScale =
          0.8 +
          0.4 * (0.5 + 0.5 * sin(time * _breathFreqs[i] + _breathPhases[i]));

      // 光团大小
      final blobW = size.width * 0.6 * breathScale;
      final blobH = size.height * 0.4 * breathScale;

      // 颜色 + 不透明度
      final color = blobColors[i].withValues(alpha: blobOpacities[i]);

      // 绘制光团（预渲染的 radial gradient image + 颜色滤镜）
      canvas.saveLayer(
        Rect.fromCenter(center: Offset(cx, cy), width: blobW, height: blobH),
        Paint()
          ..colorFilter = ui.ColorFilter.mode(color, ui.BlendMode.srcIn)
          ..imageFilter = ui.ImageFilter.blur(
            sigmaX: blobW * 0.3,
            sigmaY: blobH * 0.3,
          ),
      );
      canvas.drawImageRect(
        blobImage!,
        Rect.fromLTWH(
          0,
          0,
          blobImage!.width.toDouble(),
          blobImage!.height.toDouble(),
        ),
        Rect.fromCenter(center: Offset(cx, cy), width: blobW, height: blobH),
        Paint(),
      );
      canvas.restore();
    }

    // 噪点纹理（简化：用半透明白点模拟）
    _drawNoiseOverlay(canvas, size);
  }

  /// 轻量噪点层 — 防止色带，增加质感
  void _drawNoiseOverlay(Canvas canvas, Size size) {
    // 用极低不透明度的随机点模拟噪点
    // 实际项目中可用预渲染的 noise texture 替代
    final paint = Paint()
      ..color = const Color(0x05FFFFFF)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    // 伪随机种子基于 time（每秒更新一次，避免每帧重算）
    final seed = (time * 0.5).floor();
    final rng = Random(seed);
    for (var i = 0; i < 50; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      canvas.drawPoints(ui.PointMode.points, [Offset(x, y)], paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) {
    return oldDelegate.time != time || oldDelegate.blobImage != blobImage;
  }
}

class _LissajousParams {
  final double freqX;
  final double freqY;
  final double phaseX;
  final double phaseY;

  const _LissajousParams({
    required this.freqX,
    required this.freqY,
    required this.phaseX,
    required this.phaseY,
  });
}

/// 可从外部触发通知的 ChangeNotifier
///
/// ChangeNotifier.notifyListeners() 是 @protected，外部无法调用。
/// 用 markDirty() 作为公开入口，避免 lint 警告。
class _RepaintNotifier extends ChangeNotifier {
  void markDirty() => notifyListeners();
}
