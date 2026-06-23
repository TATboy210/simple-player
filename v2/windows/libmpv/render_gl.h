/* Copyright (C) 2017-2023 the mpv developers — ISC License */

#ifndef MPV_RENDER_GL_H_
#define MPV_RENDER_GL_H_

#include "render.h"

#ifdef __cplusplus
extern "C" {
#endif

/// OpenGL 初始化参数
typedef struct mpv_opengl_init_params {
    void *(*get_proc_address)(void *ctx, const char *name);
    void *get_proc_address_ctx;
} mpv_opengl_init_params;

/// OpenGL FBO 参数
typedef struct mpv_opengl_fbo {
    int fbo;             // FBO ID (0 = 默认帧缓冲)
    int w;               // 宽 (逻辑像素)
    int h;               // 高 (逻辑像素)
    int internal_format; // 内部格式 (GL_RGBA8, 0 = 默认)
} mpv_opengl_fbo;

#ifdef __cplusplus
}
#endif

#endif // MPV_RENDER_GL_H_
