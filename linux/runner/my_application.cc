#include "my_application.h"

#include <cstring>
#include <flutter_linux/flutter_linux.h>

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// ─── runner C ABI 导出（与 Windows/macOS 同模式，见 CONTRACT.md）───

namespace {

// 关门专线 — Dart 经 SetCloseNotifier 注册（FFI NativeCallable.listener，
// 自 GTK 主循环安全投递回 UI isolate）。delete-event 有通知器时阻断原生
// 销毁并唤起 Dart hide-first persist→exit 序列；未注册（启动极早期/降级）
// 放行默认关闭。
using CloseNotifier = void (*)();
CloseNotifier g_close_notifier = nullptr;

// 主窗口句柄槽 — activate 时赋值。Dart 经
// SimplerPlayerGetMainWindowHandle 读取（隐藏态即可用，不依赖焦点）。
GtkWindow* g_main_window = nullptr;

// X11 WM_DELETE_WINDOW 与 Wayland xdg_toplevel.close 都归结为 GTK
// delete-event — 单点拦截即覆盖两后端（返回 TRUE 阻断销毁）。
gboolean OnDeleteEvent(GtkWidget* widget, GdkEvent* event, gpointer user_data) {
  if (g_close_notifier != nullptr) {
    g_close_notifier();
    return TRUE;
  }
  return FALSE;
}

}  // namespace

extern "C" __attribute__((visibility("default"))) void SetCloseNotifier(
    CloseNotifier notifier) {
  g_close_notifier = notifier;
}

extern "C" __attribute__((visibility("default"))) void*
SimplerPlayerGetMainWindowHandle() {
  return g_main_window;
}

// ─── MethodChannel: com.simple_player/file_picker_attention ───
// （旧 com.simple_player/window 的 getGtkWindowHandle 已退役 — Dart 侧改经
// 上面的 C 符号导出取句柄；fullscreen 通道为 window_manager 时代遗产，
// Dart 零消费者，一并删除。）

namespace {

FlMethodChannel* file_picker_attention_channel = nullptr;

void file_picker_attention_method_handler(
    FlMethodChannel* channel, FlMethodCall* method_call, gpointer user_data) {
  g_autoptr(FlMethodResponse) response = nullptr;
  const gchar* method = fl_method_call_get_name(method_call);
  if (strcmp(method, "focusExistingPicker") != 0) {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
    fl_method_call_respond(method_call, response, nullptr);
    return;
  }

  GtkApplication* app = GTK_APPLICATION(user_data);
  GtkWindow* window = gtk_application_get_active_window(app);
  // Portal/Wayland pickers are external processes and cannot be focused safely.
  // Ring GTK's system bell instead of falsely bringing the player to front.
  if (window != nullptr) {
    gtk_widget_error_bell(GTK_WIDGET(window));
  }

  g_autoptr(FlValue) result = fl_value_new_bool(window != nullptr);
  response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  fl_method_call_respond(method_call, response, nullptr);
}

void register_file_picker_attention_channel(GtkApplication* app, FlView* view) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  file_picker_attention_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "com.simple_player/file_picker_attention", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      file_picker_attention_channel, file_picker_attention_method_handler, app,
      nullptr);
}

}  // namespace

// ─── Flutter lifecycle ───

// Called when first Flutter frame received.
// 首帧后亮窗 failsafe — 与 Windows runner 的 SetNextFrameCallback(Show) 对齐；
// Dart reveal() 是主路径（na show 幂等，两者先后无害）。
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  g_main_window = window;

  // 无系统装饰/CSD 标题栏 — frameless 由 Dart 侧 titleBarStyle=hidden
  // （nativeapi gtk_window_set_decorated(FALSE)）统一决定；边缘 resize 由
  // Dart UI 热区经 startResizing 补（CONTRACT.md D7）。标题必须保留：
  // Wayland 任务栏标识，且 nativeapi 的 decorated 切换以 title 非空为前提。
  gtk_window_set_title(window, "simple_player_flutter");

  // 关窗专线拦截点（✕ 的系统路径；自绘 ✕ 走 Dart close()）。
  g_signal_connect(window, "delete-event", G_CALLBACK(OnDeleteEvent), nullptr);

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  register_file_picker_attention_channel(GTK_APPLICATION(application), view);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(application);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(application);

  // Perform any actions required at application shutdown.
  g_main_window = nullptr;

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID (defined in the top-level
  // CMakeLists.txt). This is used to set the application ID, and helps various
  // systems such as the desktop environment and application launchers identify
  // the application.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
