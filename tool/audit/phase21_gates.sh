#!/usr/bin/env bash
# tool/audit/phase21_gates.sh
#
# 适配层删除闸门脚本 — 4 项硬性检查 (Phase 21, D9/D12)。
#
# 四个闸门 — Four adapter deletion gates:
#   GATE 1 (D9): 100% 调用方已迁移 — DelegationPolicy 全部 7 个 per-capability
#     字段均为 KernelMode.migrated (非 legacy)。
#   GATE 2 (D9): 双轨回归全绿 — dual_track_regression_test 通过。
#   GATE 3 (D9): 守卫已移入新引擎 — OpenGenerationTracker 在 engine 层存在,
#     且 kernel_adapter.dart 中无 _openGeneration 字段。
#   GATE 4 (D9): 回退路径已审计 — rollback.sh 存在且可执行, ROLLBACK.md 存在。
#
# 设计原则（沿用 phase16_gates.sh 模式）：
#   - 基线 LIVE 读取，绝不硬编码 — 硬编码值会漂移且掩盖漂移。
#   - 可重跑、CI 可自动化、违规时非零退出并打印可诊断的证据行。
#   - 只读 + stdout，无文件写入、无网络、无输入面。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PLAYER_SERVICES="$REPO_ROOT/lib/kernel/player_services.dart"
ENGINE_DIR="$REPO_ROOT/lib/kernel/engine"
ADAPTER_FILE="$REPO_ROOT/lib/kernel/adapter/kernel_adapter.dart"
ROLLBACK_SCRIPT="$REPO_ROOT/tool/audit/rollback.sh"
ROLLBACK_DOC="$REPO_ROOT/docs/ROLLBACK.md"
DUAL_TRACK_TEST="$REPO_ROOT/test/regression/dual_track_regression_test.dart"

STDOUT_MODE=0
for arg in "$@"; do
  case "$arg" in
    --stdout) STDOUT_MODE=1 ;;
  esac
done

# ---------------------------------------------------------------------------
# GATE 1 — D9: DelegationPolicy 全部 7 个 per-capability 字段均为 migrated
# ---------------------------------------------------------------------------
gate1_all_migrated() {
  local gate1_failed=0

  # 检查 player_services.dart 中 DelegationPolicy 构造是否使用 all-migrated。
  # 两种合法模式:
  #   (a) DelegationPolicy.all(KernelMode.migrated)
  #   (b) 显式 7 个字段全为 KernelMode.migrated
  #
  # 先检查 (a): 是否有 .all(KernelMode.migrated)
  if grep -q 'DelegationPolicy\.all(KernelMode\.migrated)' "$PLAYER_SERVICES"; then
    echo "GATE 1 PASS (D9): PlayerServices uses DelegationPolicy.all(KernelMode.migrated)."
    return 0
  fi

  # (b) 显式构造: 检查 7 个字段是否全为 KernelMode.migrated
  local fields=("stateView" "playback" "track" "subtitle" "videoEffect" "renderer" "volume")
  local all_migrated=1

  for field in "${fields[@]}"; do
    # 搜索形如 `fieldName: KernelMode.migrated` 的行
    if ! grep -qE "${field}:\s*KernelMode\.migrated" "$PLAYER_SERVICES"; then
      all_migrated=0
      echo "  FAIL: field '$field' is NOT set to KernelMode.migrated"
    fi
  done

  if [ "$all_migrated" -eq 1 ]; then
    echo "GATE 1 PASS (D9): All 7 DelegationPolicy fields set to KernelMode.migrated."
    return 0
  fi

  echo "GATE 1 FAIL (D9): DelegationPolicy not fully migrated — see above for non-migrated fields."
  return 1
}

# ---------------------------------------------------------------------------
# GATE 2 — D9: 双轨回归全绿
# ---------------------------------------------------------------------------
gate2_dual_track_regression() {
  if [ ! -f "$DUAL_TRACK_TEST" ]; then
    echo "GATE 2 FAIL (D9): dual_track_regression_test.dart not found at $DUAL_TRACK_TEST"
    return 1
  fi

  echo "  Running: flutter test test/regression/dual_track_regression_test.dart"
  local test_output
  if test_output=$(cd "$REPO_ROOT" && flutter test test/regression/dual_track_regression_test.dart 2>&1); then
    echo "GATE 2 PASS (D9): dual_track_regression_test all green."
    echo "  (last 3 lines):"
    echo "$test_output" | tail -3 | sed 's/^/    /'
    return 0
  else
    echo "GATE 2 FAIL (D9): dual_track_regression_test failed."
    echo "  (last 10 lines):"
    echo "$test_output" | tail -10 | sed 's/^/    /'
    return 1
  fi
}

# ---------------------------------------------------------------------------
# GATE 3 — D9: 守卫已移入新引擎 (OpenGenerationTracker 在 engine 层存在,
#            kernel_adapter.dart 中无 _openGeneration 字段)
# ---------------------------------------------------------------------------
gate3_guard_migrated() {
  local gate3_failed=0

  # (a) OpenGenerationTracker / _openGeneration 必须在 engine 层存在
  #     (engine_state_machine.dart 是 FvpEngine 的状态机组件)
  local engine_hits
  engine_hits=$(grep -rn '_openGeneration\|OpenGenerationTracker' "$ENGINE_DIR" || true)
  if [ -z "$engine_hits" ]; then
    echo "GATE 3 FAIL (D9a): '_openGeneration' / 'OpenGenerationTracker' NOT found in engine layer."
    echo "  Expected in: lib/kernel/engine/engine_state_machine.dart"
    gate3_failed=1
  else
    echo "  (engine layer hits):"
    printf '%s\n' "$engine_hits" | sed 's/^/    /'
  fi

  # (b) kernel_adapter.dart 中不能有 _openGeneration 字段/引用
  local adapter_hits
  adapter_hits=$(grep -n '_openGeneration' "$ADAPTER_FILE" || true)
  if [ -n "$adapter_hits" ]; then
    echo "GATE 3 FAIL (D9b): '_openGeneration' found in kernel_adapter.dart — guard not fully migrated:"
    printf '%s\n' "$adapter_hits" | sed 's/^/    /'
    gate3_failed=1
  fi

  if [ "$gate3_failed" -eq 1 ]; then
    return 1
  fi

  echo "GATE 3 PASS (D9): OpenGenerationTracker in engine layer; no '_openGeneration' in adapter."
  return 0
}

# ---------------------------------------------------------------------------
# GATE 4 — D9: 回退路径已审计 (rollback.sh + ROLLBACK.md 存在)
# ---------------------------------------------------------------------------
gate4_rollback_path() {
  local gate4_failed=0

  if [ ! -f "$ROLLBACK_SCRIPT" ]; then
    echo "GATE 4 FAIL (D9a): rollback.sh not found at $ROLLBACK_SCRIPT"
    gate4_failed=1
  elif [ ! -x "$ROLLBACK_SCRIPT" ]; then
    echo "GATE 4 FAIL (D9a): rollback.sh exists but is NOT executable: $ROLLBACK_SCRIPT"
    gate4_failed=1
  else
    echo "  rollback.sh: EXISTS + executable"
  fi

  if [ ! -f "$ROLLBACK_DOC" ]; then
    echo "GATE 4 FAIL (D9b): ROLLBACK.md not found at $ROLLBACK_DOC"
    gate4_failed=1
  else
    echo "  ROLLBACK.md: EXISTS"
  fi

  if [ "$gate4_failed" -eq 1 ]; then
    return 1
  fi

  echo "GATE 4 PASS (D9): rollback.sh exists+executable, ROLLBACK.md exists."
  return 0
}

main() {
  local exit_code=0

  gate1_all_migrated || exit_code=1
  echo ""
  gate2_dual_track_regression || exit_code=1
  echo ""
  gate3_guard_migrated || exit_code=1
  echo ""
  gate4_rollback_path || exit_code=1

  echo ""
  if [ "$exit_code" -eq 0 ]; then
    echo "=== ALL 4 GATES PASSED ==="
  else
    echo "=== SOME GATES FAILED (exit code $exit_code) ==="
  fi

  return "$exit_code"
}

main "$@"
