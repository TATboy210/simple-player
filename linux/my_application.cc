// linux/my_application.cc — GTK MethodChannel handler (Flutter Linux runner)
//
// 本文件是参考 stub，需要在 `flutter create --platforms=linux .`
// 生成完整 runner 后合并到 my_application.cc 中。
//
// 集成步骤：
//   1. flutter create --platforms=linux .
//   2. 打开 linux/my_application.cc
//   3. 在 my_application_activate() 中，窗口创建后调用：
//      register_window_channel(app, view);
//   4. 将下面的 method_call_handler 和 register_window_channel 函数复制进去

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <cstring>

static FlMethodChannel* channel = nullptr;

/// 处理来自 Dart 的 MethodChannel 调用。
///
/// 支持的方法：
///   - getGtkWindowHandle: 返回当前活动 GtkWindow 的指针（int64）
///
/// 注意：发送 int64 而非 string —— Dart 端使用 invokeMethod<int>。
static void method_call_handler(FlMethodChannel* fl_channel,
                                 FlMethodCall* method_call,
                                 gpointer user_data) {
  g_autoptr(FlMethodResponse) response = nullptr;
  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "getGtkWindowHandle") == 0) {
    GtkApplication* app = GTK_APPLICATION(user_data);
    GtkWindow* window = gtk_application_get_active_window(app);

    if (window != nullptr) {
      // 发送 int64 指针值 —— 与 Dart invokeMethod<int> 匹配
      g_autoptr(FlValue) result =
          fl_value_new_int(static_cast<int64_t>(reinterpret_cast<intptr_t>(window)));
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
    } else {
      response = FL_METHOD_RESPONSE(fl_method_error_response_new(
          "NO_WINDOW", "No active GTK window found", nullptr));
    }
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

/// 注册 com.simple_player/window MethodChannel。
///
/// 在 my_application_activate() 中窗口创建后调用：
///   register_window_channel(app, view);
void register_window_channel(GtkApplication* app, FlView* view) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  channel = fl_method_channel_new(
      fl_engine_get_binary_message_engine(fl_view_get_engine(view)),
      "com.simple_player/window",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      channel, method_call_handler, app, nullptr);
}
