fn main() {
    // Tell the linker where to find mpv.lib on Windows
    #[cfg(target_os = "windows")]
    println!("cargo:rustc-link-search=native=C:\\libmpv-dev\\mpv");
}
