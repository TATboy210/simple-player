#ifndef MPV_RENDER_PLUGIN_H_
#define MPV_RENDER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <flutter/texture_registrar.h>

#include <d3d11.h>
#include <dxgi.h>
#include <wrl/client.h>
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>

#include <atomic>
#include <memory>
#include <mutex>
#include <thread>

#include "../libmpv/client.h"
#include "../libmpv/render.h"
#include "../libmpv/render_gl.h"

using Microsoft::WRL::ComPtr;

namespace mpv_render_plugin {

class MpvRenderPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  MpvRenderPlugin(
      flutter::PluginRegistrarWindows* registrar,
      std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel);

  virtual ~MpvRenderPlugin();

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  bool CreateRenderContext(int64_t mpv_handle_ptr, int width, int height);
  void DestroyRenderContext();
  void RenderThreadFunc();
  static void OnMpvUpdate(void* ctx);

  bool InitANGLE();
  void ShutdownANGLE();
  bool CreateGLResources(int width, int height);
  void DestroyGLResources();
  bool CreateSharedTexture(int width, int height);
  void DestroySharedTexture();
  bool RegisterFlutterTexture();
  void UnregisterFlutterTexture();

  flutter::PluginRegistrarWindows* registrar_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  flutter::TextureRegistrar* texture_registrar_;

  // ANGLE
  EGLDisplay egl_display_ = EGL_NO_DISPLAY;
  EGLContext egl_context_ = EGL_NO_CONTEXT;
  EGLSurface egl_surface_ = EGL_NO_SURFACE;
  EGLConfig egl_config_ = nullptr;

  // GL
  GLuint gl_texture_ = 0;
  GLuint gl_fbo_ = 0;

  // D3D11
  ComPtr<ID3D11Device> d3d_device_;
  ComPtr<ID3D11DeviceContext> d3d_context_;
  ComPtr<ID3D11Texture2D> shared_texture_;
  HANDLE shared_handle_ = nullptr;

  // mpv
  mpv_handle* mpv_ = nullptr;
  mpv_render_context* mpv_render_ctx_ = nullptr;

  // Flutter texture
  int64_t texture_id_ = -1;
  int texture_width_ = 0;
  int texture_height_ = 0;

  // Render thread
  std::thread render_thread_;
  std::atomic<bool> render_running_{false};
  HANDLE frame_ready_event_ = nullptr;

  // Resize race condition protection (#3)
  std::atomic<bool> pending_resize_{false};
  int pending_width_ = 0;
  int pending_height_ = 0;

  // GPU surface descriptor as member variable to avoid multi-instance conflict (#4)
  FlutterDesktopGpuSurfaceDescriptor surface_desc_ = {};

  // Flutter texture variant for GPU surface registration
  std::unique_ptr<flutter::TextureVariant> texture_;

  // Zero-copy: ANGLE EGL surface directly maps D3D11 shared texture
  EGLSurface render_surface_ = EGL_NO_SURFACE;

  // D3D11 fence for GPU sync
  ComPtr<ID3D11Query> fence_query_;

  std::mutex mutex_;
};

}  // namespace mpv_render_plugin

// C-linkage entry point for Flutter plugin registration
extern "C" {
__declspec(dllexport) void MpvRenderPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);
}

#endif  // MPV_RENDER_PLUGIN_H_
