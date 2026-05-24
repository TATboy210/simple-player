use anyhow::Result;
use libmpv2_sys::*;
use std::os::raw::{c_int, c_void};
use std::sync::{Mutex, OnceLock};

// C++ plugin FFI — implemented in windows/video_texture_plugin/
extern "C" {
    fn video_texture_create(width: c_int, height: c_int, buffer: *const u8) -> i64;
    fn video_texture_mark_frame_available();
    fn video_texture_destroy();
}

struct RenderState {
    ctx: *mut mpv_render_context,
    buffer: Vec<u8>,
    width: c_int,
    height: c_int,
    stride: c_int,
    texture_id: i64,
}

unsafe impl Send for RenderState {}
unsafe impl Sync for RenderState {}

static STATE: OnceLock<Mutex<RenderState>> = OnceLock::new();

/// Called by mpv when a new frame is ready for rendering.
unsafe extern "C" fn update_callback(_cb_ctx: *mut c_void) {
    // Signal C++ plugin that a new frame is available.
    // mpv_render_context_render will be called from render_frame().
    unsafe { video_texture_mark_frame_available() };
}

/// Create a SW render context and register a Flutter texture.
pub fn create_render_context(mpv_handle_ptr: *mut mpv_handle, width: i32, height: i32) -> Result<i64> {
    let w = width as c_int;
    let h = height as c_int;
    let stride = w * 4; // BGRA = 4 bytes per pixel
    let buf_size = (stride as usize) * (h as usize);
    let mut buffer = vec![0u8; buf_size];

    let api_type: &[u8] = b"sw\0";
    let format: &[u8] = b"bgra\0";
    let size = [w, h];
    let stride_val = stride as usize;

    let mut params = vec![
        mpv_render_param {
            type_: mpv_render_param_type_MPV_RENDER_PARAM_API_TYPE,
            data: api_type.as_ptr() as *mut c_void,
        },
        mpv_render_param {
            type_: mpv_render_param_type_MPV_RENDER_PARAM_SW_SIZE,
            data: size.as_ptr() as *mut c_void,
        },
        mpv_render_param {
            type_: mpv_render_param_type_MPV_RENDER_PARAM_SW_FORMAT,
            data: format.as_ptr() as *mut c_void,
        },
        mpv_render_param {
            type_: mpv_render_param_type_MPV_RENDER_PARAM_SW_STRIDE,
            data: &stride_val as *const usize as *mut c_void,
        },
        mpv_render_param {
            type_: mpv_render_param_type_MPV_RENDER_PARAM_SW_POINTER,
            data: buffer.as_mut_ptr() as *mut c_void,
        },
        mpv_render_param {
            type_: 0, // terminator
            data: std::ptr::null_mut(),
        },
    ];

    let mut render_ctx: *mut mpv_render_context = std::ptr::null_mut();
    let ret = unsafe {
        mpv_render_context_create(
            &mut render_ctx as *mut *mut mpv_render_context,
            mpv_handle_ptr,
            params.as_mut_ptr(),
        )
    };
    if ret != 0 {
        return Err(anyhow::anyhow!("mpv_render_context_create failed: {}", ret));
    }

    // Set update callback — mpv calls this when a new frame is ready.
    unsafe {
        mpv_render_context_set_update_callback(
            render_ctx,
            Some(update_callback),
            std::ptr::null_mut(),
        );
    }

    // Register texture with Flutter via C++ plugin.
    let texture_id = unsafe { video_texture_create(w, h, buffer.as_ptr()) };

    let state = RenderState {
        ctx: render_ctx,
        buffer,
        width: w,
        height: h,
        stride,
        texture_id,
    };
    let _ = STATE.set(Mutex::new(state));

    Ok(texture_id)
}

/// Render the current video frame to the shared buffer.
/// Called by Flutter's CopyPixelBuffer callback (via C++ plugin).
pub fn render_frame() -> Result<()> {
    let state = STATE.get().ok_or_else(|| anyhow::anyhow!("render not initialized"))?;
    let mut guard = state.lock().unwrap();

    // Check if there's a new frame to render.
    let update_flags = unsafe { mpv_render_context_update(guard.ctx) };
    if update_flags & (mpv_render_update_flag_MPV_RENDER_UPDATE_FRAME as u64) == 0 {
        return Ok(()); // No new frame
    }

    let size = [guard.width, guard.height];
    let stride_val = guard.stride as usize;

    let mut params = vec![
        mpv_render_param {
            type_: mpv_render_param_type_MPV_RENDER_PARAM_SW_SIZE,
            data: size.as_ptr() as *mut c_void,
        },
        mpv_render_param {
            type_: mpv_render_param_type_MPV_RENDER_PARAM_SW_POINTER,
            data: guard.buffer.as_mut_ptr() as *mut c_void,
        },
        mpv_render_param {
            type_: mpv_render_param_type_MPV_RENDER_PARAM_SW_STRIDE,
            data: &stride_val as *const usize as *mut c_void,
        },
        mpv_render_param {
            type_: 0, // terminator
            data: std::ptr::null_mut(),
        },
    ];

    let ret = unsafe { mpv_render_context_render(guard.ctx, params.as_mut_ptr()) };
    if ret != 0 {
        return Err(anyhow::anyhow!("mpv_render_context_render failed: {}", ret));
    }

    Ok(())
}

/// Get a pointer to the frame buffer (for C++ CopyPixelBuffer callback).
pub fn get_buffer_ptr() -> *const u8 {
    match STATE.get() {
        Some(state) => {
            let guard = state.lock().unwrap();
            guard.buffer.as_ptr()
        }
        None => std::ptr::null(),
    }
}

/// Get frame dimensions.
pub fn get_dimensions() -> (i32, i32) {
    match STATE.get() {
        Some(state) => {
            let guard = state.lock().unwrap();
            (guard.width, guard.height)
        }
        None => (0, 0),
    }
}

/// Destroy the render context and unregister the texture.
pub fn destroy_render_context() {
    if let Some(state) = STATE.get() {
        let mut guard = state.lock().unwrap();

        unsafe {
            // Unregister Flutter texture.
            video_texture_destroy();

            // Free mpv render context.
            if !guard.ctx.is_null() {
                mpv_render_context_free(guard.ctx);
                guard.ctx = std::ptr::null_mut();
            }
        }
    }
}
