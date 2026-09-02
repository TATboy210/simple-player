---
status: resolved
deferred_reason: "v4.0 milestone close — debug session deferred to future milestone. Root cause not yet determined."
trigger: "只读诊断 Flutter 项目 D:\\simple_player_flutter：用户反馈“播放器播放不了视频，加载视频播放不了”。请追踪 main/app → FvpEngine/MediaEngine → PlaybackController → video surface 的初始化与 open/play 调用链，寻找明显逻辑缺陷、状态守卫、错误吞没、fvp API误用，并给出文件行号与最可能根因。不要修改文件。"
created: 2026-07-17T00:00:00+08:00
updated: 2026-09-02
audit_acknowledged:
  milestone: v1.0
  at: 2026-09-01
  status: deferred
---

## Current Focus

<!-- OVERWRITE on each update - reflects NOW -->

hypothesis: The native decoder configuration is applied through an unverified generic property string instead of fvp 0.37.2's typed decoder API, so a malformed/unsupported decoder list can cause prepare() to fail for every video while the app only exposes a generic error.
test: Static trace of FvpEngine construction through D3D11Configurator.applyDefaults(), then compare its calls with fvp 0.37.2 Player API.
expecting: FvpEngine applies `video.decoders` before every open, whereas fvp exposes `videoDecoders`/`setDecoders(MediaType.video, List<String>)` for this exact setting.
next_action: Return read-only diagnosis with confidence boundaries and required runtime confirmation.

## Symptoms

<!-- Written during gathering, then IMMUTABLE -->

expected: Selecting or opening a valid local video initializes the playback engine, renders the video surface, and begins playback.
actual: The player cannot play a video; loading a video does not start playback.
errors: No error message or stack trace supplied.
reproduction: Launch the desktop player and attempt to load a video file.
started: Not supplied.

## Eliminated

<!-- APPEND only - prevents re-investigating -->

## Evidence

<!-- APPEND only - facts discovered -->

- timestamp: 2026-07-17T00:00:00+08:00
  checked: Reported symptoms and requested call-chain scope.
  found: No runtime error, media format, platform, or regression timing was supplied; diagnosis must be based on static call-chain evidence.
  implication: Initialization ordering, state guards, fvp API use, and error propagation are the first falsifiable candidates.

## Resolution

<!-- OVERWRITE as understanding evolves -->

root_cause: 会话过时（obsolete）——假设针对 fvp 0.37.2 的 D3D11Configurator 通用属性串解码器配置缺陷，该机制随 fvp 后端整体移除而不复存在；decoder 配置现由 media_kit (libmpv) 自身管理，项目代码不再触碰该层。
fix: 无需修复（resolution_type: obsolete）。media_kit 时代如出现同类症状，按新会话调查 MediaKitEngine 初始化与 open/play 链路。
verification: 2026-09-02 会话清理核验：pubspec.yaml:16 注释 "fvp/MDK 已移除"；lib/ 无 FvpEngine/D3D11Configurator 引用。
files_changed: []
