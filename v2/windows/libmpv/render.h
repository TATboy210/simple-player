/* Copyright (C) 2017-2023 the mpv developers
 *
 * Permission to use, copy, modify, and/or distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

#ifndef MPV_RENDER_H_
#define MPV_RENDER_H_

#include "client.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * 渲染上下文 — mpv render API 核心
 *
 * 使用方式:
 *   1. mpv_render_context_create() 创建
 *   2. mpv_render_context_set_update_callback() 注册帧回调
 *   3. 在渲染线程中调用 mpv_render_context_render()
 *   4. mpv_render_context_free() 销毁
 */

// 前向声明：不透明渲染上下文
typedef struct mpv_render_context mpv_render_context;

// ============================================================
// 渲染参数类型
// ============================================================

typedef enum mpv_render_param_type {
    MPV_RENDER_PARAM_API_TYPE = 1,
    MPV_RENDER_PARAM_OPENGL_INIT_PARAMS = 2,
    MPV_RENDER_PARAM_ADVANCED_CONTROL = 3,
    MPV_RENDER_PARAM_OPENGL_FBO = 4,
    MPV_RENDER_PARAM_FLIP_Y = 5,
    MPV_RENDER_PARAM_DEPTH = 6,
    MPV_RENDER_PARAM_ICC_PROFILE = 7,
    MPV_RENDER_PARAM_TARGET_COLORSPACE = 8,
    MPV_RENDER_PARAM_TARGET_PEAK = 9,
    MPV_RENDER_PARAM_TARGET_TRC = 10,
    MPV_RENDER_PARAM_BLEND_MODE = 11,
} mpv_render_param_type;

// ============================================================
// 渲染更新标志
// ============================================================

typedef enum mpv_render_update_flag {
    MPV_RENDER_UPDATE_FRAME = 1 << 0,
} mpv_render_update_flag;

// ============================================================
// 渲染参数结构体
// ============================================================

typedef struct mpv_render_param {
    mpv_render_param_type type;
    void *data;
} mpv_render_param;

// ============================================================
// API 类型常量
// ============================================================

#define MPV_RENDER_API_TYPE_OPENGL "opengl"

// ============================================================
// 核心函数
// ============================================================

/// 创建渲染上下文. params 以 {type=0} 终止
MPV_EXPORT int mpv_render_context_create(
    mpv_render_context **res, mpv_handle *mpv, mpv_render_param *params);

/// 销毁渲染上下文
MPV_EXPORT void mpv_render_context_free(mpv_render_context *ctx);

/// 检查是否有新帧. 返回 mpv_render_update_flag 位掩码
MPV_EXPORT int mpv_render_context_update(mpv_render_context *ctx);

/// 渲染一帧到当前绑定的 FBO. 必须在 GL 上下文线程调用
MPV_EXPORT int mpv_render_context_render(
    mpv_render_context *ctx, mpv_render_param *params);

/// 设置帧更新回调. 回调在 mpv 内部线程执行，不可调用 mpv API
MPV_EXPORT void mpv_render_context_set_update_callback(
    mpv_render_context *ctx,
    void (*callback)(void *callback_ctx), void *callback_ctx);

/// 报告 swap 完成
MPV_EXPORT void mpv_render_context_report_swap(mpv_render_context *ctx);

#ifdef __cplusplus
}
#endif

#endif // MPV_RENDER_H_
