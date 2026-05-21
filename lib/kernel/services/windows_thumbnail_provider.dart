import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/painting.dart';

import 'thumbnail_provider.dart';

// ─── Win32 Constants ───

const int _siigbfThumbnailOnly = 0x00000001;
const int _biRgb = 0;
const int _dibRgbColors = 0;

// ─── Win32 Structs ───

final class GUID extends Struct {
  @Uint32()
  external int data1;
  @Uint16()
  external int data2;
  @Uint16()
  external int data3;
  @Array(8)
  external Array<Uint8> data4;
}

final class BITMAPINFOHEADER extends Struct {
  @Uint32()
  external int biSize;
  @Int32()
  external int biWidth;
  @Int32()
  external int biHeight;
  @Uint16()
  external int biPlanes;
  @Uint16()
  external int biBitCount;
  @Uint32()
  external int biCompression;
  @Uint32()
  external int biSizeImage;
  @Int32()
  external int biXPelsPerMeter;
  @Int32()
  external int biYPelsPerMeter;
  @Uint32()
  external int biClrUsed;
  @Uint32()
  external int biClrImportant;
}

/// Windows 缩略图提供者 — 通过 COM FFI 读取 Explorer 系统缩略图。
///
/// 使用 `IShellItemImageFactory` 提取与 Explorer 相同的缩略图。
/// Win32 DLL 绑定采用惰性初始化，避免在非 Windows 平台上触发加载错误。
class WindowsThumbnailProvider implements ThumbnailProvider {
  WindowsThumbnailProvider._();

  static final WindowsThumbnailProvider I = WindowsThumbnailProvider._();

  // ─── Lazy Win32 FFI Bindings ───

  static DynamicLibrary? _shell32Lib;
  static DynamicLibrary? _ole32Lib;
  static DynamicLibrary? _gdi32Lib;
  static DynamicLibrary? _user32Lib;

  static DynamicLibrary get _shell32 =>
      _shell32Lib ??= DynamicLibrary.open('shell32.dll');
  static DynamicLibrary get _ole32 =>
      _ole32Lib ??= DynamicLibrary.open('ole32.dll');
  static DynamicLibrary get _gdi32 =>
      _gdi32Lib ??= DynamicLibrary.open('gdi32.dll');
  static DynamicLibrary get _user32 =>
      _user32Lib ??= DynamicLibrary.open('user32.dll');

  // HRESULT CoInitializeEx(LPVOID, DWORD)
  static final _coInitializeEx = _ole32.lookupFunction<
      Int32 Function(Pointer<Void>, Uint32),
      int Function(Pointer<Void>, int)>('CoInitializeEx');

  // HRESULT SHCreateItemFromParsingName(PCWSTR, IBindCtx*, REFIID, void**)
  static final _shCreateItemFromParsingName = _shell32.lookupFunction<
      Int32 Function(
          Pointer<Utf16>, Pointer<Void>, Pointer<GUID>, Pointer<IntPtr>),
      int Function(Pointer<Utf16>, Pointer<Void>, Pointer<GUID>,
          Pointer<IntPtr>)>('SHCreateItemFromParsingName');

  // int GetObjectW(HGDIOBJ, int, LPVOID)
  static final _getObjectW = _gdi32.lookupFunction<
      Int32 Function(IntPtr, Int32, Pointer<Void>),
      int Function(int, int, Pointer<Void>)>('GetObjectW');

  // int GetDIBits(HDC, HBITMAP, UINT, UINT, LPVOID, LPBITMAPINFO, UINT)
  static final _getDIBits = _gdi32.lookupFunction<
      Int32 Function(IntPtr, IntPtr, Uint32, Uint32, Pointer<Void>,
          Pointer<BITMAPINFOHEADER>, Uint32),
      int Function(int, int, int, int, Pointer<Void>,
          Pointer<BITMAPINFOHEADER>, int)>('GetDIBits');

  // HDC GetDC(HWND)
  static final _getDC = _user32.lookupFunction<IntPtr Function(IntPtr),
      int Function(int)>('GetDC');

  // int ReleaseDC(HWND, HDC)
  static final _releaseDC = _user32.lookupFunction<
      Int32 Function(IntPtr, IntPtr),
      int Function(int, int)>('ReleaseDC');

  // BOOL DeleteObject(HGDIOBJ)
  static final _deleteObject = _gdi32.lookupFunction<
      Int32 Function(IntPtr),
      int Function(int)>('DeleteObject');

  static bool _comInitialized = false;

  @override
  Future<ImageProvider?> getThumbnail(String filePath) async {
    final bytes = await _getThumbnailBytes(filePath);
    if (bytes == null) return null;
    return MemoryImage(bytes);
  }

  Future<Uint8List?> _getThumbnailBytes(String filePath) async {
    _ensureComInitialized();

    final ppv = calloc<IntPtr>();
    final pathPtr = filePath.toNativeUtf16();

    try {
      // IShellItem IID: {43826d1e-e718-42ee-bc55-a1e261c37bfe}
      final riid = calloc<GUID>()
        ..ref.data1 = 0x43826D1E
        ..ref.data2 = 0xE718
        ..ref.data3 = 0x42EE
        ..ref.data4[0] = 0xBC
        ..ref.data4[1] = 0x55
        ..ref.data4[2] = 0xA1
        ..ref.data4[3] = 0xE2
        ..ref.data4[4] = 0x61
        ..ref.data4[5] = 0xC3
        ..ref.data4[6] = 0x7B
        ..ref.data4[7] = 0xFE;

      final hr = _shCreateItemFromParsingName(pathPtr, nullptr, riid, ppv);
      calloc.free(riid);

      if (hr != 0 || ppv.value == 0) return null;

      // COM vtable layout (64-bit):
      // [0] QueryInterface  [1] AddRef  [2] Release
      // [3] GetImage  (first method of IShellItemImageFactory)
      final vtable = Pointer<Pointer<IntPtr>>.fromAddress(ppv.value).value;
      final getImagePtr = (vtable + 3).value;

      // HRESULT GetImage(SIZE size, SIIGBF flags, HBITMAP *phbm)
      final getImage = Pointer<
                  NativeFunction<Int32 Function(IntPtr, Int32, Pointer<IntPtr>)>>
              .fromAddress(getImagePtr)
          .asFunction<int Function(int, int, Pointer<IntPtr>)>();

      final hBmpPtr = calloc<IntPtr>();
      // SIZE packed as int: low 32 = width, high 32 = height
      const size256 = 256 | (256 << 32);
      final hrImg = getImage(size256, _siigbfThumbnailOnly, hBmpPtr);

      if (hrImg != 0 || hBmpPtr.value == 0) {
        calloc.free(hBmpPtr);
        return null;
      }

      final hBitmap = hBmpPtr.value;
      calloc.free(hBmpPtr);

      final bytes = _hBitmapToBytes(hBitmap);
      _deleteObject(hBitmap);
      return bytes;
    } on Exception {
      return null;
    } finally {
      // Release IShellItem (IUnknown::Release = vtable[2])
      if (ppv.value != 0) {
        final vtable = Pointer<Pointer<IntPtr>>.fromAddress(ppv.value).value;
        final releaseAddr = (vtable + 2).value;
        final release = Pointer<NativeFunction<Int32 Function()>>
                .fromAddress(releaseAddr)
            .asFunction<int Function()>();
        release();
      }
      calloc.free(ppv);
      calloc.free(pathPtr);
    }
  }

  /// Convert HBITMAP to BMP file bytes for Flutter's Image.memory().
  Uint8List? _hBitmapToBytes(int hBitmap) {
    final bih = calloc<BITMAPINFOHEADER>();
    bih.ref.biSize = sizeOf<BITMAPINFOHEADER>();

    if (_getObjectW(hBitmap, sizeOf<BITMAPINFOHEADER>(), bih.cast()) == 0) {
      calloc.free(bih);
      return null;
    }

    final width = bih.ref.biWidth;
    final height = bih.ref.biHeight.abs();

    // Query 32-bit BGRA pixels
    bih.ref.biPlanes = 1;
    bih.ref.biBitCount = 32;
    bih.ref.biCompression = _biRgb;
    bih.ref.biSizeImage = width * height * 4;

    final pixels = calloc<Uint8>(bih.ref.biSizeImage);
    final hdc = _getDC(0);
    _getDIBits(hdc, hBitmap, 0, height, pixels.cast(), bih, _dibRgbColors);
    _releaseDC(0, hdc);

    // Build BMP file: BITMAPFILEHEADER(14) + BITMAPINFOHEADER(40) + pixels
    const fhSize = 14;
    final ihSize = sizeOf<BITMAPINFOHEADER>();
    final bmpSize = fhSize + ihSize + bih.ref.biSizeImage;
    final bmp = Uint8List(bmpSize);
    final bd = ByteData.sublistView(bmp);

    // BITMAPFILEHEADER
    bd.setUint16(0, 0x4D42, Endian.little); // signature 'BM'
    bd.setUint32(2, bmpSize, Endian.little);
    bd.setUint32(10, fhSize + ihSize, Endian.little); // pixel data offset

    // BITMAPINFOHEADER (positive height = bottom-up)
    bih.ref.biHeight = height;
    final bihBytes = bih.cast<Uint8>().asTypedList(ihSize);
    bmp.setRange(fhSize, fhSize + ihSize, bihBytes);

    // Copy pixels (flip rows for bottom-up BMP)
    final rowBytes = width * 4;
    for (int y = 0; y < height; y++) {
      final src = y * rowBytes;
      final dst = fhSize + ihSize + (height - 1 - y) * rowBytes;
      bmp.setRange(
          dst,
          dst + rowBytes,
          pixels
              .asTypedList(bih.ref.biSizeImage)
              .sublist(src, src + rowBytes));
    }

    calloc.free(bih);
    calloc.free(pixels);
    return bmp;
  }

  void _ensureComInitialized() {
    if (!_comInitialized) {
      _coInitializeEx(nullptr, 0x2); // COINIT_APARTMENTTHREADED
      _comInitialized = true;
    }
  }
}
