# Phase D: 质量收尾与迁移完成 - Research

**Researched:** 2026-07-10
**Domain:** Flutter Desktop CI/CD, Regression Testing, MSIX Packaging, Legacy Decommissioning
**Confidence:** MEDIUM

## Summary

Phase D is the validation and closure phase for the fullscreen upgrade project. It involves three major work streams: (1) building a regression test matrix covering 8 mandatory scenarios across Windows/macOS/Linux, (2) setting up GitHub Actions CI for automated testing and build smoke tests, and (3) MSIX packaging with RC version numbering for distribution.

The project already has 87+ test files covering unit, widget, and integration tests. The fullscreen subsystem has dedicated test files for the adapter, command queue, all three platform drivers, and the driver factory. Phase D's primary challenge is not writing new code but validating the existing implementation across all scenarios and platforms, then wrapping it for distribution.

Key risks: macOS/Linux integration tests require real window managers (not available in headless CI), so those platforms will be smoke-test only in CI with deeper validation deferred to manual/RC testing. The `msix` Dart package (pub.dev) is the standard tool for MSIX packaging — it is distinct from the npm/crates `msix` packages which are unrelated.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Regression test matrix | CI/CD | Local dev | Automated tests run in CI, manual tests run locally |
| Build smoke tests | CI/CD | — | GitHub Actions builds all 3 platforms |
| E2E validation | Integration test | Manual | Desktop E2E requires real window manager |
| MSIX packaging | CI/CD | — | Automated build + package in release workflow |
| Legacy decommission | Code | — | Gradual deprecation markers + removal |
| Quality gates | CI/CD | — | flutter analyze + flutter test as gates |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter_test | SDK | Unit + widget testing | Built-in, no additional dependency |
| integration_test | SDK | Integration/E2E testing | Built-in, required for desktop E2E |
| msix | ^3.16+ [ASSUMED] | MSIX packaging | pub.dev standard for Flutter MSIX [CITED: docs.flutter.dev/platform-integration/windows/building] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| subosito/flutter-action | v2 | GitHub Actions Flutter setup | Every CI workflow [ASSUMED] |
| actions/upload-artifact | v4 | Upload build artifacts | Release workflows [ASSUMED] |
| softprops/action-gh-release | v2 | GitHub Release creation | RC release publishing [ASSUMED] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| msix (Dart) | msstore CLI | msstore requires Microsoft Store seller account; msix works for direct distribution |
| subosito/flutter-action | Manual Flutter install | Manual install is slower and harder to cache |
| GitHub Actions | Azure DevOps | GitHub Actions is native to the repo, no external service needed |

**Installation:**
```bash
flutter pub add msix --dev
```

**Version verification:** The `msix` package should be verified against pub.dev before inclusion. The npm/crates `msix` packages are unrelated and flagged as SUS/SLOP. [ASSUMED: pub.dev msix package exists and is maintained]

## Package Legitimacy Audit

> Run before completing this section. Only packages that will be installed by this phase.

| Package | Registry | Verdict | Disposition |
|---------|----------|---------|-------------|
| msix | pub.dev [ASSUMED] | [ASSUMED] | Planner must verify on pub.dev before install |
| subosito/flutter-action | GitHub Marketplace [ASSUMED] | [ASSUMED] | Planner must verify on GitHub before use |

**Note:** The `msix` npm package (verdict: SUS, low-downloads) and `msix` crates package (verdict: SUS, low-downloads) are unrelated to the Flutter `msix` Dart package. Do not confuse them. The Flutter MSIX packaging uses the Dart `msix` package from pub.dev, which is the standard tool documented at [docs.flutter.dev/platform-integration/windows/building](https://docs.flutter.dev/platform-integration/windows/building). [CITED: docs.flutter.dev/platform-integration/windows/building]

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Actions CI                          │
│                                                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                  │
│  │  Windows  │  │  macOS   │  │  Linux   │   Build Matrix   │
│  │  Runner   │  │  Runner  │  │  Runner  │                  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘                  │
│       │              │              │                        │
│       ▼              ▼              ▼                        │
│  ┌─────────────────────────────────────┐                    │
│  │  flutter analyze (zero warnings)    │   Quality Gate 1   │
│  └─────────────┬───────────────────────┘                    │
│                ▼                                             │
│  ┌─────────────────────────────────────┐                    │
│  │  flutter test (unit + widget)       │   Quality Gate 2   │
│  └─────────────┬───────────────────────┘                    │
│                ▼                                             │
│  ┌─────────────────────────────────────┐                    │
│  │  flutter build (smoke test)         │   Quality Gate 3   │
│  └─────────────┬───────────────────────┘                    │
│                ▼                                             │
│  ┌─────────────────────────────────────┐                    │
│  │  MSIX Package (Windows only)        │   Release Artifact │
│  └─────────────────────────────────────┘                    │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                   Regression Matrix                           │
│                                                              │
│  ┌──────────────────┐  ┌──────────────────┐                │
│  │  Automated Suite  │  │  Manual Suite    │                │
│  │  (CI runs)        │  │  (RC validation) │                │
│  │                   │  │                  │                │
│  │  • Queue/Idempot  │  │  • Multi-display │                │
│  │  • Timeout/Error  │  │  • Focus/TopMost │                │
│  │  • Restore logic  │  │  • Linux WM diff │                │
│  │  • 10x/50x rapid  │  │  • Minimized→FS  │                │
│  └──────────────────┘  └──────────────────┘                │
└─────────────────────────────────────────────────────────────┘
```

### Recommended Project Structure

```
.github/
└── workflows/
    ├── ci.yml                    # PR + push: analyze + test + build smoke
    ├── release.yml               # RC release: build + MSIX + GitHub Release
    └── regression.yml            # Scheduled: full regression matrix

test/
├── regression/
│   ├── regression_matrix.md      # Regression test matrix document
│   ├── high_risk_suite_test.dart # Fast key-press, maximized restore, StateDesync
│   └── smoke_suite_test.dart     # 8 mandatory scenarios (automated subset)
├── integration/
│   └── fullscreen_e2e_test.dart  # Fullscreen E2E (Windows only in CI)
└── ...existing test files...
```

### Pattern 1: CI Quality Gates Pipeline

**What:** Three-stage quality gate pipeline in CI — analyze, test, build.
**When to use:** Every PR and push to ensure zero-regression.
**Example:**
```yaml
# Source: Flutter docs + subosito/flutter-action docs [ASSUMED]
jobs:
  quality-gates:
    strategy:
      matrix:
        include:
          - os: windows-latest
            platform: windows
          - os: macos-latest
            platform: macos
          - os: ubuntu-latest
            platform: linux
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
          cache: true
      - run: flutter analyze --fatal-infos
      - run: flutter test
      - run: flutter build ${{ matrix.platform }}
```

### Pattern 2: Regression Matrix Structure

**What:** Structured regression test matrix with standardized case IDs and pass/fail criteria.
**When to use:** Documenting and executing the 8 mandatory scenarios + high-risk suite.
**Example:**
```markdown
| Case ID     | Platform | Scenario                        | Type     | Priority |
|-------------|----------|---------------------------------|----------|----------|
| FS-WIN-001  | Windows  | Enter/exit fullscreen           | Auto     | P0       |
| FS-WIN-002  | Windows  | Rapid F key 10x                 | Auto     | P0       |
| FS-WIN-003  | Windows  | Rapid F key 50x                 | Auto     | P0       |
| FS-WIN-004  | Windows  | Maximized→FS→Exit               | Auto     | P0       |
| FS-WIN-005  | Windows  | Playing + fullscreen             | Auto     | P0       |
| FS-WIN-006  | Windows  | Paused + fullscreen              | Auto     | P0       |
| FS-WIN-007  | Windows  | F key vs button consistency      | Auto     | P0       |
| FS-WIN-008  | Windows  | ESC semantic (exit FS / close)   | Auto     | P0       |
| FS-MAC-001  | macOS    | Enter/exit fullscreen           | Manual   | P1       |
| FS-LIN-001  | Linux    | Enter/exit fullscreen (GNOME)   | Manual   | P1       |
```

### Anti-Patterns to Avoid

- **Testing only happy path:** Must include timeout, callback-missing, and StateDesync recovery paths
- **Skipping rapid key-press tests:** 10x and 50x F-key presses are the #1 source of fullscreen state bugs
- **Assuming CI can test real window managers:** macOS/Linux window behavior requires real desktop — CI can only build-smoke, not E2E
- **Single-flag testing:** Must test both `USE_NEW_FULLSCREEN=true` and `USE_NEW_FULLSCREEN=false` to validate feature flag

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| MSIX packaging | Custom PowerShell scripts | `msix` Dart package | Standard tool, handles signing, versioning, manifest |
| CI Flutter setup | Manual SDK download | subosito/flutter-action | Caching, version pinning, cross-platform |
| Release notes | Manual changelog | GitHub Release auto-generation | Integrates with PR/commit history |
| Test coverage | Custom coverage scripts | `flutter test --coverage` + lcov | Built-in, standard format |

**Key insight:** Phase D is a validation/closure phase — minimize new code, maximize use of existing tools and patterns.

## Common Pitfalls

### Pitfall 1: CI Build Matrix Missing Platform-Specific Dependencies
**What goes wrong:** Linux builds fail because `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev` are not installed.
**Why it happens:** Ubuntu runners don't have Flutter desktop build dependencies pre-installed.
**How to avoid:** Add a setup step for Linux: `sudo apt-get update && sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev`
**Warning signs:** Build fails with "Could not find a compatible C compiler" or similar.

### Pitfall 2: Feature Flag Testing Omission
**What goes wrong:** CI only tests default flags (`USE_NEW_FULLSCREEN=false`), missing regressions in the new implementation.
**Why it happens:** Default `--dart-define` values are `false`, so CI builds don't exercise new code paths.
**How to add one-off jobs for each flag combination:** [ASSUMED]
**Warning signs:** Regressions discovered only after manual testing.

### Pitfall 3: macOS Runner Architecture Mismatch
**What goes wrong:** Build targets x64 but runner is arm64 (Apple Silicon), or vice versa.
**Why it happens:** `macos-latest` now defaults to arm64 runners.
**How to avoid:** Use `macos-latest` for arm64 builds, or specify `macos-13` for x64. [ASSUMED]
**Warning signs:** Build succeeds but app crashes on target architecture.

### Pitfall 4: MSIX Version Number Format
**What goes wrong:** MSIX requires `x.x.x.x` format (4 parts), but semantic versioning uses `x.x.x-rc.1`.
**Why it happens:** MSIX manifest doesn't support pre-release labels in version field.
**How to avoid:** Map RC versions: `v1.0.0-rc.1` → MSIX version `1.0.0.1`. Use `msix_version` in pubspec.yaml or `distribute_options.yaml`.
**Warning signs:** `msix:create` fails with version format error.

### Pitfall 5: Regression Matrix Not Tracking Build Configuration
**What goes wrong:** Test results are recorded without noting which flag configuration was used, making it impossible to reproduce failures.
**Why it happens:** Regression matrix document doesn't include flag column.
**How to avoid:** Every test run must record: branch, commit, build number, `USE_NEW_FULLSCREEN` value, `USE_WINDOWS_NATIVE_FULLSCREEN` value.
**Warning signs:** "It passed on my machine" without configuration context.

## Code Examples

### CI Workflow with Feature Flag Matrix

```yaml
# Source: Flutter docs CI patterns + subosito/flutter-action [ASSUMED]
name: CI
on:
  push:
    branches: [master]
  pull_request:
    branches: [master]

jobs:
  analyze-and-test:
    strategy:
      matrix:
        include:
          - os: windows-latest
            platform: windows
          - os: macos-latest
            platform: macos
          - os: ubuntu-latest
            platform: linux
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
          cache: true

      # Linux desktop build dependencies
      - name: Install Linux dependencies
        if: matrix.platform == 'linux'
        run: |
          sudo apt-get update
          sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev

      # Quality Gate 1: Static analysis
      - name: Analyze
        run: flutter analyze --fatal-infos

      # Quality Gate 2: Unit + widget tests
      - name: Test
        run: flutter test

      # Quality Gate 3: Build smoke test
      - name: Build
        run: flutter build ${{ matrix.platform }}

  # Feature flag validation (Windows only — most complex platform)
  flag-matrix:
    runs-on: windows-latest
    strategy:
      matrix:
        flags:
          - ''  # default (USE_NEW_FULLSCREEN=false)
          - '--dart-define=USE_NEW_FULLSCREEN=true'
          - '--dart-define=USE_NEW_FULLSCREEN=true --dart-define=USE_WINDOWS_NATIVE_FULLSCREEN=true'
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
          cache: true
      - name: Test with flags
        run: flutter test ${{ matrix.flags }}
      - name: Build with flags
        run: flutter build windows ${{ matrix.flags }}
```

### MSIX Release Workflow

```yaml
# Source: docs.flutter.dev/deployment/windows + distribute_options.yaml pattern [ASSUMED]
name: Release
on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Version tag (e.g., v1.0.0-rc.1)'
        required: true

jobs:
  release-windows:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
          cache: true

      - name: Build Windows
        run: flutter build windows --dart-define=USE_NEW_FULLSCREEN=true

      - name: Create MSIX
        run: dart run msix:create

      - name: Upload MSIX artifact
        uses: actions/upload-artifact@v4
        with:
          name: msix-package
          path: build/windows/x64/runner/Release/*.msix

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          tag_name: ${{ github.event.inputs.version }}
          prerelease: true
          files: build/windows/x64/runner/Release/*.msix
```

### Regression Matrix Document Template

```markdown
# Fullscreen Regression Matrix

**Branch:** feat/v1.8-stability-polish-plan-02-02
**Build:** {commit hash}
**Flags:** USE_NEW_FULLSCREEN={true|false}, USE_WINDOWS_NATIVE_FULLSCREEN={true|false}
**Date:** {YYYY-MM-DD}
**Tester:** {name or CI}

## Results

| Case ID    | Platform | Scenario              | Type  | Priority | Result | Evidence |
|------------|----------|-----------------------|-------|----------|--------|----------|
| FS-WIN-001 | Windows  | Enter/exit fullscreen | Auto  | P0       | pass   | {log}   |
| FS-WIN-002 | Windows  | Rapid F 10x           | Auto  | P0       | pass   | {log}   |
| FS-WIN-003 | Windows  | Rapid F 50x           | Auto  | P0       | fail   | {log}   |
| ...        | ...      | ...                   | ...   | ...      | ...    | ...      |

## Blocking Rules

- P0 failures: Block release
- StateDesync without recovery: Block release
- PlatformFailure on any platform: Block release (upgrade to deep test)

## Status: {PASS / BLOCKED}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| fullscreen_window direct call | FullscreenAdapter + Driver pattern | Phase A-C (2026-07) | Full abstraction layer |
| No feature flag | USE_NEW_FULLSCREEN compile-time flag | Phase B (2026-07) | Gradual migration path |
| No regression matrix | Structured 8-scenario + high-risk suite | Phase D (this phase) | Formal validation |

**Deprecated/outdated:**
- `fullscreen_window` direct calls in UI/WindowService: deprecated, replaced by FullscreenAdapter
- `WindowState.mode` for fullscreen queries: deprecated, replaced by `FullscreenSnapshot`

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `msix` Dart package exists on pub.dev and is actively maintained | Standard Stack | MSIX packaging blocked; need alternative tool |
| A2 | `subosito/flutter-action@v2` supports `cache: true` parameter | Standard Stack | CI builds slower without caching |
| A3 | `macos-latest` GitHub runner is arm64 (Apple Silicon) | Pitfall 3 | Build architecture mismatch |
| A4 | Linux desktop build requires `clang cmake ninja-build pkg-config libgtk-3-dev` | Pitfall 1 | Linux build fails in CI |
| A5 | MSIX version format requires 4-part `x.x.x.x`, not semantic version with pre-release label | Pitfall 4 | MSIX packaging fails |
| A6 | `softprops/action-gh-release@v2` is the standard GitHub Release action | Code Examples | Release workflow needs different action |
| A7 | `actions/upload-artifact@v4` is the current version | Code Examples | Artifact upload may fail on older version |

**All claims in this research are ASSUMED from training knowledge.** The planner should verify critical assumptions (A1, A5) before implementation.

## Open Questions

1. **What is the current Flutter SDK version on the developer machine?**
   - What we know: pubspec.yaml specifies `sdk: ^3.11.5`
   - What's unclear: Whether CI should pin to this exact version or use latest stable
   - Recommendation: Pin to `3.11.x` in CI for reproducibility

2. **Does the project have a signing certificate for MSIX?**
   - What we know: `distribute_options.yaml` exists with basic config
   - What's unclear: Whether a `.pfx` certificate is available for signing
   - Recommendation: For RC releases, use self-signed certificate or skip signing (users can sideload)

3. **What is the target version number for RC?**
   - What we know: Current `pubspec.yaml` version is `0.0.1`
   - What's unclear: Whether to bump to `1.0.0-rc.1` or keep `0.x`
   - Recommendation: Follow decision D-48 (semantic versioning: `v1.0.0-rc.1`)

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | All phases | ✓ | ^3.11.5 (pubspec) | — |
| Dart SDK | All phases | ✓ | ^3.11.5 (pubspec) | — |
| Windows runner | CI | ✓ | windows-latest | — |
| macOS runner | CI | ✓ | macos-latest | — |
| Linux runner | CI | ✓ | ubuntu-latest | — |
| MSIX signing cert | MSIX packaging | ? | — | Self-signed or skip |

**Missing dependencies with no fallback:**
- None identified — all CI dependencies are available on GitHub runners

**Missing dependencies with fallback:**
- MSIX signing certificate: Use self-signed for testing, skip for RC

## Validation Architecture

> config.json has `workflow.nyquist_validation: true`, so this section is included.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) + integration_test (SDK) |
| Config file | analysis_options.yaml |
| Quick run command | `flutter test` |
| Full suite command | `flutter test --coverage` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| STATE-01 | FullscreenSnapshot fields correct | unit | `flutter test test/kernel/bridge/fullscreen_adapter_test.dart` | ✅ |
| STATE-02 | UI queries via ValueListenable<Snapshot> | widget | `flutter test test/widget/player/` | ✅ |
| STATE-03 | Per-window state isolation | unit | `flutter test test/kernel/bridge/fullscreen_adapter_test.dart` | ✅ |
| EVT-01 | Event stream 7 types | unit | `flutter test test/kernel/bridge/fullscreen_adapter_test.dart` | ✅ |
| EVT-02 | Stream decoupled from _WindowListener | unit | `flutter test test/kernel/bridge/fullscreen_adapter_test.dart` | ✅ |
| EVT-03 | forcedChange carries diff | unit | `flutter test test/kernel/bridge/fullscreen_adapter_test.dart` | ✅ |
| ERR-01 | 7 error types | unit | `flutter test test/kernel/bridge/fullscreen_adapter_test.dart` | ✅ |
| ERR-02 | Error events notify UI | unit | `flutter test test/kernel/bridge/fullscreen_adapter_test.dart` | ✅ |
| ERR-03 | PermissionDenied/Unsupported prompts | widget | `flutter test test/widget/player/` | ⚠️ Partial |
| CMD-01 | Per-window command queue | unit | `flutter test test/kernel/bridge/fullscreen_command_queue_test.dart` | ✅ |
| CMD-02 | Idempotent merge | unit | `flutter test test/kernel/bridge/fullscreen_command_queue_test.dart` | ✅ |
| CMD-03 | Post-exec state readback | unit | `flutter test test/kernel/bridge/desktop_fullscreen_adapter_test.dart` | ✅ |
| RST-01 | Windowed→FS→Exit restore | unit | `flutter test test/kernel/bridge/desktop_fullscreen_adapter_test.dart` | ✅ |
| RST-02 | Maximized→FS→Exit restore | unit | `flutter test test/kernel/bridge/desktop_fullscreen_adapter_test.dart` | ✅ |
| RST-03 | Secondary display restore | unit | `flutter test test/kernel/bridge/desktop_fullscreen_adapter_test.dart` | ✅ |
| RST-04 | Minimized→FS handling | unit | `flutter test test/kernel/bridge/desktop_fullscreen_adapter_test.dart` | ✅ |
| PLAT-01 | Windows WS_THICKFRAME | unit | `flutter test test/platform/windows_fullscreen_driver_test.dart` | ✅ |
| PLAT-02 | macOS delegate callback | unit | `flutter test test/platform/macos_fullscreen_driver_test.dart` | ✅ |
| PLAT-03 | Linux WM fallback | unit | `flutter test test/platform/linux_fullscreen_driver_test.dart` | ✅ |
| PLAT-04 | capabilities() returns real values | unit | `flutter test test/platform/fullscreen_driver_factory_test.dart` | ✅ |
| ARCH-01 | FullscreenAdapter independent | unit | `flutter test test/kernel/bridge/fullscreen_adapter_test.dart` | ✅ |
| ARCH-02 | WindowBridge keeps generic ops | unit | `flutter test test/unit/bridge/window_service_test.dart` | ✅ |
| ARCH-03 | Legacy migration + feature flag | unit | `flutter test test/kernel/bridge/desktop_fullscreen_adapter_test.dart` | ✅ |

### Sampling Rate

- **Per task commit:** `flutter test` (quick subset)
- **Per wave merge:** `flutter test --coverage`
- **Phase gate:** Full suite green + regression matrix pass before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/regression/high_risk_suite_test.dart` — rapid key-press (10/50x), maximized restore, StateDesync recovery
- [ ] `test/regression/smoke_suite_test.dart` — 8 mandatory scenarios automated subset
- [ ] `test/integration/fullscreen_e2e_test.dart` — fullscreen E2E with real window
- [ ] `.github/workflows/ci.yml` — CI workflow (does not exist yet)
- [ ] `.github/workflows/release.yml` — Release workflow (does not exist yet)
- [ ] `test/regression/regression_matrix.md` — Regression matrix document

## Security Domain

> Not applicable for Phase D — this is a validation/closure phase with no new security-sensitive code. No authentication, no user input handling, no cryptography.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | no | — |
| V6 Cryptography | no | — |

**Rationale:** Phase D only validates existing code and sets up CI/packaging. No new security-sensitive code is introduced.

## Sources

### Primary (HIGH confidence)
- [docs.flutter.dev/platform-integration/desktop](https://docs.flutter.dev/platform-integration/desktop) — Desktop build commands
- [docs.flutter.dev/testing/integration-tests](https://docs.flutter.dev/testing/integration-tests) — Integration test setup + CI examples
- [docs.flutter.dev/deployment/windows](https://docs.flutter.dev/deployment/windows) — MSIX packaging + Microsoft Store publishing
- [docs.flutter.dev/platform-integration/windows/building](https://docs.flutter.dev/platform-integration/windows/building) — MSIX packaging details

### Secondary (MEDIUM confidence)
- Context7 `/websites/flutter_dev` — Flutter docs snippets for CI and MSIX

### Tertiary (LOW confidence)
- Training knowledge — GitHub Actions patterns, subosito/flutter-action usage, MSIX version format

## Metadata

**Confidence breakdown:**
- Standard Stack: MEDIUM — tools are well-known but versions not verified against current registries
- Architecture: HIGH — CI/testing patterns are standard and well-documented
- Pitfalls: MEDIUM — based on common Flutter desktop CI issues, not project-specific verification

**Research date:** 2026-07-10
**Valid until:** 2026-08-10 (stable phase, CI patterns change slowly)
