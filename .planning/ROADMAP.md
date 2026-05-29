# Roadmap: Simple Player Flutter

## Milestones

- **v1.0 Window Management & UI Unification** — Phases 1-5 (shipped 2026-05-29)
- **v1.1 Testing, Quality & Code Optimization** — Phases 6-8 (in progress)

## Phases

<details>
<summary>v1.0 Window Management & UI Unification (Phases 1-5) — SHIPPED 2026-05-29</summary>

- [x] Phase 1: Window Management Foundation (4/4 plans) — completed 2026-05-28
- [x] Phase 2: Widget Unification (2/2 plans) — completed 2026-05-28
- [x] Phase 3: Performance Optimization (4/4 plans) — completed 2026-05-28
- [x] Phase 4: Test Coverage (1/1 plan) — completed 2026-05-29
- [x] Phase 5: Technical Debt Cleanup (3 waves) — completed 2026-05-29

</details>

### v1.1 Testing, Quality & Code Optimization (In Progress)

- [x] **Phase 6: Window Code Optimization** — Fix fullscreen interaction, DragToResizeArea config, ESC key wiring (OPT-01) (completed 2026-05-29)
  Plans:
  - [x] 06-01-PLAN.md — DragToResizeArea fullscreen-aware + ESC key fullscreen exit
- [ ] **Phase 7: Integration & Golden Tests** — E2E flows + visual regression (TEST-05, TEST-06)
  Plans:
  - [x] 07-03-PLAN.md — Window optimization: BoxFit.contain + custom maximize with rcWork (completed 2026-05-30)
  - [ ] 07-01-PLAN.md — Integration tests: FFI guard refactor, FakeWindowService, E2E playback/controls/playlist flows
  - [ ] 07-02-PLAN.md — Golden tests: custom comparator, glass widget snapshots, control layout snapshots
- [ ] **Phase 8: Architecture & Dead Code** — Context7-guided optimization + cleanup (QUAL-01, QUAL-02, QUAL-03)

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|---------------|--------|-----------|
| 1. Window Management | v1.0 | 4/4 | Complete | 2026-05-28 |
| 2. Widget Unification | v1.0 | 2/2 | Complete | 2026-05-28 |
| 3. Performance Optimization | v1.0 | 4/4 | Complete | 2026-05-28 |
| 4. Test Coverage | v1.0 | 1/1 | Complete | 2026-05-29 |
| 5. Technical Debt Cleanup | v1.0 | 3 waves | Complete | 2026-05-29 |
| 6. Window Code Optimization | v1.1 | 1/1 | Complete | 2026-05-29 |
| 7. Integration & Golden Tests | v1.1 | 1/3 | Planning | — |
| 8. Architecture & Dead Code | v1.1 | 0/? | Not started | — |

## Requirement Traceability

| Requirement | Phase | Plan |
|-------------|-------|------|
| OPT-01 | 6 | 06-01 |
| OPT-02 | 7 | 07-03 |
| TEST-05 | 7 | 07-01 |
| TEST-06 | 7 | 07-02 |
| QUAL-01 | 8 | TBD |
| QUAL-02 | 8 | TBD |
| QUAL-03 | 8 | TBD |

---
*Last updated: 2026-05-29 — Phase 7 planned*
