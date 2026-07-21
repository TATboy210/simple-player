/// 毫秒格式化为 HH:MM:SS 或 MM:SS。
///
/// Formats a millisecond value into a human-readable time string.
///
/// Returns `MM:SS` when hours are zero, `HH:MM:SS` otherwise.
/// Returns `00:00` for non-positive input.
String formatMs(int ms) {
  if (ms <= 0) return '00:00';
  final totalSeconds = ms ~/ 1000;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}
