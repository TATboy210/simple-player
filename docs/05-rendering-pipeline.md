# 05 — 渲染管线

> fvp/MDK/D3D11 渲染管线完整流程、帧生命周期、性能瓶颈与优化方案。

## 管线总览

```
┌──────────────────────────────────────────────────────────────┐
│                    FFmpeg / 硬件解码器                        │
│         (MFT:d3d=11 / NVDEC / D3D11 / FFmpeg)              │
└──────────────────────┬───────────────────────────────────────┘
                       │ 解码帧 (NV12/YUV420P)
                       ▼
┌──────────────────────────────────────────────────────────────┐
│              MDK 渲染线程 (render 回调)                       │
│  renderVideo() → D3D11 渲染目标 (rt)                         │
│  CopyResource(rt → tex) + Flush()                            │
│  MarkTextureFrameAvailable(textureId)                        │
└──────────────────────┬───────────────────────────────────────┘
                       │ DXGI Shared Handle
                       ▼
┌──────────────────────────────────────────────────────────────┐
│           Flutter 合成器 (Raster 线程)                        │
│  描述符回调 → 填充 FlutterDesktopGpuSurfaceDescriptor         │
│  合成器读取共享纹理 → 合成到场景                              │
└──────────────────────┬───────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────┐
│              Texture Widget → 屏幕像素                        │
└──────────────────────────────────────────────────────────────┘
```

## fvp C++ 插件详解

fvp 的 Windows 渲染核心在 `fvp_plugin.cpp` (193 行)，由两个类组成：

### TexturePlayer 类 (行 28-96)

```cpp
// 关键成员变量
int64_t textureId;                                     // Flutter 纹理 ID
unique_ptr<flutter::TextureVariant> flt_tex;           // Flutter 纹理包装
unique_ptr<FlutterDesktopGpuSurfaceDescriptor> desc;   // 表面描述符
ComPtr<ID3D11Texture2D> rt;                            // 渲染目标 (MDK 写入)
ComPtr<ID3D11Texture2D> tex;                           // 共享纹理 (Flutter 读取)
ComPtr<ID3D11DeviceContext> ctx;                       // D3D11 设备上下文
mutex mtx;                                             // 保护两个回调的临界区
```

**构造流程 (行 31-80):**

| 步骤 | 行号 | 操作 |
|------|------|------|
| 1 | 35-37 | `rt->GetDevice(&dev)` → `dev->GetImmediateContext(&ctx)` |
| 2 | 39-42 | 读取 rt 描述，添加 `D3D11_RESOURCE_MISC_SHARED`，创建 tex |
| 3 | 44-47 | `tex.As(&IDXGIResource)` → `GetSharedHandle()` |
| 4 | 48-54 | 填充 `FlutterDesktopGpuSurfaceDescriptor` |
| 5 | 56-66 | 注册 `GpuSurfaceTexture(kFlutterDesktopGpuSurfaceTypeDxgiSharedHandle)` |
| 6 | 67 | `RegisterTexture()` |
| 7 | 70-71 | `D3D11RenderAPI::ra.rtv = rt` |
| 8 | 74-78 | `setRenderCallback`: `scoped_lock(mtx)` → `renderVideo()` → `MarkTextureFrameAvailable()` |

**双缓冲关键代码 (行 59-64):**

```cpp
// 描述符回调 — Flutter Raster 线程
flt_tex->Update([this](...) {
    scoped_lock lock(mtx);           // 与 render 回调互斥
    ctx->CopyResource(tex, rt);      // GPU-to-GPU 拷贝 (~8MB/帧@1080p)
    ctx->Flush();                    // 强制 GPU 管线排空
    return flt_surface_desc.get();
});
```

### FvpPlugin 类 (行 110-190)

`CreateRT` 处理 (行 139-176):
- 行 144: `D3D11CreateDevice` — 每次创建新设备
- 行 149-151: `SetMultithreadProtected(TRUE)` — 冗余多线程保护
- 行 152-167: 创建纹理 `DXGI_FORMAT_B8G8R8A8_UNORM`

**D3D11 纹理创建参数:**

| 参数 | 值 | 说明 |
|------|-----|------|
| Format | `DXGI_FORMAT_B8G8R8A8_UNORM` | BGRA8 (Flutter 要求) |
| BindFlags | `RENDER_TARGET \| SHADER_RESOURCE` | MDK 渲染 + shader 采样 |
| MiscFlags | `RESOURCE_MISC_SHARED` | DXGI 共享句柄 |
| Usage | `D3D11_USAGE_DEFAULT` | GPU 访问 |
| MipLevels | 1 | 单级 |

## 帧生命周期

一个视频帧从解码到显示经历以下阶段：

```
时间线 →

[MDK 解码线程]          [MDK 渲染回调]           [Flutter Raster]        [显示]
     │                      │                       │                    │
     │ 解码完成              │                       │                    │
     │ ──renderVideo()──→   │                       │                    │
     │                      │ rt 写入完成            │                    │
     │                      │ ──CopyResource──→     │                    │
     │                      │    rt → tex            │                    │
     │                      │ ──Flush()──→          │                    │
     │                      │ ──MarkTexture──→      │                    │
     │                      │                       │ 描述符回调          │
     │                      │                       │ 读取 tex           │
     │                      │                       │ ──合成──→          │
     │                      │                       │                    │ 像素
```

## 性能瓶颈分析

按影响程度排序的 9 个瓶颈：

| # | 瓶颈 | 影响 | 位置 | 应用层可缓解 |
|---|------|------|------|------------|
| 1 | `d3d11.sync.cpu=1` 全局 CPU-GPU 同步 | **高** | video_player_mdk.dart:274 | 部分 |
| 2 | `Flush()` 复制后管线停顿 | **中高** | fvp_plugin.cpp:64 | 否 |
| 3 | Mutex 竞争 (render vs raster) | **中高** | fvp_plugin.cpp:59 | 否 |
| 4 | 每帧 `CopyResource` (~8MB/帧) | **中** | fvp_plugin.cpp:62 | 否 |
| 5 | `shader_resource=0` 禁用 GPU 色彩转换 | **中** | video_player_mdk.dart:325 | 是 |
| 6 | BGRA 格式要求 | **低中** | Flutter 约束 | 否 |
| 7 | `D3D11CreateDevice` 每纹理一次 | **低** | fvp_plugin.cpp:144 | 否 |
| 8 | MethodChannel 往返开销 | **低** | 一次性 | 否 |
| 9 | 宽高比计算 | **可忽略** | CPU 浮点 | N/A |

### 瓶颈 1: d3d11.sync.cpu=1

fvp 默认 `d3d11.sync.cpu=1`，每帧强制 CPU-GPU 同步。确保 MDK 渲染完成后 Flutter 才能读取纹理，但阻塞了 GPU 管线的异步执行。

### 瓶颈 2: Flush() 管线停顿

CopyResource 后立即 `Flush()` 强制 GPU 管线排空。D3D11 是异步命令队列，Flush 等待所有命令完成。替代方案：用 `ID3D11Query` 事件查询，只等待复制完成：

```cpp
D3D11_QUERY_DESC qdesc = { D3D11_QUERY_EVENT, 0 };
ComPtr<ID3D11Query> copyDone;
dev->CreateQuery(&qdesc, &copyDone);

// 替代 Flush()
ctx->End(copyDone.Get());
while (ctx->GetData(copyDone.Get(), nullptr, 0) == S_FALSE) {
    YieldProcessor();  // spin-wait, 通常 <1ms
}
```

### 瓶颈 3: Mutex 竞争

render 回调 (MDK 线程) 和描述符回调 (Flutter raster 线程) 共享同一把 mutex。三缓冲方案可消除 90% 锁竞争：

```cpp
ComPtr<ID3D11Texture2D> tex[2];  // 双共享纹理
int write_idx = 0;
int read_idx = 1;

// Render 回调: 交换而非长时间持锁
ctx->CopyResource(tex[write_idx].Get(), rt.Get());
std::swap(write_idx, read_idx);
```

## 优化方案

### Tier 1: 应用层 (零 fork)

| 优化项 | 文件 | 改动 | 预期收益 |
|--------|------|------|---------|
| `MFT:d3d=1` → `MFT:d3d=11` | platform_decoders.dart | 1 行 | 消除 D3D9→D3D11 转换 |
| `shader_resource=1` | registerWith player | 1 行 | GPU 直接色彩采样 |
| `d3d11.sync.cpu=0` | registerWith global | 1 行 | 消除 CPU 等待 |
| `log=warning` | registerWith global | 1 行 | 减少 I/O |

### Tier 2: C++ 插件层 (需 fork)

| 优化项 | 改动量 | 预期收益 |
|--------|--------|---------|
| Fence 替代 Flush | ~15 行 | 减少 GPU 停顿 1-3ms |
| 三缓冲 | ~50 行 | 消除 90% 锁竞争 |
| 移除冗余多线程保护 | 删 3 行 | 减少 API 内部锁 |
| 共享 D3D11 设备 | ~10 行 | 多纹理场景复用 |

### Tier 3: MDK SDK 层 (需上游 PR)

- 可配置 per-player `d3d11.sync.cpu`
- 直接渲染到外部共享纹理 (省去 CopyResource)
- D3D11RenderAPI 增加 fence 回调

## 与其他播放器对比

| 维度 | mpv GPU-Next | ExoPlayer | Flutter+fvp |
|------|-------------|-----------|-------------|
| 解码→渲染 | 懒上传 (map_frame) | 零拷贝 (Surface 直出) | GPU 拷贝 (CopyResource) |
| 帧调度 | VO 线程 + VSync 跟踪 | 6 动作决策树 | 隐式 (MDK 回调 + VSync) |
| A/V 同步 | 音频延迟 + 阻尼修正 | 音频时钟 + earlyUs | MDK 内部处理 |
| VSync | swap_buffers 阻塞 | Choreographer 采样 | 隐式 (合成器驱动) |
| 色彩管理 | 完整 (libplacebo HDR/ICC) | Dolby Vision | 无 (透传) |
| 帧插值 | pl_queue 多帧混合 | 无 | 无 |
| 零拷贝 | hwdec mapper | Surface 直出 | 无 (CopyResource) |

## 关键文件

| 文件 | 说明 |
|------|------|
| `fvp_plugin.cpp` (fvp 包) | C++ 插件: TexturePlayer + FvpPlugin |
| `video_player_mdk.dart` (fvp 包) | Dart 层 MDK 配置和属性设置 |
| `lib/kernel/engine/fvp_engine.dart` | 项目引擎实现 |
| `lib/ui/player/video_surface.dart` | Texture widget 渲染表面 |
| `lib/kernel/utils/platform_decoders.dart` | 解码器优先级配置 |
| `lib/main.dart` | fvp registerWith 初始化 |
