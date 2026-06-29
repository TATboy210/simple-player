import '../../kernel/engine/engine_state.dart';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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
      Tokens.auroraBlue1,
      Tokens.auroraBlue2,
      Tokens.auroraBlue3,
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
  int _lastRepaintMs = 0;
  bool _isRunning = true;

  // 预渲染的着色+模糊光团 Image 缓存（每色一张，启动时一次性生成）
  List<ui.Image>? _blobImages;

  // 噪点 Picture 缓存 — seed 每 2 秒变化一次，避免每帧重绘
  ui.Picture? _cachedNoisePicture;
  int _cachedNoiseSeed = -1;
  Size _cachedNoiseSize = Size.zero;

  // 缓存 layout 尺寸，避免每帧触发 LayoutBuilder
  Size _layoutSize = Size.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick);
    _ticker.start();
    _generateBlobImages();
    widget.engineState?.addListener(_onEngineStateChanged);
  }

  @override
  void didUpdateWidget(AuroraBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.engineState != widget.engineState) {
      oldWidget.engineState?.removeListener(_onEngineStateChanged);
      widget.engineState?.addListener(_onEngineStateChanged);
      _syncTicker();
    }
    if (oldWidget.blobColors != widget.blobColors ||
        oldWidget.blobOpacities != widget.blobOpacities) {
      _disposeBlobImages();
      _generateBlobImages();
    }
  }

  @override
  void dispose() {
    widget.engineState?.removeListener(_onEngineStateChanged);
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _repaint.dispose();
    _disposeBlobImages();
    _cachedNoisePicture?.dispose();
    super.dispose();
  }

  void _disposeBlobImages() {
    if (_blobImages != null) {
      for (final img in _blobImages!) {
        img.dispose();
      }
      _blobImages = null;
    }
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
    final shouldRun = _isRunning && engineIdle;

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
    // 降级到 ~15fps — 光团移动极慢 (freq ~0.03)，60fps 与 15fps 肉眼无区别
    final ms = elapsed.inMilliseconds;
    if (ms - _lastRepaintMs >= 66) {
      _repaint.markDirty();
      _lastRepaintMs = ms;
    }
  }

  /// 预渲染 3 个着色+模糊的光团 Image（一次性 saveLayer 开销）
  ///
  /// 每张图: 白色径向渐变 + ColorFilter 着色 + ImageFilter.blur。
  /// blur sigma = 256 × 0.6 × 0.3 = 46.08（breathScale=1.0 时的参考值）。
  /// 运行时通过 drawImage + scale 变换实现呼吸效果，零 saveLayer。
  Future<void> _generateBlobImages() async {
    const size = 256;
    const refSigma = size * 0.6 * 0.3; // 46.08

    // 1. 创建白色径向渐变源图
    final srcRecorder = ui.PictureRecorder();
    final srcCanvas = Canvas(srcRecorder);
    srcCanvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2,
      Paint()
        ..shader = ui.Gradient.radial(
          const Offset(size / 2, size / 2),
          size / 2,
          [const Color(0xFFFFFFFF), const Color(0x00FFFFFF)],
          [0.0, 1.0],
        ),
    );
    final srcPicture = srcRecorder.endRecording();
    final srcImage = await srcPicture.toImage(size, size);

    // 2. 对每个光团: 着色 + 模糊 → 预渲染 Image
    final images = <ui.Image>[];
    for (var i = 0; i < 3; i++) {
      final color = widget.blobColors[i].withValues(
        alpha: widget.blobOpacities[i],
      );
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.saveLayer(
        Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
        Paint()
          ..colorFilter = ui.ColorFilter.mode(color, ui.BlendMode.srcIn)
          ..imageFilter = ui.ImageFilter.blur(
            sigmaX: refSigma,
            sigmaY: refSigma,
          ),
      );
      canvas.drawImage(srcImage, Offset.zero, Paint());
      canvas.restore();
      final picture = recorder.endRecording();
      images.add(await picture.toImage(size, size));
    }
    srcImage.dispose();

    if (mounted) {
      setState(() => _blobImages = images);
    } else {
      for (final img in images) {
        img.dispose();
      }
    }
  }

  /// 录制噪点 Picture 并缓存 — seed 每 2 秒变化一次时调用
  void _regenerateNoiseCache(Size size) {
    final seed = (_time * 0.5).floor();
    if (seed == _cachedNoiseSeed && size == _cachedNoiseSize) return;

    _cachedNoisePicture?.dispose();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..color = const Color(0x05FFFFFF)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    final rng = Random(seed);
    for (var i = 0; i < 50; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      canvas.drawPoints(ui.PointMode.points, [Offset(x, y)], paint);
    }

    _cachedNoisePicture = recorder.endRecording();
    _cachedNoiseSeed = seed;
    _cachedNoiseSize = size;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // LayoutBuilder 只在窗口尺寸变化时触发（极低频）
            _layoutSize = Size(constraints.maxWidth, constraints.maxHeight);
            _regenerateNoiseCache(_layoutSize);
            return AnimatedBuilder(
              animation: _repaint,
              builder: (context, _) => CustomPaint(
                painter: _AuroraPainter(
                  time: _time,
                  blobImages: _blobImages,
                  cachedNoise: _cachedNoisePicture,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double time;
  final List<ui.Image>? blobImages;
  final ui.Picture? cachedNoise;

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
    required this.blobImages,
    this.cachedNoise,
  });

  // 静态 Paint 缓存 — 避免每帧分配（PERF-07）
  static final _bgPaint = Paint()..color = Tokens.bgBase;
  static final _compositePaint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    // Layer 0: 深色底
    canvas.drawRect(Offset.zero & size, _bgPaint);

    final images = blobImages;
    if (images == null || images.length < 3) return;

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

      // 绘制预渲染的着色+模糊光团（仅 affine transform，零 saveLayer）
      final img = images[i];
      canvas.save();
      canvas.translate(cx, cy);
      canvas.scale(blobW / img.width, blobH / img.height);
      canvas.drawImage(img, Offset(-img.width / 2, -img.height / 2), _compositePaint);
      canvas.restore();
    }

    // 噪点纹理（简化：用半透明白点模拟）
    _drawNoiseOverlay(canvas, size);
  }

  /// 轻量噪点层 — 防止色带，增加质感
  ///
  /// 噪点 Picture 由 State 层缓存，seed 每 2 秒变化一次时才重新录制。
  void _drawNoiseOverlay(Canvas canvas, Size size) {
    if (cachedNoise == null) return;
    canvas.drawPicture(cachedNoise!);
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) {
    return oldDelegate.time != time || oldDelegate.blobImages != blobImages;
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
