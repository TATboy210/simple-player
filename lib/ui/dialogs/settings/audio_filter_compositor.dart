// audio_filter_compositor.dart — Phase 33 音频 af 链确定性组合器 + 运行时可用性接缝。
//
// 纯值对象 + 确定性组合：把"用户音频偏好 → FFmpeg af 字符串"的逻辑从
// 引擎/控制器中分离，使组合规则可无头单测（无 mdk.dll 依赖）。运行时
// 可用性（pan/adelay/dynaudnorm 是否被目标 fvp 支持）由 PlayerFeature 组合根
// 经 probe 探测后注入；不可用段被省略并 debugPrint 警告，原始用户值不变。

import 'package:flutter/foundation.dart';

/// 音频偏好快照 — EQ 预设索引 / balance / 同步延迟 / 归一化开关。
///
/// 不可变值对象（AUDIO-06 延迟应用的基础）：tab 编辑只产出新快照，
/// 提交时由 [SettingsPanelController.commitPending] 构造一次交给
/// [AudioCommitCallback]。
@immutable
class AudioSettings {
  const AudioSettings({
    this.eqPresetIndex = 0,
    this.balance = 0.0,
    this.syncMs = 0,
    this.normalization = false,
  });

  /// EQ 预设索引 [0..4]（见 [AudioFilterCompositor.eqPresets]）。
  final int eqPresetIndex;

  /// 立体声平衡 [-1.0..1.0]：负=偏左，0=居中，正=偏右。
  final double balance;

  /// 音频延迟毫秒 [0..10000]（仅延迟——FFmpeg adelay 无法提前音频）。
  final int syncMs;

  /// 音量归一化开关。
  final bool normalization;

  /// 返回仅替换指定字段的新快照（不可变更新）。
  AudioSettings copyWith({
    int? eqPresetIndex,
    double? balance,
    int? syncMs,
    bool? normalization,
  }) =>
      AudioSettings(
        eqPresetIndex: eqPresetIndex ?? this.eqPresetIndex,
        balance: balance ?? this.balance,
        syncMs: syncMs ?? this.syncMs,
        normalization: normalization ?? this.normalization,
      );
}

/// 目标 fvp 运行时对 pan/adelay/dynaudnorm 三滤镜的支持证据。
///
/// 由 PlayerFeature 组合根拥有（它持有引擎）；组合器消费此结果以省略
/// 不支持段。默认 [allSupported]——运行时未探测前假定全支持；目标
/// Windows smoke 检查（audio_filter_runtime_smoke_test.dart）建立真实值。
@immutable
class AudioFilterAvailability {
  const AudioFilterAvailability({
    this.pan = true,
    this.adelay = true,
    this.dynaudnorm = true,
  });

  /// `pan=stereo|...` 是否在目标运行时应用成功。
  final bool pan;

  /// `adelay=<ms>|<ms>` 是否在目标运行时应用成功。
  final bool adelay;

  /// `dynaudnorm=f=500:g=15:p=0.95` 是否在目标运行时应用成功。
  final bool dynaudnorm;

  /// 全支持哨兵——未探测前的默认假定。
  static const AudioFilterAvailability allSupported = AudioFilterAvailability();

  /// 经 [applyFilter]（现有 `setEqualizer(String)` 入口）逐滤镜探测支持情况。
  ///
  /// 设计：注入 applier 回调使本函数保持引擎无关、可无头单测——测试注入
  /// 对特定滤镜抛 Exception 的 fake applier，断言对应字段为 false 且
  /// debugPrint 警告含滤镜标识。仅捕获可恢复 [Exception]（编程 bug 仍上抛）。
  static AudioFilterAvailability probe({
    required void Function(String afFilter) applyFilter,
  }) {
    bool check(String label, String filter) {
      try {
        applyFilter(filter);
        return true;
      } on Exception catch (e) {
        debugPrint('[AudioFilterAvailability] filter "$label" unavailable: $e');
        return false;
      }
    }

    return AudioFilterAvailability(
      pan: check('pan', 'pan=stereo|c0=1.00*c0|c1=1.00*c1'),
      adelay: check('adelay', 'adelay=200|200'),
      dynaudnorm: check('dynaudnorm', 'dynaudnorm=f=500:g=15:p=0.95'),
    );
  }
}

/// 音频提交回调类型——控制器在 Apply/OK 提交时构造 [AudioSettings] 快照
/// 调用一次，PlayerFeature 组合根实现它：组合 af 串 → 调现有 setEqualizer
/// 入口 → 顺序持久化 4 个原始值。
typedef AudioCommitCallback = void Function(AudioSettings settings);

/// 确定性 FFmpeg af 链组合器——EQ → balance(pan) → delay(adelay) → normalization(dynaudnorm)。
///
/// 纯静态（不可实例化）：所有逻辑经 [compose] 暴露，输入仅限有界数值 + 固定
/// EQ 表（T-33-03：仅从有界值构建串，精确输出已测）。不可用运行时滤镜段被
/// 省略并 debugPrint 警告；恒等值（空 EQ / 居中 balance / 0 延迟 / 归一化关）
/// 同样省略。永不修改原始用户设置。
class AudioFilterCompositor {
  AudioFilterCompositor._(); // 不可实例化——纯静态组合

  /// 五个固定 EQ 预设（索引顺序，AUDIO-01）。
  static const List<String> eqPresets = [
    '', // 0: 关闭
    'bass=g=10', // 1: 低音增强
    'treble=g=5', // 2: 高音增强
    'bass=g=8,treble=g=6', // 3: 摇滚
    'bass=g=3,treble=g=4', // 4: 流行
  ];

  /// 组合完整 af 链。规范顺序：EQ → pan → adelay → dynaudnorm。
  ///
  /// 不可用段（[availability] 为 false）且用户设了非恒等值时，省略该段并
  /// debugPrint 警告；恒等值段静默省略。EQ 索引额外 clamp 到表范围作纵深防御。
  static String compose(
    AudioSettings settings,
    AudioFilterAvailability availability,
  ) {
    final segments = <String>[];

    // 1. EQ 预设（validator 已 bound 0..4；此处再 clamp 作纵深防御）
    final eqIndex = settings.eqPresetIndex.clamp(0, eqPresets.length - 1);
    final eq = eqPresets[eqIndex];
    if (eq.isNotEmpty) segments.add(eq);

    // 2. balance → pan（居中 0.0 省略；不可用时省略 + 警告）
    _appendPan(segments, settings.balance, availability.pan);

    // 3. sync → adelay（0 省略；不可用时省略 + 警告；正值=音频延后）
    _appendAdelay(segments, settings.syncMs, availability.adelay);

    // 4. normalization → dynaudnorm（关省略；不可用时省略 + 警告）
    _appendDynaudnorm(
      segments,
      settings.normalization,
      availability.dynaudnorm,
    );

    return segments.join(',');
  }

  /// 追加 pan 段：balance=0.0 居中省略；clamp 后两位小数格式化系数。
  static void _appendPan(
    List<String> segments,
    double balance,
    bool available,
  ) {
    if (balance == 0.0) return;
    if (!available) {
      debugPrint(
        '[AudioFilterCompositor] pan unavailable — balance segment omitted',
      );
      return;
    }
    // 左/右声道增益：balance=-1→全左，0→居中，+1→全右
    final b = balance.clamp(-1.0, 1.0);
    final leftGain = (1.0 - b).clamp(0.0, 1.0);
    final rightGain = (1.0 + b).clamp(0.0, 1.0);
    segments.add(
      'pan=stereo|c0=${leftGain.toStringAsFixed(2)}*c0|c1=${rightGain.toStringAsFixed(2)}*c1',
    );
  }

  /// 追加 adelay 段：0 省略；直接传非负值（无 abs()——FFmpeg adelay 无法提前
  /// 音频，故 UI 正值统一表示"音频延后"）。范围 0..10000。
  static void _appendAdelay(
    List<String> segments,
    int syncMs,
    bool available,
  ) {
    if (syncMs == 0) return;
    if (!available) {
      debugPrint(
        '[AudioFilterCompositor] adelay unavailable — delay segment omitted',
      );
      return;
    }
    final ms = syncMs.clamp(0, 10000);
    segments.add('adelay=$ms|$ms');
  }

  /// 追加 dynaudnorm 段：关省略；固定参数 f=500:g=15:p=0.95。
  static void _appendDynaudnorm(
    List<String> segments,
    bool normalization,
    bool available,
  ) {
    if (!normalization) return;
    if (!available) {
      debugPrint(
        '[AudioFilterCompositor] dynaudnorm unavailable — normalization segment omitted',
      );
      return;
    }
    segments.add('dynaudnorm=f=500:g=15:p=0.95');
  }
}
