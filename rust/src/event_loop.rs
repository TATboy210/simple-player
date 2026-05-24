use crate::api::events::PlayerEvent;
use crate::frb_generated::StreamSink;
use anyhow::Result;
use libmpv2::events::{Event, PropertyData};
use libmpv2::mpv_end_file_reason;
use libmpv2::Format;
use std::sync::{Arc, Mutex, OnceLock};
use std::time::Duration;

// Single shared mpv handle — initialized once in MpvPlayer::new().
static MPV: OnceLock<Arc<Mutex<libmpv2::Mpv>>> = OnceLock::new();

pub fn init_mpv(mpv: Arc<Mutex<libmpv2::Mpv>>) {
    let _ = MPV.set(mpv);
}

pub fn with_mpv<T>(f: impl FnOnce(&libmpv2::Mpv) -> Result<T>) -> Result<T> {
    let mpv = MPV.get().ok_or_else(|| anyhow::anyhow!("mpv not initialized"))?;
    let guard = mpv.lock().unwrap();
    f(&guard)
}

enum Action {
    Event(PlayerEvent),
    Break,
    Continue,
}

pub fn run(sink: StreamSink<PlayerEvent>) -> Result<()> {
    let mpv = MPV.get().ok_or_else(|| anyhow::anyhow!("mpv not initialized"))?;

    {
        let guard = mpv.lock().unwrap();
        guard.observe_property("time-pos", Format::Double, 0)?;
        guard.observe_property("duration", Format::Double, 0)?;
        guard.observe_property("pause", Format::Flag, 0)?;
    }

    loop {
        let action = {
            let guard = mpv.lock().unwrap();
            match guard.wait_event(0.1) {
                Some(Ok(event)) => map_event(event),
                Some(Err(e)) => Action::Event(PlayerEvent::Error {
                    message: format!("mpv event error: {e}"),
                }),
                None => Action::Break,
            }
        };

        match action {
            Action::Event(ev) => {
                let is_end = matches!(ev, PlayerEvent::State { ref state } if state == "ended" || state == "stopped");
                let _ = sink.add(ev);
                if is_end { break; }
            }
            Action::Break => break,
            Action::Continue => {}
        }

        std::thread::sleep(Duration::from_millis(1));
    }
    Ok(())
}

fn map_event(event: Event<'_>) -> Action {
    match event {
        Event::StartFile => Action::Event(PlayerEvent::State { state: "loading".into() }),
        Event::FileLoaded => Action::Event(PlayerEvent::State { state: "playing".into() }),
        Event::EndFile(reason) => {
            let ev = match reason {
                mpv_end_file_reason::Eof => PlayerEvent::State { state: "ended".into() },
                mpv_end_file_reason::Error => PlayerEvent::Error { message: "Playback error".into() },
                mpv_end_file_reason::Stop => PlayerEvent::State { state: "stopped".into() },
                _ => return Action::Continue,
            };
            Action::Event(ev)
        }
        Event::PropertyChange { name, change, .. } => {
            let ev = match (name, change) {
                ("time-pos", PropertyData::Double(v)) => Some(PlayerEvent::Position { ms: v * 1000.0 }),
                ("duration", PropertyData::Double(v)) => Some(PlayerEvent::Duration { ms: v * 1000.0 }),
                ("pause", PropertyData::Flag(v)) => Some(PlayerEvent::Paused { paused: v }),
                _ => None,
            };
            match ev { Some(e) => Action::Event(e), None => Action::Continue }
        }
        Event::Shutdown => Action::Break,
        _ => Action::Continue,
    }
}
