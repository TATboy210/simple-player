import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/features/player/file_picker_adapters.dart';

/// runner 原生对话框（SimplerPlayerShowOpenDialog）返回码映射的行为锁定。
///
/// FFI 调用本身需真机（runner 符号）；此处锁 Dart 侧的纯映射契约：
/// 1=选中路径、0=取消(null)、-1/-2=参数与缓冲错误、其他负数=HRESULT。
void main() {
  group('RunnerFileDialog.mapResult', () {
    test('code=1 → 返回完整路径', () {
      expect(
        RunnerFileDialog.mapResult(1, r'D:\media\movie.mkv'),
        r'D:\media\movie.mkv',
      );
    });

    test('code=0 → null（用户取消）', () {
      expect(RunnerFileDialog.mapResult(0, r'anything'), isNull);
    });

    test('code=-1 → StateError（参数错误）', () {
      expect(
        () => RunnerFileDialog.mapResult(-1, ''),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('argument'),
          ),
        ),
      );
    });

    test('code=-2 → StateError（路径超出缓冲容量）', () {
      expect(
        () => RunnerFileDialog.mapResult(-2, ''),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('buffer capacity'),
          ),
        ),
      );
    });

    test('其他负数 → StateError 携带 HRESULT 十六进制', () {
      // runner 以 -HRESULT 形式回传，-2147500037 = 0x80004005 (E_FAIL)。
      expect(
        () => RunnerFileDialog.mapResult(-2147500037, ''),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('80004005'),
          ),
        ),
      );
    });
  });

  group('降级哨兵', () {
    test('fallback 哨兵非空且不含空字符歧义（gateway 用 == 判定，非路径冲突）',
        () {
      expect(RunnerFileDialog.fallback, isNotEmpty);
      // 哨兵以 \u0000 包裹 — 真实文件路径不可能包含 NUL，判等无碰撞面。
      expect(RunnerFileDialog.fallback.startsWith('\u0000'), isTrue);
    });
  });
}
