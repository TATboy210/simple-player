// ignore_for_file: non_constant_identifier_names
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

/// libmpv C API FFI 绑定
///
/// 只绑定实际存在的 mpv 导出函数。
/// 函数签名来自 client.h。

// --- 函数签名 ---

typedef MpvCreateNative = Pointer<Void> Function();
typedef MpvCreateDart = Pointer<Void> Function();

typedef MpvInitializeNative = Int32 Function(Pointer<Void>);
typedef MpvInitializeDart = int Function(Pointer<Void>);

typedef MpvCommandNative = Int32 Function(Pointer<Void>, Pointer<Pointer<Utf8>>);
typedef MpvCommandDart = int Function(Pointer<Void>, Pointer<Pointer<Utf8>>);

typedef MpvSetOptionStringNative = Int32 Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);
typedef MpvSetOptionStringDart = int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);

typedef MpvSetPropertyStringNative = Int32 Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);
typedef MpvSetPropertyStringDart = int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);

/// mpv_get_property(ctx, name, format, data) — 通用属性读取
typedef MpvGetPropertyNative = Int32 Function(Pointer<Void>, Pointer<Utf8>, Int32, Pointer<Void>);
typedef MpvGetPropertyDart = int Function(Pointer<Void>, Pointer<Utf8>, int, Pointer<Void>);

typedef MpvGetPropertyStringNative = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>);
typedef MpvGetPropertyStringDart = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>);

typedef MpvObservePropertyNative = Int32 Function(Pointer<Void>, Int64, Pointer<Utf8>, Int32);
typedef MpvObservePropertyDart = int Function(Pointer<Void>, int, Pointer<Utf8>, int);

typedef MpvSetWakeupCallbackNative = Void Function(Pointer<Void>, Pointer<NativeFunction<Void Function(Pointer<Void>)>>, Pointer<Void>);
typedef MpvSetWakeupCallbackDart = void Function(Pointer<Void>, Pointer<NativeFunction<Void Function(Pointer<Void>)>>, Pointer<Void>);

typedef MpvWaitEventNative = Pointer<MpvEvent> Function(Pointer<Void>, Double);
typedef MpvWaitEventDart = Pointer<MpvEvent> Function(Pointer<Void>, double);

typedef MpvTerminateDestroyNative = Void Function(Pointer<Void>);
typedef MpvTerminateDestroyDart = void Function(Pointer<Void>);

typedef MpvFreeNative = Void Function(Pointer<Void>);
typedef MpvFreeDart = void Function(Pointer<Void>);

// --- 结构体 ---

/// mpv_event
final class MpvEvent extends Struct {
  @Int32()
  external int event_id;
  @Int32()
  external int error;
  @Int64()
  external int reply_userdata;
  external Pointer<Void> data;
}

// --- 常量 ---

abstract class MpvFormat {
  static const int none = 0;
  static const int string = 1;
  static const int osdString = 2;
  static const int flag = 3;
  static const int int64 = 4;
  static const int double_ = 5;
}

abstract class MpvEventId {
  static const int none = 0;
  static const int shutdown = 1;
  static const int startFile = 6;
  static const int endFile = 7;
  static const int fileLoaded = 8;
  static const int tracksChanged = 9;
  static const int trackSwitched = 10;
  static const int pause = 12;
  static const int unpause = 13;
  static const int seek = 20;
  static const int propertyChange = 22;
}

abstract class MpvError {
  static const int success = 0;
}

// --- 绑定类 ---

class MpvBindings {
  late final DynamicLibrary _lib;

  late final MpvCreateDart mpv_create;
  late final MpvInitializeDart mpv_initialize;
  late final MpvCommandDart mpv_command;
  late final MpvSetOptionStringDart mpv_set_option_string;
  late final MpvSetPropertyStringDart mpv_set_property_string;
  late final MpvGetPropertyDart mpv_get_property;
  late final MpvGetPropertyStringDart mpv_get_property_string;
  late final MpvObservePropertyDart mpv_observe_property;
  late final MpvSetWakeupCallbackDart mpv_set_wakeup_callback;
  late final MpvWaitEventDart mpv_wait_event;
  late final MpvTerminateDestroyDart mpv_terminate_destroy;
  late final MpvFreeDart mpv_free;

  MpvBindings() {
    _lib = _loadLib();
    _bindFunctions();
  }

  DynamicLibrary _loadLib() {
    if (Platform.isWindows) return DynamicLibrary.open('libmpv-2.dll');
    if (Platform.isLinux) return DynamicLibrary.open('libmpv.so');
    if (Platform.isMacOS) return DynamicLibrary.open('libmpv.dylib');
    throw UnsupportedError('Unsupported: ${Platform.operatingSystem}');
  }

  void _bindFunctions() {
    mpv_create = _lib.lookupFunction<MpvCreateNative, MpvCreateDart>('mpv_create');
    mpv_initialize = _lib.lookupFunction<MpvInitializeNative, MpvInitializeDart>('mpv_initialize');
    mpv_command = _lib.lookupFunction<MpvCommandNative, MpvCommandDart>('mpv_command');
    mpv_set_option_string = _lib.lookupFunction<MpvSetOptionStringNative, MpvSetOptionStringDart>('mpv_set_option_string');
    mpv_set_property_string = _lib.lookupFunction<MpvSetPropertyStringNative, MpvSetPropertyStringDart>('mpv_set_property_string');
    mpv_get_property = _lib.lookupFunction<MpvGetPropertyNative, MpvGetPropertyDart>('mpv_get_property');
    mpv_get_property_string = _lib.lookupFunction<MpvGetPropertyStringNative, MpvGetPropertyStringDart>('mpv_get_property_string');
    mpv_observe_property = _lib.lookupFunction<MpvObservePropertyNative, MpvObservePropertyDart>('mpv_observe_property');
    mpv_set_wakeup_callback = _lib.lookupFunction<MpvSetWakeupCallbackNative, MpvSetWakeupCallbackDart>('mpv_set_wakeup_callback');
    mpv_wait_event = _lib.lookupFunction<MpvWaitEventNative, MpvWaitEventDart>('mpv_wait_event');
    mpv_terminate_destroy = _lib.lookupFunction<MpvTerminateDestroyNative, MpvTerminateDestroyDart>('mpv_terminate_destroy');
    mpv_free = _lib.lookupFunction<MpvFreeNative, MpvFreeDart>('mpv_free');
  }
}
