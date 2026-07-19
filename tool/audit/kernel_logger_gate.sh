#!/usr/bin/env bash
# tool/audit/kernel_logger_gate.sh
#
# LOG-01 / LOG-04 静态结构闸门脚本 (Phase 17, Plan 02)。
#
# 两个闸门 — Two structural gates:
#   GATE 1 (LOG-01): lib/kernel/** 零 package:logger 导入。
#     唯一允许导入 package:logger 的是 lib/kernel/utils/log.dart 本身（应用层日志保留）。
#   GATE 2 (LOG-04): lib/kernel/** 零 utils/log.dart 导入。
#     迁移完成后，只有 lib/kernel/ 外的文件（app.dart, main.dart 等）才导入 utils/log.dart。
#
# 设计原则（沿用 phase16_gates.sh / inventory.sh）：
#   - 只读 + stdout，无文件写入、无网络、无输入面。
#   - rg/grep 兼容层：优先 ripgrep，降级到 GNU grep。
#   - CI 可自动化：exit 0 = pass, exit 1 = fail，可诊断证据行。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
KERNEL_DIR="$REPO_ROOT/lib/kernel"

# rg / grep 兼容层
if command -v rg >/dev/null 2>&1; then
  SEARCH_CMD="rg"
else
  SEARCH_CMD="grep"
fi

# 搜索 lib/kernel/ 中的匹配行，排除指定文件
# Usage: search_kernel <pattern> [exclude_file]
search_kernel() {
  local pattern="$1"
  local exclude_file="${2:-}"
  if [ "$SEARCH_CMD" = "rg" ]; then
    if [ -n "$exclude_file" ]; then
      rg -n "$pattern" --type dart "$KERNEL_DIR" -g "!**/${exclude_file}" || true
    else
      rg -n "$pattern" --type dart "$KERNEL_DIR" || true
    fi
  else
    if [ -n "$exclude_file" ]; then
      grep -rn "$pattern" --include='*.dart' "$KERNEL_DIR" | grep -v "/${exclude_file}:" || true
    else
      grep -rn "$pattern" --include='*.dart' "$KERNEL_DIR" || true
    fi
  fi
}

# ---------------------------------------------------------------------------
# GATE 1 — LOG-01: zero package:logger imports in lib/kernel/
# (excluding lib/kernel/utils/log.dart which is allowed)
# ---------------------------------------------------------------------------
gate1_package_logger() {
  local hits
  hits=$(search_kernel "import.*package:logger" "utils/log.dart")

  if [ -n "$hits" ]; then
    echo "GATE 1 FAIL (LOG-01): 'import.*package:logger' found in lib/kernel/ (excluding utils/log.dart):"
    printf '%s\n' "$hits"
    return 1
  fi

  echo "GATE 1 PASS (LOG-01): zero 'package:logger' imports in lib/kernel/ (utils/log.dart excluded)."
  return 0
}

# ---------------------------------------------------------------------------
# GATE 2 — LOG-04: zero utils/log.dart imports in lib/kernel/
# (all files should now import diagnostics/kernel_logger.dart instead)
# ---------------------------------------------------------------------------
gate2_utils_log_dart() {
  local hits
  hits=$(search_kernel "import.*utils/log\\.dart")

  if [ -n "$hits" ]; then
    echo "GATE 2 FAIL (LOG-04): 'import.*utils/log.dart' found in lib/kernel/:"
    printf '%s\n' "$hits"
    return 1
  fi

  # Also check relative 'log.dart' imports in utils/ (the 3 files that used import 'log.dart')
  local relative_hits
  if [ "$SEARCH_CMD" = "rg" ]; then
    relative_hits=$(rg -n "import 'log\\.dart'" --type dart "$KERNEL_DIR/utils/" || true)
  else
    relative_hits=$(grep -rn "import 'log\\.dart'" --include='*.dart' "$KERNEL_DIR/utils/" || true)
  fi

  if [ -n "$relative_hits" ]; then
    echo "GATE 2 FAIL (LOG-04): relative 'import log.dart' found in lib/kernel/utils/:"
    printf '%s\n' "$relative_hits"
    return 1
  fi

  echo "GATE 2 PASS (LOG-04): zero 'utils/log.dart' imports in lib/kernel/."
  return 0
}

main() {
  local exit_code=0

  gate1_package_logger || exit_code=1
  echo ""
  gate2_utils_log_dart || exit_code=1

  return "$exit_code"
}

main "$@"
