#!/usr/bin/env bash
# tool/audit/inventory.sh
#
# BASE-02 可重跑静态调用点审计脚本。
#
# 设计原则（D21/D23）：
#   - 只读 LIVE lib/ 源码，从不硬编码任何计数或文件路径 —— 历史数字
#     （121 处/30 文件）已过时（LIVE 实测 84/28），任何硬编码值都会漂移
#     且掩盖漂移（见 15-RESEARCH.md Pitfall 1）。
#   - openGeneration 用递归 glob 扫描全部 lib/，绝不假设只在某一个
#     已知文件里出现（Pitfall 2：实际分布在 fvp_engine.dart 与
#     playback_navigator.dart 两处）。
#   - 统计逻辑（count_* 函数）与格式化/输出逻辑（format_*/main）严格
#     分离，使 Phase 17 加 --enforce 阈值比较时只需在现有计数函数
#     返回值上加分支判断，不需要重写任何计数逻辑（D23 演进路径）。
#   - 可复现性：所有进入输出的 locations/文件列表数组在序列化前
#     必须先 sort，使两次运行的数组顺序稳定 —— 输出必须字节级一致
#     （除 generated_at 时间戳外）。
set -euo pipefail

SCRIPT_VERSION="1.0.0"
# 脚本自身所在目录 → 反推仓库根目录，使脚本可从任意 cwd 调用
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB_DIR="$REPO_ROOT/lib"

OUTPUT_JSON="$REPO_ROOT/.planning/phases/15-contract-freeze-baseline-audit/15-BASELINE-AUDIT.json"
OUTPUT_MD="$REPO_ROOT/.planning/phases/15-contract-freeze-baseline-audit/15-BASELINE-AUDIT.md"

STDOUT_MODE=0
for arg in "$@"; do
  case "$arg" in
    --stdout) STDOUT_MODE=1 ;;
  esac
done

# ---------------------------------------------------------------------------
# rg / grep -P 兼容层
#
# 设计说明：D21/D23 锁定的方案是 ripgrep，本机开发环境已验证 rg 14.1.1 可用
# （见 15-RESEARCH.md Environment Availability）。但部分 CI/用户终端可能只有
# GNU grep（无 rg 二进制），因此这里做一层薄的自动探测 + 降级，保证脚本在
# 两种环境下都能重跑出完全一致的计数结果（正则语义保持不变，仅切换后端）。
# ---------------------------------------------------------------------------
if command -v rg >/dev/null 2>&1; then
  AUDIT_BACKEND="rg"
else
  AUDIT_BACKEND="grep"
fi

# rg -o "<pattern>" --type dart <dir> 的等价物 —— 输出每个匹配的文本（不含文件名/行号）
# 注："零匹配"（如 logServices/logUi 前缀当前实际用量为 0）是合法结果，不是错误——
# rg/grep 在无匹配时返回非零退出码，这里用 `|| true` 吸收，避免在 `set -e` 下
# 被误判为脚本执行失败而中断整个审计。
_backend_match_only() {
  local pattern="$1" dir="$2"
  if [ "$AUDIT_BACKEND" = "rg" ]; then
    rg -o "$pattern" --type dart "$dir" || true
  else
    grep -rPo "$pattern" --include='*.dart' "$dir" || true
  fi
}

# rg -l "<pattern>" --type dart <dir> 的等价物 —— 输出命中的文件名列表
_backend_files_only() {
  local pattern="$1" dir="$2"
  if [ "$AUDIT_BACKEND" = "rg" ]; then
    rg -l "$pattern" --type dart "$dir" || true
  else
    grep -rPl "$pattern" --include='*.dart' "$dir" || true
  fi
}

# rg -n "<pattern>" --type dart <dir> -g '!<exclude_basename>' 的等价物 ——
# 输出 file:line:match，同时排除指定 basename 的文件（用于过滤
# memory_monitor.dart 自身的 doc-comment 误报）
_backend_lines_excluding() {
  local pattern="$1" dir="$2" exclude_basename="$3"
  if [ "$AUDIT_BACKEND" = "rg" ]; then
    rg -n "$pattern" --type dart "$dir" -g "!**/${exclude_basename}" || true
  else
    grep -rnP "$pattern" --include='*.dart' --exclude="$exclude_basename" "$dir" || true
  fi
}

# ---------------------------------------------------------------------------
# 计数函数（纯逻辑，无 print/exit，供 Phase 17 --enforce 复用）
# ---------------------------------------------------------------------------

# 目标 1: package:logger 风格调用点统计
# 返回：total_call_sites, total_files, 5 个前缀各自的调用次数
count_logger_usage() {
  local pattern='\b(log|logEngine|logBridge|logServices|logUi)\.(t|d|i|w|e|f|v)\('
  LOGGER_TOTAL_CALL_SITES=$(_backend_match_only "$pattern" "$LIB_DIR" | wc -l | tr -d ' ')
  LOGGER_TOTAL_FILES=$(_backend_files_only "$pattern" "$LIB_DIR" | wc -l | tr -d ' ')
  # 5 个前缀分别计数（各自独立正则，避免相互吞噬匹配）
  LOGGER_BREAKDOWN_log=$(_backend_match_only '\blog\.(t|d|i|w|e|f|v)\(' "$LIB_DIR" | wc -l | tr -d ' ')
  LOGGER_BREAKDOWN_logEngine=$(_backend_match_only '\blogEngine\.(t|d|i|w|e|f|v)\(' "$LIB_DIR" | wc -l | tr -d ' ')
  LOGGER_BREAKDOWN_logBridge=$(_backend_match_only '\blogBridge\.(t|d|i|w|e|f|v)\(' "$LIB_DIR" | wc -l | tr -d ' ')
  LOGGER_BREAKDOWN_logServices=$(_backend_match_only '\blogServices\.(t|d|i|w|e|f|v)\(' "$LIB_DIR" | wc -l | tr -d ' ')
  LOGGER_BREAKDOWN_logUi=$(_backend_match_only '\blogUi\.(t|d|i|w|e|f|v)\(' "$LIB_DIR" | wc -l | tr -d ' ')
}

# 目标 2: MemoryMonitor.start()/.snapshot() 生产调用点
# 必须排除定义文件自身（memory_monitor.dart 的 doc-comment usage 示例
# 会被朴素正则误报为"调用点"——见 15-RESEARCH.md Pitfall / PATTERNS）
count_memory_monitor_calls() {
  local pattern='MemoryMonitor\.(start|snapshot)\('
  # 排除定义文件自身，避免其内部 doc-comment 里的使用示例
  # （/// MemoryMonitor.start(...)）被算作调用点
  local raw
  raw=$(_backend_lines_excluding "$pattern" "$LIB_DIR" "memory_monitor.dart" || true)
  # 转成相对仓库根目录的 file:line，再排序，保证跨运行顺序稳定
  MEMORY_MONITOR_LOCATIONS=$(printf '%s\n' "$raw" \
    | sed -e "s#^$LIB_DIR/##" -e "s#^$LIB_DIR\\\\##" \
    | awk -F: '{print "lib/"$1":"$2}' \
    | sed 's#\\\\#/#g' \
    | grep -v '^lib/:$' \
    | sort)
  MEMORY_MONITOR_TOTAL=$(printf '%s\n' "$MEMORY_MONITOR_LOCATIONS" | grep -c . || true)
}

# 目标 3: openGeneration 全部引用 —— 递归扫描整个 lib/，不硬编码文件名
# （绝不假设只在 fvp_engine.dart，实际分布在两个文件，Pitfall 2）
count_open_generation_references() {
  local pattern='openGeneration|_openGeneration'
  local raw
  raw=$(_backend_files_only "$pattern" "$LIB_DIR" || true)
  OPEN_GENERATION_LOCATIONS=$(printf '%s\n' "$raw" \
    | sed -e "s#^$LIB_DIR/##" -e "s#^$LIB_DIR\\\\##" \
    | sed 's#\\\\#/#g' \
    | awk '{print "lib/"$0}' \
    | grep -v '^lib/$' \
    | sort)
  OPEN_GENERATION_TOTAL_FILES=$(printf '%s\n' "$OPEN_GENERATION_LOCATIONS" | grep -c . || true)
}

# ---------------------------------------------------------------------------
# 格式化函数（JSON / Markdown），只读上面计数函数写入的全局变量
# ---------------------------------------------------------------------------

# 把 sorted 的换行分隔列表转成 JSON 字符串数组（缩进 6 空格，键内数组项）
_to_json_array() {
  local list="$1"
  local indent="$2"
  if [ -z "$list" ]; then
    printf '[]'
    return
  fi
  local out="["
  local first=1
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if [ "$first" -eq 1 ]; then
      out="${out}\n${indent}  \"${line}\""
      first=0
    else
      out="${out},\n${indent}  \"${line}\""
    fi
  done <<< "$list"
  out="${out}\n${indent}]"
  printf '%b' "$out"
}

format_json() {
  local generated_at="$1"
  local mem_locations_json open_locations_json
  mem_locations_json=$(_to_json_array "$MEMORY_MONITOR_LOCATIONS" "      ")
  open_locations_json=$(_to_json_array "$OPEN_GENERATION_LOCATIONS" "      ")

  cat <<EOF
{
  "generated_at": "${generated_at}",
  "script_version": "${SCRIPT_VERSION}",
  "targets": {
    "package_logger_usage": {
      "total_call_sites": ${LOGGER_TOTAL_CALL_SITES},
      "total_files": ${LOGGER_TOTAL_FILES},
      "breakdown": {
        "log": ${LOGGER_BREAKDOWN_log},
        "logEngine": ${LOGGER_BREAKDOWN_logEngine},
        "logBridge": ${LOGGER_BREAKDOWN_logBridge},
        "logServices": ${LOGGER_BREAKDOWN_logServices},
        "logUi": ${LOGGER_BREAKDOWN_logUi}
      }
    },
    "memory_monitor_calls": {
      "total_call_sites": ${MEMORY_MONITOR_TOTAL},
      "locations": ${mem_locations_json}
    },
    "open_generation_references": {
      "total_files": ${OPEN_GENERATION_TOTAL_FILES},
      "locations": ${open_locations_json}
    }
  }
}
EOF
}

format_markdown() {
  local generated_at="$1"
  cat <<EOF
# Phase 15 Baseline Audit

> 由 \`tool/audit/inventory.sh\` 自动生成——数字来自脚本对 LIVE \`lib/\` 代码的实时扫描，
> 不是任何历史文档的转述（D21：不设第二真相源）。重新运行脚本以获取当前数字。

**Generated at:** ${generated_at}
**Script version:** ${SCRIPT_VERSION}

## package:logger 风格调用统计

| Metric | Value |
|--------|-------|
| Total call sites | ${LOGGER_TOTAL_CALL_SITES} |
| Total files | ${LOGGER_TOTAL_FILES} |

### Breakdown by prefix

| Prefix | Call sites |
|--------|-----------|
| log | ${LOGGER_BREAKDOWN_log} |
| logEngine | ${LOGGER_BREAKDOWN_logEngine} |
| logBridge | ${LOGGER_BREAKDOWN_logBridge} |
| logServices | ${LOGGER_BREAKDOWN_logServices} |
| logUi | ${LOGGER_BREAKDOWN_logUi} |

## MemoryMonitor.start()/.snapshot() 生产调用点

**Total call sites:** ${MEMORY_MONITOR_TOTAL}

$(if [ -n "$MEMORY_MONITOR_LOCATIONS" ]; then printf '%s\n' "$MEMORY_MONITOR_LOCATIONS" | sed 's/^/- /'; else echo "(none)"; fi)

## openGeneration 引用

**Total files:** ${OPEN_GENERATION_TOTAL_FILES}

$(if [ -n "$OPEN_GENERATION_LOCATIONS" ]; then printf '%s\n' "$OPEN_GENERATION_LOCATIONS" | sed 's/^/- /'; else echo "(none)"; fi)
EOF
}

# ---------------------------------------------------------------------------
# main：调度计数 → 格式化 → 写文件或 stdout
# ---------------------------------------------------------------------------
main() {
  count_logger_usage
  count_memory_monitor_calls
  count_open_generation_references

  # generated_at 用 UTC ISO-8601；--stdout 模式用于可复现性验收对比，
  # 验收脚本会 grep -v 掉这一行再 diff，所以此处正常取实时钟即可
  local generated_at
  generated_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local json_content
  json_content=$(format_json "$generated_at")

  if [ "$STDOUT_MODE" -eq 1 ]; then
    printf '%s\n' "$json_content"
    return 0
  fi

  mkdir -p "$(dirname "$OUTPUT_JSON")"
  printf '%s\n' "$json_content" > "$OUTPUT_JSON"
  format_markdown "$generated_at" > "$OUTPUT_MD"

  echo "Wrote $OUTPUT_JSON"
  echo "Wrote $OUTPUT_MD"
}

main "$@"
