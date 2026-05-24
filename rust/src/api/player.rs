use anyhow::Result;
use std::sync::{Arc, Mutex};

/// Minimal mpv player wrapper. Commands only — state sync is Phase 3.
pub struct MpvPlayer {
    mpv: Arc<Mutex<libmpv2::Mpv>>,
}

impl MpvPlayer {
    pub fn new() -> Result<Self> {
        let mpv = libmpv2::Mpv::new()?;
        // Embed-friendly defaults
        mpv.set_property("vo", "null")?; // no video output yet (Phase 4)
        mpv.set_property("pause", true)?;
        Ok(Self {
            mpv: Arc::new(Mutex::new(mpv)),
        })
    }

    pub fn load_file(&self, path: String) -> Result<()> {
        let mpv = self.mpv.lock().unwrap();
        mpv.command("loadfile", &[&path, "replace"])?;
        Ok(())
    }

    pub fn play(&self) -> Result<()> {
        let mpv = self.mpv.lock().unwrap();
        mpv.set_property("pause", false)?;
        Ok(())
    }

    pub fn pause(&self) -> Result<()> {
        let mpv = self.mpv.lock().unwrap();
        mpv.set_property("pause", true)?;
        Ok(())
    }

    pub fn toggle_pause(&self) -> Result<()> {
        let mpv = self.mpv.lock().unwrap();
        let paused: bool = mpv.get_property("pause")?;
        mpv.set_property("pause", !paused)?;
        Ok(())
    }

    pub fn seek(&self, position_ms: i64) -> Result<()> {
        let mpv = self.mpv.lock().unwrap();
        let secs = position_ms as f64 / 1000.0;
        mpv.command("seek", &[&secs.to_string(), "absolute"])?;
        Ok(())
    }

    pub fn set_volume(&self, vol: f64) -> Result<()> {
        let mpv = self.mpv.lock().unwrap();
        // mpv volume is 0-100, caller passes 0.0-1.0
        mpv.set_property("volume", vol * 100.0)?;
        Ok(())
    }

    pub fn set_mute(&self, muted: bool) -> Result<()> {
        let mpv = self.mpv.lock().unwrap();
        mpv.set_property("mute", muted)?;
        Ok(())
    }

    pub fn set_speed(&self, speed: f64) -> Result<()> {
        let mpv = self.mpv.lock().unwrap();
        mpv.set_property("speed", speed)?;
        Ok(())
    }

    pub fn stop(&self) -> Result<()> {
        let mpv = self.mpv.lock().unwrap();
        mpv.command("stop", &[])?;
        Ok(())
    }

    pub fn get_position(&self) -> Result<f64> {
        let mpv = self.mpv.lock().unwrap();
        let pos: f64 = mpv.get_property("time-pos").unwrap_or(0.0);
        Ok(pos)
    }

    pub fn get_duration(&self) -> Result<f64> {
        let mpv = self.mpv.lock().unwrap();
        let dur: f64 = mpv.get_property("duration").unwrap_or(0.0);
        Ok(dur)
    }

    pub fn get_is_paused(&self) -> Result<bool> {
        let mpv = self.mpv.lock().unwrap();
        let paused: bool = mpv.get_property("pause").unwrap_or(true);
        Ok(paused)
    }
}
