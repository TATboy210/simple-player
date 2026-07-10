#include "include/fullscreen_window/fullscreen_window_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>

#include <cstring>

#include "fullscreen_window_plugin_private.h"

#define FULLSCREEN_WINDOW_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), fullscreen_window_plugin_get_type(), \
                              FullscreenWindowPlugin))

struct _FullscreenWindowPlugin {
  GObject parent_instance;

  FlPluginRegistrar *registrar; //Jacky
  FlMethodChannel *channel;     // 用于向 Dart 层发送 onFullScreenChanged 回调 (D-P12)
};

G_DEFINE_TYPE(FullscreenWindowPlugin, fullscreen_window_plugin, g_object_get_type())

// --------------------------------------------------------------------------

GtkWindow* get_window(FullscreenWindowPlugin* self) {
  FlView* view = fl_plugin_registrar_get_view(self->registrar);
  if (view == nullptr)
    return nullptr;

  return GTK_WINDOW(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

FlMethodResponse* getScreenSize() {
  GdkDisplay *display = gdk_display_get_default();
  GdkMonitor *monitor = gdk_display_get_primary_monitor(display);
  GdkRectangle geometry;
  gdk_monitor_get_geometry(monitor, &geometry);

  int width = geometry.width;
  int height = geometry.height;

  g_autoptr(FlValue) result_data = fl_value_new_map();
  fl_value_set_string_take(result_data, "width", fl_value_new_int(width));
  fl_value_set_string_take(result_data, "height", fl_value_new_int(height));

  return FL_METHOD_RESPONSE(fl_method_success_response_new(result_data));
}

// --------------------------------------------------------------------------
// window-state-event 信号回调 (D-P12)
//
// GDK 在窗口状态变化时触发此信号，包括全屏状态变化。
// 检查 changed_mask 中的 GDK_WINDOW_STATE_FULLSCREEN 位，
// 通过 MethodChannel 将 isFullScreen 状态发送到 Dart 层。
static gboolean on_window_state_changed(GtkWidget *widget,
    GdkEventWindowState *event, gpointer user_data) {
  FullscreenWindowPlugin *plugin = FULLSCREEN_WINDOW_PLUGIN(user_data);

  // 只处理全屏相关的状态变化
  if (event->changed_mask & GDK_WINDOW_STATE_FULLSCREEN) {
    gboolean is_fullscreen =
        event->new_window_state & GDK_WINDOW_STATE_FULLSCREEN;

    // 通过 MethodChannel 通知 Dart 层 (D-P12)
    g_autoptr(FlValue) args = fl_value_new_map();
    fl_value_set_string_take(args, "isFullScreen",
        fl_value_new_bool(is_fullscreen));
    fl_method_channel_invoke_method(plugin->channel,
        "onFullScreenChanged", args, NULL, NULL, NULL);
  }

  return FALSE; // 不拦截事件，继续传播到其他处理器
}

// --------------------------------------------------------------------------

// Called when a method call is received from Flutter.
static void fullscreen_window_plugin_handle_method_call(
    FullscreenWindowPlugin* self,
    FlMethodCall* method_call) {

  g_autoptr(FlMethodResponse) response = nullptr;
  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  if (strcmp(method, "setFullScreen") == 0) {
    bool isFullScreen = fl_value_get_bool(fl_value_lookup_string(args, "isFullScreen"));
    if (isFullScreen) {
      gtk_window_fullscreen(get_window(self));
    } else {
      gtk_window_unfullscreen(get_window(self));
    }

    g_autoptr(FlValue) result = fl_value_new_bool(true);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if (strcmp(method, "getScreenSize") == 0) {
    response = getScreenSize();
  } else if (strcmp(method, "getFullScreenState") == 0) {
    // 查询 GDK 窗口的真实全屏状态 (D-P12)
    GtkWindow *window = get_window(self);
    gboolean is_fullscreen = FALSE;
    if (window != nullptr) {
      GdkWindow *gdk_window = gtk_widget_get_window(GTK_WIDGET(window));
      if (gdk_window != nullptr) {
        GdkWindowState state = gdk_window_get_state(gdk_window);
        is_fullscreen = state & GDK_WINDOW_STATE_FULLSCREEN;
      }
    }
    g_autoptr(FlValue) result = fl_value_new_bool(is_fullscreen);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if (strcmp(method, "getPlatformNotes") == 0) {
    // 返回 WM 类型信息 (D-P13) — 运行时检测桌面环境
    const gchar *session_type = g_getenv("XDG_SESSION_TYPE");
    const gchar *desktop = g_getenv("XDG_CURRENT_DESKTOP");
    const gchar *wm_session = g_getenv("GDMSESSION");

    g_autofree gchar *notes = g_strdup_printf(
        "session=%s, desktop=%s, wm=%s",
        session_type ? session_type : "unknown",
        desktop ? desktop : "unknown",
        wm_session ? wm_session : "unknown");

    g_autoptr(FlValue) result = fl_value_new_string(notes);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void fullscreen_window_plugin_dispose(GObject* object) {
  FullscreenWindowPlugin *self = FULLSCREEN_WINDOW_PLUGIN(object);

  // 释放 MethodChannel 引用 (D-P12)
  g_clear_object(&self->channel);

  G_OBJECT_CLASS(fullscreen_window_plugin_parent_class)->dispose(object);
}

static void fullscreen_window_plugin_class_init(FullscreenWindowPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = fullscreen_window_plugin_dispose;
}

static void fullscreen_window_plugin_init(FullscreenWindowPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  FullscreenWindowPlugin* plugin = FULLSCREEN_WINDOW_PLUGIN(user_data);
  fullscreen_window_plugin_handle_method_call(plugin, method_call);
}

void fullscreen_window_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  FullscreenWindowPlugin* plugin = FULLSCREEN_WINDOW_PLUGIN(
      g_object_new(fullscreen_window_plugin_get_type(), nullptr));

  plugin->registrar = FL_PLUGIN_REGISTRAR(g_object_ref(registrar)); //Jacky

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "fullscreen_window",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  // 保存 channel 引用 — 用于发送 onFullScreenChanged 回调到 Dart 层 (D-P12)
  plugin->channel = FL_METHOD_CHANNEL(g_object_ref(channel));

  // 注册 window-state-event 信号监听 (D-P12)
  // 当 GDK 窗口状态变化（包括全屏）时触发 on_window_state_changed
  FlView *view = fl_plugin_registrar_get_view(registrar);
  if (view != nullptr) {
    GtkWidget *toplevel = gtk_widget_get_toplevel(GTK_WIDGET(view));
    g_signal_connect(G_OBJECT(toplevel), "window-state-event",
                     G_CALLBACK(on_window_state_changed), plugin);
  }

  g_object_unref(plugin);
}
