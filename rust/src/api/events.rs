use crate::frb_generated::StreamSink;
use anyhow::Result;

/// Events pushed from Rust mpv event loop to Dart Stream.
pub enum PlayerEvent {
    Position { ms: f64 },
    Duration { ms: f64 },
    Paused { paused: bool },
    State { state: String },
    Error { message: String },
}

/// Start streaming mpv events to Dart.
///
/// Observes time-pos, duration, pause. Returns Stream<PlayerEvent>.
#[flutter_rust_bridge::frb(stream_dart_await)]
pub fn start_event_loop(sink: StreamSink<PlayerEvent>) -> Result<()> {
    crate::event_loop::run(sink)
}
