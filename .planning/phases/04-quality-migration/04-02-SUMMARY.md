---
phase: 04-quality-migration
plan: 02
status: complete
completed: "2026-07-10"
commits:
  - cabf04d: "feat(ci): add GitHub Actions CI workflow with quality gates and flag matrix"
  - 302413e: "feat(release): add release workflow with MSIX packaging and GitHub Release"
files_created:
  - .github/workflows/ci.yml
  - .github/workflows/release.yml
files_modified:
  - pubspec.yaml
tests_added: 0
tests_passed: N/A (config-only changes)
---

# Plan 02 Summary: CI/CD Pipeline + MSIX Packaging

## What Was Done

### Task 1: GitHub Actions CI Workflow
Created `.github/workflows/ci.yml` with:
- **Triggers**: push to master, pull_request to master, workflow_dispatch
- **Job 1: quality-gates** — Three-platform matrix (Windows/macOS/Linux)
  - `actions/checkout@v4` + `subosito/flutter-action@v2` with cache
  - Linux: `apt-get install clang cmake ninja-build pkg-config libgtk-3-dev`
  - Quality Gate 1: `flutter analyze --fatal-infos`
  - Quality Gate 2: `flutter test`
  - Quality Gate 3: `flutter build {windows|macos|linux}`
- **Job 2: flag-matrix** — Windows-only, 3 flag combinations
  - Default (USE_NEW_FULLSCREEN=false)
  - `USE_NEW_FULLSCREEN=true`
  - `USE_NEW_FULLSCREEN=true + USE_WINDOWS_NATIVE_FULLSCREEN=true`
  - Runs `flutter test` + `flutter build windows` per flag combo

### Task 2: Release Workflow + MSIX Config
Created `.github/workflows/release.yml` with:
- **Trigger**: workflow_dispatch with `version` input (e.g., v1.0.0-rc.1)
- **Steps**: checkout → flutter-action → build windows → msix:create → upload-artifact → gh-release
- **Release**: prerelease=true, MSIX attached

Modified `pubspec.yaml`:
- Added `msix: ^3.16.0` to dev_dependencies
- Added `msix_config` section: display_name, publisher_display_name, identity_name, msix_version (1.0.0.0), logo_path, capabilities

## Acceptance Criteria Check

- [x] .github/workflows/ci.yml exists with correct YAML
- [x] quality-gates job: 3-platform matrix (windows/macos/linux)
- [x] flag-matrix job: 3 flag combinations on Windows
- [x] 3 Quality Gates: analyze / test / build
- [x] Linux step includes apt-get install for desktop deps
- [x] Triggers: push + pull_request + workflow_dispatch
- [x] Uses subosito/flutter-action@v2 + cache: true
- [x] .github/workflows/release.yml exists with correct YAML
- [x] Trigger: workflow_dispatch + version input
- [x] Steps: flutter build + msix:create + upload-artifact + gh-release
- [x] prerelease: true
- [x] pubspec.yaml contains msix_config with required fields

## Decisions Applied

| Decision | Implementation |
|----------|---------------|
| D-42: GitHub Actions | Both workflows use GitHub Actions |
| D-43: Test + Build | CI runs analyze + test + build |
| D-44: Three-platform coverage | quality-gates matrix covers all 3 platforms |
| D-45: Full triggers | push + PR + workflow_dispatch |
| D-48: Semantic versioning | workflow_dispatch version input for RC tags |
| D-49: GitHub Release + MSIX | release.yml creates prerelease with MSIX |
| D-51: CI auto-packaging | release.yml automates MSIX creation |
| D-52: Manual trigger + CI execution | workflow_dispatch trigger |

## Risks

| Risk | Mitigation |
|------|-----------|
| Linux desktop deps missing in CI | apt-get install step for clang/cmake/ninja/pkg-config/gtk3 |
| MSIX version format (4-part) | msix_version: 1.0.0.0 in pubspec, dynamic override in workflow |
| macOS arm64 runner | macos-latest defaults to arm64, compatible with Flutter stable |
