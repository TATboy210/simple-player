use anyhow::Result;
use std::sync::{Arc, Mutex};

/// Minimal mpv player wrapper. Uses global mpv handle shared with event loop.
pub struct MpvPlayer {}

impl MpvPlayer {
    pub fn new() -> Result<Self> {
        let mpv = libmpv2::Mpv::new()?;
        mpv.set_property("vo", "null")?;
        mpv.set_property("pause", true)?;
        crate::event_loop::init_mpv(Arc::new(Mutex::new(mpv)));
        Ok(Self {})
    }

    pub fn load_file(&self, path: String) -> Result<()> {
        crate::event_loop::with_mpv(|mpv| { mpv.command("loadfile", &[&path, "replace"])?; Ok(()) })
    }
    pub fn play(&self) -> Result<()> {
        crate::event_loop::with_mpv(|mpv| { mpv.set_property("pause", false)?; Ok(()) })
    }
    pub fn pause(&self) -> Result<()> {
        crate::event_loop::with_mpv(|mpv| { mpv.set_property("pause", true)?; Ok(()) })
    }
    pub fn toggle_pause(&self) -> Result<()> {
        crate::event_loop::with_mpv(|mpv| { let p: bool = mpv.get_property("pause")?; mpv.set_property("pause", !p)?; Ok(()) })
    }
    pub fn seek(&self, position_ms: i64) -> Result<()> {
        crate::event_loop::with_mpv(|mpv| {
            let secs = (position_ms as f64 / 1000.0).to_string();
            mpv.command("seek", &[secs.as_str(), "absolute"])?;
            Ok(())
        })
    }
    pub fn set_volume(&self, vol: f64) -> Result<()> {
        crate::event_loop::with_mpv(|mpv| { mpv.set_property("volume", vol * 100.0)?; Ok(()) })
    }
    pub fn set_mute(&self, muted: bool) -> Result<()> {
        crate::event_loop::with_mpv(|mpv| { mpv.set_property("mute", muted)?; Ok(()) })
    }
    pub fn set_speed(&self, speed: f64) -> Result<()> {
        crate::event_loop::with_mpv(|mpv| { mpv.set_property("speed", speed)?; Ok(()) })
    }
    pub fn stop(&self) -> Result<()> {
        crate::event_loop::with_mpv(|mpv| { mpv.command("stop", &[])?; Ok(()) })
    }
    pub fn get_position(&self) -> Result<f64> {
        crate::event_loop::with_mpv(|mpv| Ok(mpv.get_property("time-pos").unwrap_or(0.0)))
    }
    pub fn get_duration(&self) -> Result<f64> {
        crate::event_loop::with_mpv(|mpv| Ok(mpv.get_property("duration").unwrap_or(0.0)))
    }
    pub fn get_is_paused(&self) -> Result<bool> {
        crate::event_loop::with_mpv(|mpv| Ok(mpv.get_property("pause").unwrap_or(true)))
    }
}
