# Long-Term Plans Technical Research Report

> **Generated:** 2026-07-20
> **Project:** simple_player_flutter v1.0.0-rc.1
> **Purpose:** Technical feasibility analysis for four long-term strategic initiatives

---

## Executive Summary

| Initiative | Feasibility | Complexity | Priority | Est. Effort |
|------------|-------------|------------|----------|-------------|
| Impeller Migration | HIGH | Medium | P1 - Short-term | 2-3 weeks |
| Cross-Platform Expansion | HIGH | Medium-High | P1 - Short-term | 4-6 weeks |
| Plugin System Architecture | MEDIUM | High | P2 - Mid-term | 6-8 weeks |
| Cloud Sync | MEDIUM | Very High | P3 - Long-term | 8-12 weeks |

---

## 1. Impeller Migration

### 1.1 Current Status

**Platform Support Matrix (Flutter 3.44+):**

| Platform | Impeller Status | GPU Backend | Enable Method |
|----------|-----------------|-------------|---------------|
| **Windows** | Default (3.44+) | Vulkan 1.4 → OpenGL fallback | Automatic |
| **macOS** | Preview | Metal | `FLTEnableImpeller` in Info.plist |
| **Linux** | Experimental | Vulkan/OpenGL | `--enable-impeller` flag |

**Key Finding:** Flutter 3.44.0-beta has `--enable-impeller` flag removed for Windows (now default). VulkanSDK 1.4.341 is installed at `D:\VulkanSDK`.

### 1.2 Risk Assessment

| Risk Level | Component | Files | Issue |
|------------|-----------|-------|-------|
| **HIGH** | BackdropFilter | 6 files, 6 locations | Impeller framebuffer readback overhead |
| **MEDIUM-HIGH** | fvp Texture | `video_surface.dart` | D3D11→Vulkan interop verification needed |
| **LOW** | ClipRRect, Opacity | Multiple | Native Impeller support |

**Affected Files:**
- `lib/ui/shared/glass_container.dart` — BackdropFilter core (L80)
- `lib/ui/shared/aurora_background.dart` — saveLayer+BlendMode composite (L120-200)
- `lib/ui/player/video_surface.dart` — Texture widget
- `lib/ui/playlist/playlist_panel.dart` — BackdropFilter
- `lib/ui/player/control_bar.dart` — BackdropFilter
- `lib/ui/player/controls_overlay.dart` — BackdropFilter

### 1.3 Implementation Phases

| Phase | Description | Effort | Dependencies |
|-------|-------------|--------|--------------|
| 1 | **Verification** — Build + runtime video playback test | 2-3 days | None |
| 2 | **BackdropFilter Refactor** — GlassContainer optimization + sigma reduction | 3-4 days | Phase 1 |
| 3 | **Custom FragmentShaders** — glass_blur.frag, aurora_blob.frag | 5-7 days | Phase 2 |
| 4 | **Impeller-Specific Optimizations** — Shader prewarm, Opacity→FadeTransition | 3-4 days | Phase 3 |
| 5 | **Cross-Platform Config** — macOS FLTEnableImpeller, Linux flag | 1-2 days | Phase 4 |
| 6 | **Testing & Monitoring** — Performance benchmarks, regression tests | 2-3 days | Phase 5 |

**Total Estimated Effort:** 2-3 weeks

### 1.4 Technical Approach

**FragmentShader Migration Pattern:**
```dart
// BEFORE: BackdropFilter with sigma blur
BackdropFilter(
  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
  child: Container(...),
)

// AFTER: Custom FragmentShader (Impeller-optimized)
FragmentProgram.asset('shaders/glass_blur.frag')
  ..setFloat(0, sigma)
  ..setFloat(1, opacity)
```

**Safety Nets:**
- Preserve `--impeller=skia` fallback (if available)
- Use `FlutterFragCoord()` not `gl_FragCoord` in shaders
- macOS sigma values unchanged (Metal performance adequate)

### 1.5 Dependencies

| Dependency | Status | Impact |
|------------|--------|--------|
| Flutter SDK 3.44+ | Required | Breaking changes possible |
| VulkanSDK 1.4.341 | ✅ Installed | Windows GPU backend |
| fvp plugin | v0.37.2 | Texture interop verification |
| Metal support | macOS only | No additional setup |

### 1.6 Success Metrics

- [ ] All BackdropFilter locations render correctly under Impeller
- [ ] fvp Texture widget displays video without artifacts
- [ ] No shader compilation jank on first frame
- [ ] Performance parity or improvement vs Skia

---

## 2. Cross-Platform Expansion (macOS, Linux)

### 2.1 Current Status

**Existing Work (fix/window-startup branch):**

| Phase | Status | Description |
|-------|--------|-------------|
| 1-3 | ✅ Complete | Factory refactor + macOS/Linux Dart端 |
| 4-6 | ✅ Complete | macOS Swift + Linux GTK + Win32 multi-monitor |
| 7 | ✅ Complete | macOS/Linux Runner configuration |
| 8 | ✅ Complete | Unit tests (14 tests total) |

**Key Files:**
- `lib/kernel/bridge/window_service.dart` — Factory method (L244-248)
- `lib/kernel/bridge/platform_fullscreen.dart` — Strategy interface
- `lib/kernel/bridge/win32/win32_platform_fullscreen.dart` — Win32 FFI
- `lib/kernel/bridge/macos/macos_platform_fullscreen.dart` — macOS MethodChannel
- `lib/kernel/bridge/linux/linux_platform_fullscreen.dart` — Linux GTK3 FFI + MethodChannel

### 2.2 Gap Analysis

| Area | Windows | macOS | Linux | Gap |
|------|---------|-------|-------|-----|
| **Window Management** | ✅ Complete | ✅ Complete | ✅ Complete | None |
| **Fullscreen** | ✅ Win32 FFI | ✅ NSWindow | ✅ GTK3 | None |
| **Multi-Monitor** | ✅ MonitorFromWindow | ⚠️ Partial | ⚠️ Partial | macOS/Linux |
| **File Thumbnails** | ✅ COM | ❌ Stub | ❌ Stub | macOS/Linux |
| **Native Menus** | ❌ None | ❌ None | ❌ None | All platforms |
| **System Tray** | ❌ None | ❌ None | ❌ None | All platforms |
| **CI/CD** | ✅ GitHub Actions | ❌ None | ❌ None | macOS/Linux |

### 2.3 Implementation Roadmap

**Phase 1: macOS Parity (2-3 weeks)**
- [ ] Multi-monitor support (NSScreen APIs)
- [ ] Thumbnail generation (QLThumbnailGenerator)
- [ ] Native menu bar (NSMenu)
- [ ] Retina display support

**Phase 2: Linux Parity (2-3 weeks)**
- [ ] Multi-monitor support (X11/Wayland)
- [ ] Thumbnail generation (ThumbnailFactory)
- [ ] AppImage/Flatpak packaging
- [ ] Desktop integration (XDG)

**Phase 3: CI/CD Pipeline (1 week)**
- [ ] macOS GitHub Actions runner
- [ ] Linux GitHub Actions runner
- [ ] Cross-platform test matrix
- [ ] Release automation

**Total Estimated Effort:** 4-6 weeks

### 2.4 Technical Challenges

| Challenge | Complexity | Mitigation |
|-----------|------------|------------|
| **macOS Retina** | Medium | Use `window.devicePixelRatio` |
| **Linux Wayland** | High | X11 fallback, GTK4 migration path |
| **Thumbnail APIs** | Medium | Platform-specific implementations |
| **Native Menus** | Low | `menubar` package or custom |

### 2.5 Dependencies

| Dependency | macOS | Linux | Impact |
|------------|-------|-------|--------|
| Flutter SDK | ✅ Stable | ✅ Stable | Core requirement |
| Swift/Xcode | ✅ Required | N/A | macOS development |
| GTK3/GTK4 | N/A | ✅ Required | Linux UI framework |
| CMake | N/A | ✅ Required | Linux build system |

### 2.6 Distribution Strategy

| Platform | Format | Store | Notes |
|----------|--------|-------|-------|
| **Windows** | MSIX | Microsoft Store | ✅ Already configured |
| **macOS** | DMG/App Store | Mac App Store | Requires Apple Developer |
| **Linux** | AppImage/Flatpak/Deb | Flathub | Community distribution |

---

## 3. Plugin System Architecture

### 3.1 Current Architecture

**Existing Layers:**
```
lib/
├── kernel/         # Core logic (no UI)
│   ├── engine/     # fvp/MDK wrapper
│   ├── bridge/     # Platform channels
│   ├── services/   # Business logic
│   └── models/     # Data classes
└── ui/             # Flutter widgets
```

**Current Extension Points:**
- `MediaEngine` abstract interface
- `PlatformFullscreen` strategy pattern
- `PlaybackController` orchestrator

### 3.2 Plugin System Design Options

**Option A: Federated Plugin Pattern (Recommended)**
```
simple_player/                    # App-facing package
simple_player_platform_interface/ # Platform interface
simple_player_windows/            # Windows implementation
simple_player_macos/              # macOS implementation
simple_player_linux/              # Linux implementation
```

**Pros:**
- Follows Flutter ecosystem conventions
- Clean separation of concerns
- Enables third-party extensions

**Cons:**
- Significant refactoring required
- Multiple packages to maintain

**Option B: Internal Plugin Registry**
```dart
abstract class PlayerPlugin {
  String get name;
  String get version;
  void initialize(PluginContext context);
  void dispose();
}

class PluginRegistry {
  final Map<String, PlayerPlugin> _plugins = {};
  
  void register(PlayerPlugin plugin) => _plugins[plugin.name] = plugin;
  T? get<T extends PlayerPlugin>() => _plugins.values.whereType<T>().firstOrNull;
}
```

**Pros:**
- Simpler implementation
- Single package structure
- Easier testing

**Cons:**
- Not Flutter ecosystem standard
- Limited third-party extensibility

### 3.3 Potential Plugin Categories

| Category | Examples | Complexity |
|----------|----------|------------|
| **Codecs** | HEVC, AV1, VP9 | High |
| **Subtitles** | SRT, ASS, VTT | Medium |
| **Sources** | HTTP, RTSP, HLS | Medium |
| **UI Themes** | Skins, layouts | Low |
| **Analytics** | Playback stats | Low |

### 3.4 Implementation Phases

**Phase 1: Interface Extraction (2 weeks)**
- [ ] Define `PlatformInterface` for each domain
- [ ] Extract `MediaEngine`, `WindowService`, `ThumbnailService`
- [ ] Create abstract contracts

**Phase 2: Registry Implementation (2 weeks)**
- [ ] Build `PluginRegistry` with lifecycle management
- [ ] Add dependency injection
- [ ] Implement plugin discovery

**Phase 3: Example Plugins (2 weeks)**
- [ ] Convert existing features to plugins
- [ ] Create sample external plugin
- [ ] Documentation and templates

**Phase 4: Ecosystem (2 weeks)**
- [ ] Plugin API documentation
- [ ] Developer tooling
- [ ] Plugin validation/publishing

**Total Estimated Effort:** 6-8 weeks

### 3.5 Technical Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Breaking Changes** | High | Versioned interfaces |
| **Performance** | Medium | Lazy loading, caching |
| **Complexity** | High | Start with internal plugins |
| **Testing** | Medium | Mock plugin implementations |

---

## 4. Cloud Sync Solution

### 4.1 Requirements Analysis

**Syncable Data:**
| Data Type | Size | Frequency | Priority |
|-----------|------|-----------|----------|
| Playlist items | ~1KB/item | On change | HIGH |
| Playback position | 8 bytes | Every 30s | HIGH |
| Settings | ~5KB | On change | MEDIUM |
| Thumbnails | ~100KB/item | On demand | LOW |
| Watch history | ~200 bytes/item | On playback | MEDIUM |

### 4.2 Solution Options

**Option A: Firebase/Firestore**
```dart
// Example: Sync playlist
class FirebasePlaylistSync implements PlaylistSync {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  @override
  Future<void> syncPlaylist(List<PlaylistItem> items) async {
    final batch = _firestore.batch();
    for (final item in items) {
      batch.set(_firestore.collection('playlists').doc(item.id), item.toJson());
    }
    await batch.commit();
  }
}
```

**Pros:**
- Real-time sync out of the box
- Offline support built-in
- Cross-platform SDK

**Cons:**
- Google dependency
- Cost at scale
- Requires internet

**Option B: Supabase (PostgreSQL)**
```dart
class SupabasePlaylistSync implements PlaylistSync {
  final SupabaseClient _client = Supabase.instance.client;
  
  @override
  Future<void> syncPlaylist(List<PlaylistItem> items) async {
    await _client.from('playlists').upsert(
      items.map((i) => i.toJson()).toList(),
    );
  }
}
```

**Pros:**
- Open source
- PostgreSQL flexibility
- Self-hostable

**Cons:**
- Less mature ecosystem
- More setup required

**Option C: Custom WebSocket Server**
```dart
class WebSocketSync implements CloudSync {
  late WebSocket _socket;
  final StreamController<SyncEvent> _events = StreamController.broadcast();
  
  @override
  void connect(String serverUrl) {
    _socket = WebSocket.connect(serverUrl);
    _socket.listen(_handleMessage);
  }
}
```

**Pros:**
- Full control
- No vendor lock-in
- Custom protocol

**Cons:**
- Significant development effort
- Infrastructure management
- Security implementation

### 4.3 Recommended Architecture

**Hybrid Approach:**
```
┌─────────────────────────────────────────────────────────┐
│                      Flutter App                        │
├─────────────────────────────────────────────────────────┤
│  SyncManager (Local-first with cloud backup)           │
│  ├── LocalStore (SQLite/SharedPreferences)             │
│  ├── CloudAdapter (Firebase/Supabase/Custom)           │
│  └── ConflictResolver (Last-write-wins / CRDT)         │
└─────────────────────────────────────────────────────────┘
```

**Data Flow:**
1. All changes write to local store immediately
2. Background sync pushes to cloud
3. Conflict resolution on pull
4. Real-time updates via WebSocket/SSE

### 4.4 Implementation Phases

**Phase 1: Local-First Foundation (2 weeks)**
- [ ] SQLite database for structured data
- [ ] Change tracking and versioning
- [ ] Offline queue

**Phase 2: Cloud Adapter (2 weeks)**
- [ ] Firebase/Supabase integration
- [ ] Authentication flow
- [ ] Basic sync protocol

**Phase 3: Conflict Resolution (2 weeks)**
- [ ] Last-write-wins strategy
- [ ] Merge algorithms
- [ ] Sync status UI

**Phase 4: Real-Time Sync (2 weeks)**
- [ ] WebSocket connection
- [ ] Live updates
- [ ] Presence indicators

**Phase 5: Advanced Features (2-4 weeks)**
- [ ] Selective sync
- [ ] Bandwidth optimization
- [ ] End-to-end encryption

**Total Estimated Effort:** 8-12 weeks

### 4.5 Technical Challenges

| Challenge | Complexity | Solution |
|-----------|------------|----------|
| **Conflict Resolution** | High | CRDT or last-write-wins |
| **Offline Support** | Medium | Local-first architecture |
| **Authentication** | Medium | Firebase Auth / Supabase Auth |
| **Data Migration** | Medium | Versioned schema |
| **Bandwidth** | Medium | Delta sync, compression |

### 4.6 Cost Estimation

| Provider | Free Tier | Paid (1K users) | Notes |
|----------|-----------|-----------------|-------|
| **Firebase** | 1GB storage, 10GB/mo | ~$25-50/mo | Blaze plan |
| **Supabase** | 500MB storage, 2GB/mo | ~$25/mo | Pro plan |
| **Custom** | Server costs only | ~$5-20/mo | DigitalOcean/Hetzner |

---

## 5. Prioritization Matrix

### 5.1 Strategic Priorities

| Initiative | Business Value | Technical Risk | Dependencies | **Recommended Priority** |
|------------|----------------|----------------|--------------|--------------------------|
| **Impeller Migration** | HIGH | Medium | Flutter SDK | **P1 — Immediate** |
| **Cross-Platform** | HIGH | Medium | Platform SDKs | **P1 — Q3 2026** |
| **Plugin System** | MEDIUM | High | Architecture | **P2 — Q4 2026** |
| **Cloud Sync** | MEDIUM | Very High | Backend | **P3 — 2027** |

### 5.2 Recommended Execution Order

```
Q3 2026 (Jul-Sep):
├── Impeller Migration (2-3 weeks)
└── Cross-Platform Expansion (4-6 weeks)

Q4 2026 (Oct-Dec):
└── Plugin System Architecture (6-8 weeks)

2027:
└── Cloud Sync Solution (8-12 weeks)
```

### 5.3 Resource Requirements

| Initiative | Developers | Skills Required |
|------------|------------|-----------------|
| **Impeller** | 1 | Flutter rendering, GLSL, Metal |
| **Cross-Platform** | 1-2 | Swift, GTK, CMake |
| **Plugin System** | 1 | Dart architecture, package publishing |
| **Cloud Sync** | 1-2 | Backend, Firebase/Supabase, security |

---

## 6. Risk Mitigation Strategies

### 6.1 General Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| **Flutter Breaking Changes** | Medium | High | Pin SDK version, test upgrades |
| **Platform API Changes** | Low | Medium | Abstract platform layer |
| **Performance Regression** | Medium | High | Benchmark suite, A/B testing |
| **Scope Creep** | High | Medium | Strict phase gates |

### 6.2 Contingency Plans

**Impeller Issues:**
- Fallback: `--impeller=skia` flag
- Alternative: Delay migration until stable

**Cross-Platform Issues:**
- Fallback: Windows-only release
- Alternative: Community contributions

**Plugin System Issues:**
- Fallback: Internal-only plugins
- Alternative: Simplified registry

**Cloud Sync Issues:**
- Fallback: Local-only with export/import
- Alternative: Third-party sync (Dropbox, Google Drive)

---

## 7. Conclusion

### 7.1 Key Findings

1. **Impeller Migration** is the most impactful short-term initiative with manageable risk
2. **Cross-Platform Expansion** has strong foundation from existing work (Phase 1-8 complete)
3. **Plugin System** requires significant architectural changes but enables ecosystem growth
4. **Cloud Sync** is the most complex with highest ongoing maintenance burden

### 7.2 Recommendations

1. **Start Impeller Migration immediately** — Windows is already default, macOS ready for preview
2. **Merge cross-platform work** from `fix/window-startup` branch to master
3. **Defer plugin system** until architecture stabilizes
4. **Prototype cloud sync** with Firebase before full commitment

### 7.3 Next Steps

- [ ] Create Impeller verification test suite
- [ ] Document cross-platform merge plan
- [ ] Design plugin interface contracts
- [ ] Evaluate Firebase vs Supabase for sync

---

*This research report was generated using Context7 Flutter documentation, project memory files, and codebase analysis. Last updated: 2026-07-20.*
