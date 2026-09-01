---
phase: 02
plan: 02
subsystem: kernel-diagnostics
tags: [dart, flutter, diagnostics, trusted-location, source-evidence, security]
requires:
  - phase: 02-01
    provides: immutable ErrorLocation formatter contract and frozen ErrorReport raw-stack evidence
provides:
  - Conservative stored-stack extraction of the first application package frame and up to two successors
  - Trusted-root, build-gated source excerpts with immutable numbered plus/minus-two line evidence
  - Fail-closed path containment for package and file frames
  - Stable D-05 and D-01 degradation paths without secondary diagnostic failures
affects: [02-03, 02-04, phase-03-error-card]
actuals:
  tokens: 5416
  tasks: 2
  commits: 3
tech-stack:
  added: []
  patterns:
    - Flutter StackFrame parsing only after malformed VM-line filtering
    - Stored raw stack is the sole locator input; no live-stack substitution
    - Self-anchored diagnostics file frame establishes the only production source root
    - Release source evidence short-circuits before File access
    - Component-aware canonical containment rejects traversal and sibling-prefix escapes
key-files:
  created:
    - lib/kernel/diagnostics/source_line_reader.dart
    - test/diagnostics/error_location_test.dart
    - test/diagnostics/source_line_reader_test.dart
  modified:
    - lib/kernel/diagnostics/error_location.dart
key-decisions:
  - "D-05 location extraction accepts only exact package:simple_player_flutter frames; the first is primary and no more than two later project frames are retained."
  - "D-01 source I/O is limited to debug/profile after an owned diagnostics file frame establishes a trusted root; there is no cwd, executable-directory, or arbitrary-frame fallback."
  - "Path containment is fail-closed: reject traversal before canonicalization, then require component-aware canonical root containment."
patterns-established:
  - "Diagnostic parsing treats malformed input as absent evidence rather than throwing from the reporting chain."
  - "SourceFileAccess provides deterministic filesystem and release no-I/O verification seams."
requirements-completed: [LOC-01, LOC-02]
coverage:
  - id: conservative-project-frame-extraction
    description: "Frozen raw stacks produce the first exact simple_player_flutter frame and at most two following project frames, or no location evidence."
    requirement: LOC-01
    verification:
      - kind: test
        ref: test/diagnostics/error_location_test.dart#selects the first project frame and two following project frames
        status: pass
      - kind: test
        ref: test/diagnostics/error_location_test.dart#skips malformed VM lines without changing frozen raw evidence
        status: pass
      - kind: test
        ref: test/diagnostics/error_location_test.dart#returns the stable null fallback for non-project or degraded stacks
        status: pass
    human_judgment: false
  - id: trusted-build-gated-source-excerpts
    description: "Trusted debug/profile source evidence returns immutable one-based target plus/minus-two excerpts and safely omits every untrusted case."
    requirement: LOC-02
    verification:
      - kind: test
        ref: test/diagnostics/source_line_reader_test.dart#reads numbered target plus/minus two lines and clamps file edges
        status: pass
      - kind: test
        ref: test/diagnostics/source_line_reader_test.dart#rejects traversal sibling prefixes absolute escape and invalid lines
        status: pass
      - kind: test
        ref: test/diagnostics/source_line_reader_test.dart#normalizes a Windows file URI form for case-insensitive containment
        status: pass
      - kind: test
        ref: test/diagnostics/source_line_reader_test.dart#does no file access in release and degrades without a trusted root
        status: pass
    human_judgment: false
duration: 18m 43s
completed: 2026-08-30
status: complete
---

# Phase 2 Plan 02: Trusted Location and Source Evidence Summary

已交付仅基于冻结 raw stack 的保守项目帧定位，以及仅在 debug/profile 的受信项目根中读取带真实行号的 ±2 源码证据；任一解析、路径或 I/O 异常均只降级证据，绝不制造第二个错误。

## Performance

- Duration: 18m 43s
- Started: 2026-08-30T13:29:02Z
- Completed: 2026-08-30T13:47:45Z
- Tasks: 2/2
- Files modified: 4

## Accomplishments

- 使用 Flutter foundation `StackFrame` 解析 stored raw stack，并在 API 调用前过滤 malformed `#` VM frame，避免 SDK `match!` 解析边界抛出。
- 严格按 D-05 选择第一个 `package:simple_player_flutter` frame 为 primary，只保留随后两个同包 frame，且所有 retained collections 都是不可修改快照。
- 为 empty、unavailable、async suspension、elision、foreign package 和 malformed-only 输入提供确定性 `null` fallback，不读取 live stack、不访问文件系统。
- 实现 `SourceLineReader`：release 在任何 canonicalize/read 调用前短路；debug/profile 只接受测试注入或 locator-owned `file:` diagnostics anchor 建立的 root。
- package frame 仅映射至 `<trusted-root>/lib/<packagePath>`；file frame 经过 traversal 拒绝、Windows URI/drive 规范化、canonical component boundary containment 后才可同步读取。
- 源码成功证据最多返回目标行 ±2 共五条 immutable `SourceLine`，保留真实 1-based line number，并在文件边界正确 clamp。

## Task Commits

1. `6faa7768` — `feat(02-02): extract trusted project stack frames`
2. `bca6ab8b` — `feat(02-02): read trusted source excerpts`
3. `dc291395` — `fix(02-02): anchor source root from owned file frame`

## Files Created/Modified

- `lib/kernel/diagnostics/error_location.dart` — StackFrame pre-filter/parser、exact package project-frame selector、stable immutable frame text and metadata。
- `test/diagnostics/error_location_test.dart` — normal/malformed/async/foreign/empty frozen-stack selection matrix。
- `lib/kernel/diagnostics/source_line_reader.dart` — self-anchored trusted root、source build-mode gate、canonical containment、numbered source excerpt reader。
- `test/diagnostics/source_line_reader_test.dart` — temp-root containment、Windows drive normalization、release no-I/O、traversal/prefix/out-of-range and boundary clamp matrix。

## Decisions Made

- D-05 只信任 `StackFrame.package == 'simple_player_flutter'` 的 parsed package frame；file frame 不可冒充 primary report location。
- D-01 的 root 仅可来自 diagnostics module own `file:` stack frame 或 explicit testing seam；缺 anchor 必须保持 untrusted。
- source path 必须先拒绝 `..`，后 canonicalize，最后以完整 path component 验证 containment，不能使用字符串 prefix。

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] 修复 self-anchor 只检查首个项目 package frame 导致无法捕获 file root**
- **Found during:** Task 2
- **Issue:** 通用 location extractor 依 D-05 只选择 package frame，若它位于 self-anchor 扫描前，reader 无法观察后续 project-owned `file:` diagnostics frame。
- **Fix:** root capture 独立扫描当前 stack 的所有安全 parsed `file:` frames，并仅接受 `/lib/kernel/diagnostics/` marker；仍不回退到 cwd、executable 或 arbitrary frame。
- **Files modified:** `lib/kernel/diagnostics/source_line_reader.dart`
- **Verification:** focused source-reader tests、focused Flutter analyze、kernel logger gate all passed。
- **Committed in:** `dc291395`

**Total deviations:** 1 auto-fixed (Rule 1: 1).
**Impact:** 修复 production self-anchor correctness，同时保持 D-05 report primary selection 和 fail-closed trust boundary 不变。

## Issues Encountered

- Task 1 RED tests failed as expected because `extractErrorLocation` did not exist.
- Task 2 RED tests failed as expected because `source_line_reader.dart` and its test seams did not exist.
- The initial `SourceExcerpt` constructor reused its formal parameter name for field initialization; Flutter compilation exposed the conflict and the constructor was corrected before the task verification passed.

## User Setup Required

None.

## Next Phase Readiness

- 02-03 can enrich accepted `ErrorReport` values with `extractErrorLocation` and optional `SourceLineReader` evidence before effect fan-out.
- 02-04 can retain this no-I/O release behavior while wiring the durable log location and production effects.
- Phase 3 formatter/card presentation can consume immutable primary/secondary frame and source-excerpt values without accessing the filesystem.

## Verification Results

- PASS — `D:/flutter/bin/flutter test test/diagnostics/error_location_test.dart`
- PASS — `D:/flutter/bin/flutter test test/diagnostics/source_line_reader_test.dart`
- PASS — `D:/flutter/bin/flutter test test/diagnostics/error_location_test.dart test/diagnostics/source_line_reader_test.dart`
- PASS — `D:/flutter/bin/flutter analyze lib/kernel/diagnostics/error_location.dart lib/kernel/diagnostics/source_line_reader.dart test/diagnostics/error_location_test.dart test/diagnostics/source_line_reader_test.dart`
- PASS — `bash tool/audit/kernel_logger_gate.sh`
- PASS — `git diff --check`
- PASS — acceptance criteria: stored-only frame extraction, first-package selection plus bounded successors, malformed degradation, trusted-root-only source I/O, traversal/component containment, Windows normalization, bounded numbered excerpts, release no-I/O, and root-capture failure degradation.

*Phase: 02-trusted-location-file-evidence, Completed: 2026-08-30*

## Self-Check: PASSED
