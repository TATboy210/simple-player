# Adapter API

## KernelAdapter (class)

**File:** `lib/kernel/adapter/kernel_adapter.dart`

Strangler Fig 适配器 — 临时路由层，实现 `MediaEngine` 接口。

按 `DelegationPolicy` 将约 44 个成员逐能力转发到旧引擎或新引擎。

### Constructor

```dart
KernelAdapter({
  required MediaEngine legacy,
  required MediaEngine migrated,
  required DelegationPolicy policy,
  DiagnosticsBundle bundle = const DiagnosticsBundle.noop(),
})
```

### Design

- Phase 16: `DelegationPolicy.all(KernelMode.legacy)` — 100% 路由到旧引擎
- Phase 20: 逐方法迁移 — `migratedMethods` 集合控制
- Phase 21: 删除适配器

---

## DelegationPolicy (final class)

**File:** `lib/kernel/adapter/kernel_adapter.dart`

不可变的逐能力路由策略。7 个 `KernelMode` 字段一一对应 MediaEngine 的 7 个 ISP 子接口。

### Constructor

```dart
const DelegationPolicy({
  required KernelMode stateView,
  required KernelMode playback,
  required KernelMode track,
  required KernelMode subtitle,
  required KernelMode videoEffect,
  required KernelMode renderer,
  required KernelMode volume,
  Set<String> migratedMethods = const {},
})

// All capabilities to same mode
const DelegationPolicy.all(KernelMode mode)
```

### Fields

| Field | Description |
|-------|-------------|
| `stateView` | EngineStateView 路由 |
| `playback` | PlaybackControl 路由 |
| `track` | TrackControl 路由 |
| `subtitle` | SubtitleConfig 路由 |
| `videoEffect` | VideoEffectControl 路由 |
| `renderer` | RendererControl 路由 |
| `volume` | VolumeControl 路由 |
| `migratedMethods` | 已迁移方法名集合（per-method 粒度） |

---

## KernelMode (enum)

| Value | Description |
|-------|-------------|
| `legacy` | 路由到旧引擎（FvpEngine） |
| `migrated` | 路由到新引擎 |
