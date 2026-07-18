#!/usr/bin/env bash
# tool/audit/phase16_gates.sh
#
# ADAPT-04/ADAPT-05 静态结构闸门脚本 (Phase 16, D22/D27)。
#
# 两个闸门 — Two structural gates:
#   GATE 1 (D22): KernelAdapter 无双数据源 — no dual openGeneration data source.
#     D20 裁定 P16 适配器是透明转发层: NO counter field, NO generation code,
#     open() 100% forward 到 legacy (openGeneration 守卫完整驻留于旧引擎
#     fvp_engine.dart:259/267/311/320)。计数器迁移到适配器是 P20 任务
#     (STATE-02)，目前仅作为 D21 类级 doc-comment checklist 里的前瞻占位。
#   GATE 2 (D27): 6 个生产文件 (1 adapter + 5 diagnostics) 总行数 < FvpEngine
#     636 行基线 (D27 尺寸预算, ADAPT-05)。
#
# 设计原则（沿用 inventory.sh / D21/D23 精神）：
#   - 基线 (636) 与总行数 LIVE 读取，绝不硬编码 —— 硬编码值会漂移且掩盖漂移
#     (inventory.sh 设计原则)。
#   - 与 LOG-01 grep-gate 惯例一致：可重跑、CI 可自动化、违规时非零退出并
#     打印可诊断的证据行（不是笼统的失败信息）。
#   - 只读 + stdout，无文件写入、无网络、无输入面 —— 审计工具本身零信任边界
#     (见 16-05-PLAN.md threat_model)。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ADAPTER_DIR="$REPO_ROOT/lib/kernel/adapter"
DIAGNOSTICS_DIR="$REPO_ROOT/lib/kernel/diagnostics"
BASELINE_FILE="$REPO_ROOT/lib/kernel/engine/fvp_engine.dart"

# --stdout 与 inventory.sh 保持一致：仅打印结果，无副作用（本脚本本身就
# 无文件写入，此 flag 是为了接口一致性/未来 CI 集成时行为可预期）。
STDOUT_MODE=0
for arg in "$@"; do
  case "$arg" in
    --stdout) STDOUT_MODE=1 ;;
  esac
done

# D26 20% 偏差升级阈值：预算中位数 ~480 的 20% = 96，触发线取整为 575
# (~480 + 96 ≈ 576，PLAN 文档写明 "> 575" 作为触发点，此处直接沿用避免二次推导漂移)。
WARNING_THRESHOLD=575

# ---------------------------------------------------------------------------
# GATE 1 — D22: no double openGeneration data source in the adapter
# ---------------------------------------------------------------------------
gate1_open_generation() {
  local gate1_failed=0

  # (a) 下划线前缀的计数器标识符必须 0 命中 —— 任何命中即适配器偷偷加了
  #     计数器字段/引用，直接违反 D20/D22。
  local underscore_hits
  underscore_hits=$(grep -rn '_openGeneration' "$ADAPTER_DIR" || true)
  if [ -n "$underscore_hits" ]; then
    echo "GATE 1 FAIL (D22a): '_openGeneration' found in adapter — counter field/reference smuggled in:"
    printf '%s\n' "$underscore_hits"
    gate1_failed=1
  fi

  # (b) 无下划线的 'openGeneration' 只允许出现在 /// doc comment 行里
  #     （D21 类级迁移 checklist）。任何出现在字段/方法体/import 里的匹配
  #     都是违规。这里用 grep -n 拿到 file:line:content，逐行判断该行
  #     "去除前导空白后" 是否以 /// 开头。
  local matches
  matches=$(grep -rn 'openGeneration' "$ADAPTER_DIR" || true)
  local non_doc_comment_lines=""
  if [ -n "$matches" ]; then
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      # 取出 file:line:content 中 content 部分（第三个及之后的字段，保留冒号）
      local content="${line#*:*:}"
      # 去除前导空白后判断是否以 /// 开头
      local trimmed="${content#"${content%%[![:space:]]*}"}"
      case "$trimmed" in
        '///'*) ;; # doc comment 行，合法
        *) non_doc_comment_lines="${non_doc_comment_lines}${line}"$'\n' ;;
      esac
    done <<< "$matches"
  fi

  if [ -n "$non_doc_comment_lines" ]; then
    echo "GATE 1 FAIL (D22b): 'openGeneration' found outside /// doc comment in adapter — non-doc-comment reference is a D20/D22 violation:"
    printf '%s' "$non_doc_comment_lines"
    gate1_failed=1
  fi

  if [ "$gate1_failed" -eq 1 ]; then
    return 1
  fi

  echo "GATE 1 PASS (D22): 0 '_openGeneration' hits; all 'openGeneration' matches are inside /// doc comments."
  if [ -n "$matches" ]; then
    echo "  (doc-comment matches, for auditability):"
    printf '%s\n' "$matches" | sed 's/^/    /'
  fi
  return 0
}

# ---------------------------------------------------------------------------
# GATE 2 — D27: size budget (6 production files < live-read FvpEngine baseline)
# ---------------------------------------------------------------------------
gate2_size_budget() {
  local baseline
  baseline=$(wc -l < "$BASELINE_FILE" | tr -d ' ')

  local total=0
  local breakdown=""
  local file
  # 逐文件 wc -l 相加，同时保留明细供 ADAPT-05 审计打印（含注释/空行，D27）。
  for file in "$ADAPTER_DIR"/*.dart "$DIAGNOSTICS_DIR"/*.dart; do
    [ -f "$file" ] || continue
    local lines
    lines=$(wc -l < "$file" | tr -d ' ')
    total=$((total + lines))
    breakdown="${breakdown}    ${lines}\t${file#$REPO_ROOT/}\n"
  done

  echo "GATE 2 (D27) per-file breakdown:"
  printf '%b' "$breakdown"
  echo "  Total: $total lines. Baseline (live wc -l fvp_engine.dart): $baseline lines."

  if [ "$total" -ge "$baseline" ]; then
    echo "GATE 2 FAIL (D27): total ($total) >= baseline ($baseline) — size budget exceeded."
    return 1
  fi

  if [ "$total" -gt "$WARNING_THRESHOLD" ]; then
    echo "WARNING (D26 escalation): total ($total) exceeds the 20%-deviation threshold ($WARNING_THRESHOLD) vs the ~480 estimate — still under the $baseline ceiling, but recommend a senior-architect/red-team re-challenge (D26/D27 escalation)."
  fi

  echo "GATE 2 PASS (D27): total ($total) < baseline ($baseline)."
  return 0
}

main() {
  local exit_code=0

  gate1_open_generation || exit_code=1
  echo ""
  gate2_size_budget || exit_code=1

  if [ "$STDOUT_MODE" -eq 1 ]; then
    : # 当前两个闸门本身就只打印到 stdout，无额外文件写入需要跳过。
  fi

  return "$exit_code"
}

main "$@"
