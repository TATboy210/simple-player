# Research Summary — v1.1 Testing, Quality & Code Optimization

**Date:** 2026-05-29
**Source:** Context7 (Flutter docs), codebase analysis

## Stack Findings

- `integration_test` package: built into Flutter SDK, no extra dependency
- `flutter test integration_test/` runs on desktop (Windows/macOS/Linux)
- Golden tests: `matchesGoldenFile()` with `.png` convention
- Custom `goldenFileComparator` needed for cross-machine consistency (GPU-dependent)
- `AnimationSheetBuilder.collate()` for animation golden tests (replaces deprecated `display`)

## Feature Patterns

**Integration tests:**
- `IntegrationTestWidgetsFlutterBinding.ensureInitialized()` in main
- `tester.pumpWidget()` → interact → `pumpAndSettle()` → assert
- Desktop: builds real app, runs on actual platform
- Key flows to test: file open, play/pause, seek, volume, fullscreen, playlist navigation

**Golden tests:**
- `matchesGoldenFile('filename.png')` in `testWidgets`
- Custom comparator extends `GoldenFileComparator`
- `autoUpdateGoldenFiles` flag for CI: `flutter test --update-goldens`
- Risk: BackdropFilter/glass effects may differ across GPUs

**Code optimization:**
- Window layer: 5 files ~337 lines (from CONCERNS.md analysis)
- Dead code: check for unused imports, unreachable code, deprecated patterns
- Static analysis: `flutter analyze` already 0 errors, can add custom lint rules

## Architecture Notes

- Current test structure: `test/` with 27 test files, FakeEngine hand-written
- Integration tests go in `integration_test/` (separate from unit tests)
- Golden test images stored in `test/golden/` alongside test files
- No new dependencies needed for v1.1

## Pitfalls

- Golden tests GPU-dependent: BackdropFilter renders differently on Intel/NVIDIA/AMD
- Integration tests on desktop: slower than mobile (full app build)
- Window code refactoring: must preserve MethodChannel contract with C++ runner
- Dead code removal: verify no runtime reflection or code gen references before deleting

---
*Research completed: 2026-05-29*
