#include "mpv_render_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <flutter/texture_registrar.h>

#include <d3d11.h>
#include <dxgi.h>
#include <wrl/client.h>

#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <EGL/eglext_angle.h>
#include <GLES2/gl2.h>
#include <GLES2/gl2ext.h>
#include <GLES2/gl2ext_angle.h>

#include <algorithm>
#include <memory>
#include <mutex>
#include <vector>

#include "../libmpv/client.h"
#include "../libmpv/render.h"
#include "../libmpv/render_gl.h"

// ANGLE EGL extension function pointers
typedef EGLDisplay(EGLAPIENTRYP PFNEGLGETPLATFORMDISPLAYEXTPROC)(
    EGLenum platform, void *native_display, const EGLint *attrib_list);

// ANGLE D3D11 interop: eglCreatePbufferFromClientBufferANGLE function pointer
typedef EGLSurface(EGLAPIENTRYP PFNEGLCREATEPBUFFERFROMCLIENTBUFFERANGLEPROC)(
    EGLDisplay dpy, EGLenum buftype, EGLClientBuffer buffer,
    EGLConfig config, const EGLint *attrib_list);

// Fallback: if eglext_angle.h does not define this constant (include order issue)
#ifndef EGL_D3D11_TEXTURE_ANGLE
#define EGL_D3D11_TEXTURE_ANGLE 0x3484
#endif

// Fallback: EGL_PLATFORM_ANGLE_D3D11_DEVICE_ANGLE for passing D3D11 device
#ifndef EGL_PLATFORM_ANGLE_D3D11_DEVICE_ANGLE
#define EGL_PLATFORM_ANGLE_D3D11_DEVICE_ANGLE 0x3488
#endif

namespace mpv_render_plugin {

// ============================================================
// Registration
// ============================================================

void MpvRenderPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "com.simple_player/mpv_render",
          &flutter::StandardMethodCodec::GetInstance());

  auto *channel_ptr = channel.get();
  auto plugin = std::make_unique<MpvRenderPlugin>(registrar, std::move(channel));

  channel_ptr->SetMethodCallHandler(
      [plugin_ref = plugin.get()](const auto &call, auto result) {
        plugin_ref->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

MpvRenderPlugin::MpvRenderPlugin(
    flutter::PluginRegistrarWindows *registrar,
    std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel)
    : registrar_(registrar), channel_(std::move(channel)) {
  texture_registrar_ = registrar->texture_registrar();
}

MpvRenderPlugin::~MpvRenderPlugin() {
  DestroyRenderContext();
}

// ============================================================
// MethodChannel
// ============================================================

void MpvRenderPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  if (call.method_name() == "CreateRenderTexture") {
    const auto *args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (!args) {
      result->Error("INVALID_ARGS", "Expected map");
      return;
    }
    auto mpv_it = args->find(flutter::EncodableValue("mpv_handle"));
    auto w_it = args->find(flutter::EncodableValue("width"));
    auto h_it = args->find(flutter::EncodableValue("height"));
    if (mpv_it == args->end() || w_it == args->end() || h_it == args->end()) {
      result->Error("INVALID_ARGS", "Missing mpv_handle/width/height");
      return;
    }

    int64_t mpv_ptr = std::get<int64_t>(mpv_it->second);
    int w = static_cast<int>(std::get<int64_t>(w_it->second));
    int h = static_cast<int>(std::get<int64_t>(h_it->second));

    if (CreateRenderContext(mpv_ptr, w, h)) {
      flutter::EncodableMap resp;
      resp[flutter::EncodableValue("textureId")] = texture_id_;
      resp[flutter::EncodableValue("width")] = texture_width_;
      resp[flutter::EncodableValue("height")] = texture_height_;
      result->Success(flutter::EncodableValue(resp));
    } else {
      result->Error("CREATE_FAILED", "Failed to create render context");
    }
  } else if (call.method_name() == "Resize") {
    const auto *args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (!args) {
      result->Error("INVALID_ARGS", "Expected map");
      return;
    }
    auto w_it = args->find(flutter::EncodableValue("width"));
    auto h_it = args->find(flutter::EncodableValue("height"));
    if (w_it == args->end() || h_it == args->end()) {
      result->Error("INVALID_ARGS", "Missing width/height");
      return;
    }
    int w = static_cast<int>(std::get<int64_t>(w_it->second));
    int h = static_cast<int>(std::get<int64_t>(h_it->second));
    pending_width_ = w;
    pending_height_ = h;
    pending_resize_.store(true, std::memory_order_release);
    result->Success(flutter::EncodableValue(true));
  } else if (call.method_name() == "GetFrameInfo") {
    flutter::EncodableMap resp;
    resp[flutter::EncodableValue("width")] = texture_width_;
    resp[flutter::EncodableValue("height")] = texture_height_;
    resp[flutter::EncodableValue("format")] = static_cast<int64_t>(kFlutterDesktopPixelFormatBGRA8888);
    result->Success(flutter::EncodableValue(resp));
  } else if (call.method_name() == "ReleaseRenderTexture") {
    DestroyRenderContext();
    result->Success(flutter::EncodableValue(true));
  } else {
    result->NotImplemented();
  }
}

// ============================================================
// Render Context
// ============================================================

bool MpvRenderPlugin::CreateRenderContext(int64_t mpv_handle_ptr,
                                          int width, int height) {
  std::lock_guard<std::mutex> lock(mutex_);
  DestroyRenderContext();

  mpv_ = reinterpret_cast<mpv_handle *>(mpv_handle_ptr);
  if (!mpv_) return false;

  texture_width_ = width;
  texture_height_ = height;

  if (!InitANGLE()) return false;

  // Zero-copy: create D3D11 shared texture first, then create ANGLE render surface from it
  if (!CreateSharedTexture(width, height)) { ShutdownANGLE(); return false; }

  // Create render surface: ANGLE directly uses D3D11 texture as GL render target
  auto eglCreatePbufferFromClientBufferANGLE =
      reinterpret_cast<PFNEGLCREATEPBUFFERFROMCLIENTBUFFERANGLEPROC>(
          eglGetProcAddress("eglCreatePbufferFromClientBufferANGLE"));
  if (eglCreatePbufferFromClientBufferANGLE && shared_handle_) {
    const EGLint surf_attrs[] = {
        EGL_WIDTH, width, EGL_HEIGHT, height, EGL_NONE};
    render_surface_ = eglCreatePbufferFromClientBufferANGLE(
        egl_display_, EGL_D3D11_TEXTURE_ANGLE,
        static_cast<EGLClientBuffer>(shared_handle_),
        egl_config_, surf_attrs);
  }
  if (render_surface_ != EGL_NO_SURFACE) {
    egl_surface_ = render_surface_;
    eglMakeCurrent(egl_display_, egl_surface_, egl_surface_, egl_context_);
  }

  if (!CreateGLResources(width, height)) {
    DestroySharedTexture(); ShutdownANGLE(); return false;
  }

  // Create mpv render context
  mpv_opengl_init_params gl_params = {};
  gl_params.get_proc_address = [](void *, const char *name) -> void * {
    return reinterpret_cast<void *>(eglGetProcAddress(name));
  };

  int advanced = 1;
  mpv_render_param params[] = {
      {MPV_RENDER_PARAM_API_TYPE,
       const_cast<void *>(static_cast<const void *>(MPV_RENDER_API_TYPE_OPENGL))},
      {MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, &gl_params},
      {MPV_RENDER_PARAM_ADVANCED_CONTROL, &advanced},
      {static_cast<mpv_render_param_type>(0), nullptr},
  };

  if (mpv_render_context_create(&mpv_render_ctx_, mpv_, params) < 0) {
    DestroySharedTexture(); DestroyGLResources(); ShutdownANGLE();
    return false;
  }

  frame_ready_event_ = CreateEventA(nullptr, FALSE, FALSE, nullptr);
  mpv_render_context_set_update_callback(mpv_render_ctx_, OnMpvUpdate, this);

  if (!RegisterFlutterTexture()) {
    mpv_render_context_free(mpv_render_ctx_); mpv_render_ctx_ = nullptr;
    DestroySharedTexture(); DestroyGLResources(); ShutdownANGLE();
    return false;
  }

  // D3D11 fence query for GPU sync
  D3D11_QUERY_DESC qd = {D3D11_QUERY_EVENT, 0};
  d3d_device_->CreateQuery(&qd, &fence_query_);

  render_running_ = true;
  render_thread_ = std::thread(&MpvRenderPlugin::RenderThreadFunc, this);
  return true;
}

void MpvRenderPlugin::DestroyRenderContext() {
  render_running_ = false;
  if (frame_ready_event_) SetEvent(frame_ready_event_);
  if (render_thread_.joinable()) render_thread_.join();

  if (mpv_render_ctx_) {
    mpv_render_context_set_update_callback(mpv_render_ctx_, nullptr, nullptr);
    mpv_render_context_free(mpv_render_ctx_);
    mpv_render_ctx_ = nullptr;
  }

  UnregisterFlutterTexture();
  DestroyGLResources();
  if (render_surface_ != EGL_NO_SURFACE) {
    eglDestroySurface(egl_display_, render_surface_);
    render_surface_ = EGL_NO_SURFACE;
  }
  DestroySharedTexture();
  ShutdownANGLE();

  // Cleanup preallocated resources
  fence_query_.Reset();

  if (frame_ready_event_) {
    CloseHandle(frame_ready_event_);
    frame_ready_event_ = nullptr;
  }
  mpv_ = nullptr;
}

// ============================================================
// ANGLE
// ============================================================

bool MpvRenderPlugin::InitANGLE() {
  auto eglGetPlatformDisplayEXT =
      reinterpret_cast<PFNEGLGETPLATFORMDISPLAYEXTPROC>(
          eglGetProcAddress("eglGetPlatformDisplayEXT"));
  if (!eglGetPlatformDisplayEXT) return false;

  const EGLint display_attrs[] = {
      EGL_PLATFORM_ANGLE_TYPE_ANGLE, EGL_PLATFORM_ANGLE_TYPE_D3D11_ANGLE,
      EGL_PLATFORM_ANGLE_D3D11_DEVICE_ANGLE, EGL_DONT_CARE,
      EGL_NONE,
  };

  egl_display_ = eglGetPlatformDisplayEXT(EGL_PLATFORM_ANGLE_ANGLE,
                                           nullptr, display_attrs);
  if (egl_display_ == EGL_NO_DISPLAY) return false;
  if (!eglInitialize(egl_display_, nullptr, nullptr)) return false;

  const EGLint config_attrs[] = {
      EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
      EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8, EGL_ALPHA_SIZE, 8,
      EGL_NONE,
  };
  EGLint num_configs;
  if (!eglChooseConfig(egl_display_, config_attrs, &egl_config_, 1, &num_configs) ||
      num_configs == 0) return false;

  const EGLint ctx_attrs[] = {EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE};
  egl_context_ = eglCreateContext(egl_display_, egl_config_, EGL_NO_CONTEXT, ctx_attrs);
  if (egl_context_ == EGL_NO_CONTEXT) return false;

  const EGLint surf_attrs[] = {EGL_WIDTH, 1, EGL_HEIGHT, 1, EGL_NONE};
  egl_surface_ = eglCreatePbufferSurface(egl_display_, egl_config_, surf_attrs);
  if (egl_surface_ == EGL_NO_SURFACE) return false;

  if (!eglMakeCurrent(egl_display_, egl_surface_, egl_surface_, egl_context_))
    return false;

  // Get ANGLE's internal D3D11 device
  auto eglQueryDisplayAttribANGLE =
      reinterpret_cast<PFNEGLQUERYDISPLAYATTRIBANGLEPROC>(
          eglGetProcAddress("eglQueryDisplayAttribANGLE"));
  auto eglQueryDeviceAttribEXT =
      reinterpret_cast<PFNEGLQUERYDEVICEATTRIBEXTPROC>(
          eglGetProcAddress("eglQueryDeviceAttribEXT"));

  if (eglQueryDisplayAttribANGLE && eglQueryDeviceAttribEXT) {
    EGLAttrib dev_attr;
    if (eglQueryDisplayAttribANGLE(egl_display_, EGL_DEVICE_EXT, &dev_attr)) {
      EGLDeviceEXT device = reinterpret_cast<EGLDeviceEXT>(dev_attr);
      EGLAttrib d3d_attr;
      if (eglQueryDeviceAttribEXT(device, EGL_D3D11_DEVICE_ANGLE, &d3d_attr)) {
        d3d_device_ = reinterpret_cast<ID3D11Device *>(d3d_attr);
        d3d_device_->GetImmediateContext(&d3d_context_);
      }
    }
  }
  if (!d3d_device_ || !d3d_context_) return false;

  ComPtr<ID3D10Multithread> mt;
  if (SUCCEEDED(d3d_device_.As(&mt))) mt->SetMultithreadProtected(TRUE);

  return true;
}

void MpvRenderPlugin::ShutdownANGLE() {
  d3d_context_.Reset();
  d3d_device_.Reset();
  if (egl_display_ != EGL_NO_DISPLAY) {
    eglMakeCurrent(egl_display_, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    if (egl_surface_ != EGL_NO_SURFACE) {
      eglDestroySurface(egl_display_, egl_surface_);
      egl_surface_ = EGL_NO_SURFACE;
    }
    if (egl_context_ != EGL_NO_CONTEXT) {
      eglDestroyContext(egl_display_, egl_context_);
      egl_context_ = EGL_NO_CONTEXT;
    }
    eglTerminate(egl_display_);
    egl_display_ = EGL_NO_DISPLAY;
  }
}

// ============================================================
// GL Resources
// ============================================================

bool MpvRenderPlugin::CreateGLResources(int width, int height) {
  glGenTextures(1, &gl_texture_);
  glBindTexture(GL_TEXTURE_2D, gl_texture_);
  // Zero-copy mode: render_surface_ already maps D3D11 texture to GL texture
  // Use GL_RGBA format, ANGLE handles BGRA mapping internally
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0,
               GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

  glGenFramebuffers(1, &gl_fbo_);
  glBindFramebuffer(GL_FRAMEBUFFER, gl_fbo_);
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                         GL_TEXTURE_2D, gl_texture_, 0);

  bool ok = glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE;
  glBindFramebuffer(GL_FRAMEBUFFER, 0);
  glBindTexture(GL_TEXTURE_2D, 0);
  return ok;
}

void MpvRenderPlugin::DestroyGLResources() {
  if (gl_fbo_) { glDeleteFramebuffers(1, &gl_fbo_); gl_fbo_ = 0; }
  if (gl_texture_) { glDeleteTextures(1, &gl_texture_); gl_texture_ = 0; }
}

// ============================================================
// D3D11 Shared Texture
// ============================================================

bool MpvRenderPlugin::CreateSharedTexture(int width, int height) {
  D3D11_TEXTURE2D_DESC desc = {};
  desc.Width = width;
  desc.Height = height;
  desc.MipLevels = 1;
  desc.ArraySize = 1;
  desc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
  desc.SampleDesc.Count = 1;
  desc.Usage = D3D11_USAGE_DEFAULT;
  desc.BindFlags = D3D11_BIND_RENDER_TARGET;
  desc.MiscFlags = D3D11_RESOURCE_MISC_SHARED;

  if (FAILED(d3d_device_->CreateTexture2D(&desc, nullptr, &shared_texture_)))
    return false;

  ComPtr<IDXGIResource> dxgi;
  if (FAILED(shared_texture_.As(&dxgi))) return false;
  if (FAILED(dxgi->GetSharedHandle(&shared_handle_)) || !shared_handle_)
    return false;

  return true;
}

void MpvRenderPlugin::DestroySharedTexture() {
  shared_handle_ = nullptr;
  shared_texture_.Reset();
}

// ============================================================
// Flutter Texture Registration
// ============================================================

bool MpvRenderPlugin::RegisterFlutterTexture() {
  surface_desc_.struct_size = sizeof(FlutterDesktopGpuSurfaceDescriptor);
  surface_desc_.handle = shared_handle_;
  surface_desc_.width = texture_width_;
  surface_desc_.height = texture_height_;
  surface_desc_.visible_width = texture_width_;
  surface_desc_.visible_height = texture_height_;
  surface_desc_.format = kFlutterDesktopPixelFormatBGRA8888;

  // Use Flutter C++ wrapper API to register GPU surface texture
  auto callback = [this](size_t width, size_t height)
      -> const FlutterDesktopGpuSurfaceDescriptor* {
    return &surface_desc_;
  };

  texture_ = std::make_unique<flutter::TextureVariant>(
      flutter::GpuSurfaceTexture(
          kFlutterDesktopGpuSurfaceTypeDxgiSharedHandle,
          callback));

  texture_id_ = texture_registrar_->RegisterTexture(texture_.get());
  return texture_id_ >= 0;
}

void MpvRenderPlugin::UnregisterFlutterTexture() {
  if (texture_id_ >= 0 && texture_registrar_) {
    texture_registrar_->UnregisterTexture(texture_id_);
    texture_id_ = -1;
  }
}

// ============================================================
// Render Thread
// ============================================================

void MpvRenderPlugin::OnMpvUpdate(void *ctx) {
  auto *p = static_cast<MpvRenderPlugin *>(ctx);
  if (p->frame_ready_event_) SetEvent(p->frame_ready_event_);
}

void MpvRenderPlugin::RenderThreadFunc() {
  eglMakeCurrent(egl_display_, egl_surface_, egl_surface_, egl_context_);

  while (render_running_) {
    WaitForSingleObject(frame_ready_event_, 100);
    if (!render_running_) break;

    // Resize race condition protection (#3): complete resize in render thread, hold lock to rebuild resources
    if (pending_resize_.load(std::memory_order_acquire)) {
      std::lock_guard<std::mutex> lock(mutex_);
      pending_resize_.store(false, std::memory_order_release);
      int new_w = pending_width_;
      int new_h = pending_height_;
      DestroyGLResources();
      if (render_surface_ != EGL_NO_SURFACE) {
        eglDestroySurface(egl_display_, render_surface_);
        render_surface_ = EGL_NO_SURFACE;
      }
      DestroySharedTexture();
      texture_width_ = new_w;
      texture_height_ = new_h;
      CreateSharedTexture(new_w, new_h);
      // Rebuild render surface (zero-copy: ANGLE directly writes to shared_texture_)
      auto eglCreatePbufferFromClientBufferANGLE =
          reinterpret_cast<PFNEGLCREATEPBUFFERFROMCLIENTBUFFERANGLEPROC>(
              eglGetProcAddress("eglCreatePbufferFromClientBufferANGLE"));
      if (eglCreatePbufferFromClientBufferANGLE && shared_handle_) {
        const EGLint sa[] = {EGL_WIDTH, new_w, EGL_HEIGHT, new_h, EGL_NONE};
        render_surface_ = eglCreatePbufferFromClientBufferANGLE(
            egl_display_, EGL_D3D11_TEXTURE_ANGLE,
            static_cast<EGLClientBuffer>(shared_handle_), egl_config_, sa);
      }
      if (render_surface_ != EGL_NO_SURFACE) {
        egl_surface_ = render_surface_;
        eglMakeCurrent(egl_display_, egl_surface_, egl_surface_, egl_context_);
      }
      CreateGLResources(new_w, new_h);
      surface_desc_.width = new_w;
      surface_desc_.height = new_h;
      surface_desc_.visible_width = new_w;
      surface_desc_.visible_height = new_h;
      // Zero-copy: no pixel_buffer_ needed, ANGLE directly writes to shared_texture_
    }

    uint32_t flags = mpv_render_context_update(mpv_render_ctx_);
    if (!(flags & MPV_RENDER_UPDATE_FRAME)) continue;

    // mpv renders to GL FBO, ANGLE directly writes to D3D11 shared texture (zero-copy)
    mpv_opengl_fbo fbo = {static_cast<int>(gl_fbo_),
                          texture_width_, texture_height_, GL_RGBA};
    int flip_y = 1;
    mpv_render_param params[] = {
        {MPV_RENDER_PARAM_OPENGL_FBO, &fbo},
        {MPV_RENDER_PARAM_FLIP_Y, &flip_y},
        {static_cast<mpv_render_param_type>(0), nullptr},
    };
    if (mpv_render_context_render(mpv_render_ctx_, params) < 0) continue;

    // glFlush submits GL commands to ANGLE D3D11 backend
    glFlush();

    // Zero-copy: shared_texture_ already written by ANGLE
    // D3D11 fence ensures GPU write completes before notifying Flutter
    d3d_context_->End(fence_query_.Get());
    d3d_context_->Flush();
    while (d3d_context_->GetData(fence_query_.Get(), nullptr, 0, 0) == S_FALSE)
      Sleep(1);

    if (texture_registrar_ && texture_id_ >= 0)
      texture_registrar_->MarkTextureFrameAvailable(texture_id_);
  }
}

}  // namespace mpv_render_plugin

// ============================================================
// Plugin Registration Entry Point
// ============================================================

void MpvRenderPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  mpv_render_plugin::MpvRenderPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
