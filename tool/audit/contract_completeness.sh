#!/usr/bin/env bash
# tool/audit/contract_completeness.sh
#
# BASE-01 契约完整性检查脚本（支撑 Plan 02 验收，RESEARCH Pitfall 3/5,
# Recommendations 2/7）。
#
# 设计原则：
#   - 对 lib/kernel/engine/ 下 7 个 ISP 接口文件动态提取每个公开成员
#     （getter / 方法声明）签名 —— 绝不依赖任何文档里写死的成员计数
#     （例如 CONTEXT.md 曾写 EngineStateView "12 个" getter，但 LIVE 代码
#     实际是 13 个 ValueNotifier getter + mediaInfo + dispose = 15 个成员，
#     见 15-RESEARCH.md Pitfall 3）。
#   - 计数/提取逻辑（count_* 函数）与格式化/输出逻辑（format_*/main）
#     严格分离，与 inventory.sh 同构，复用同一套设计哲学（D21/D23）。
#   - 只校验"契约标签是否存在"，不校验"标签值是否正确"（例如 states:
#     标签的值与 EngineStateMachine 转换表的交叉校验属 Plan 03 契约
#     测试职责，本脚本不做）。
#   - Wave 0 阶段（Plan 02 尚未撰写契约）运行本脚本，预期 6 个控制类接口
#     会报告"成员缺失契约标签"——这是预期结果，不是脚本 bug。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENGINE_DIR="$REPO_ROOT/lib/kernel/engine"

# media_engine.dart 的 implements 子句列出的全部 7 个接口文件——
# EngineStateView（状态视图）+ 6 个能力接口（含此前 D14 枚举遗漏的
# VolumeControl，见 RESEARCH Pitfall 4 / Open Question 2）。
# 硬编码这个文件名列表是可接受的（不是"计数硬编码"）：这 7 个文件名
# 本身就是 media_engine.dart implements 子句的直接抄录，若接口集合本身
# 变化，脚本理应随之更新——这与"审计目标的具体数字不能硬编码"是两件事。
INTERFACE_FILES=(
  "engine_state_view.dart"
  "playback_control.dart"
  "track_control.dart"
  "subtitle_config.dart"
  "video_effect_control.dart"
  "renderer_control.dart"
  "volume_control.dart"
)

# rg / grep -P 兼容层（与 inventory.sh 同构，独立维护一份避免脚本间耦合）
if command -v rg >/dev/null 2>&1; then
  AUDIT_BACKEND="rg"
else
  AUDIT_BACKEND="grep"
fi

# ---------------------------------------------------------------------------
# 成员签名提取（纯逻辑，无 print/exit）
# ---------------------------------------------------------------------------

# 从单个接口文件动态提取"公开成员声明行"的行号列表。
# 匹配对象：
#   - getter 声明：形如 `  Xxx get name;` 或 `  ValueNotifier<T> get name;`
#   - 方法声明：形如 `  ReturnType methodName(...);` 或 `  void methodName(...)`
#   - 排除：私有成员（下划线开头）、import 行、class 声明行本身、注释行
# 用简单的行首缩进 + 类型签名模式识别，不需要完整 Dart AST 解析——
# 接口文件本身结构简单（无内部实现体，全是签名 + 分号结尾），正则足够可靠。
_extract_member_lines() {
  local file="$1"
  local pattern='^[[:space:]]+([A-Za-z_][A-Za-z0-9_<>?, ]*[[:space:]]+get[[:space:]]+[a-zA-Z][a-zA-Z0-9]*;|[A-Za-z_][A-Za-z0-9_<>?,\[\] ]*[[:space:]]+[a-zA-Z][a-zA-Z0-9]*\([^;]*\)[[:space:]]*;)'
  if [ "$AUDIT_BACKEND" = "rg" ]; then
    rg -n -P "$pattern" "$file" || true
  else
    grep -nP "$pattern" "$file" || true
  fi
}

# 提取成员名（去掉签名噪音，只留标识符，用于展示 missing 清单）
_member_name_from_line() {
  local line_text="$1"
  # getter: "... get name;" -> name
  # method: "... name(...);" -> name
  if echo "$line_text" | command grep -qP 'get[[:space:]]+[a-zA-Z][a-zA-Z0-9]*;$'; then
    echo "$line_text" | command grep -oP 'get[[:space:]]+\K[a-zA-Z][a-zA-Z0-9]*(?=;$)'
  else
    echo "$line_text" | command grep -oP '\b[a-zA-Z][a-zA-Z0-9]*(?=\()' | tail -1
  fi
}

# 检查某一行号上方最近的 /// 文档块是否含至少一个 D2 契约标签行，
# 或该文件顶部（接口类声明前）存在组契约块含契约标签（D3 组契约模式，
# 适用于 EngineStateView 这类"每个 getter 一行意图 + 接口顶部共享契约"的场景）。
_has_contract_tag_above() {
  local file="$1" line_no="$2"
  local tag_pattern='^[[:space:]]*///[[:space:]]*(requires|ensures|states|modifies|throws):'
  # 向上最多回溯 15 行查找 /// 契约标签（覆盖单个成员的多行 doc block）
  local start=$((line_no - 15))
  [ "$start" -lt 1 ] && start=1
  local window
  window=$(sed -n "${start},${line_no}p" "$file")
  if echo "$window" | command grep -qP "$tag_pattern"; then
    return 0
  fi
  return 1
}

# 检查接口文件顶部（class 声明之前）是否存在组契约块（D3）——
# 至少含一个契约标签，视为该接口下所有只读 getter 共享的组级契约。
_has_class_level_group_contract() {
  local file="$1"
  local class_line
  class_line=$(command grep -n '^abstract class' "$file" | head -1 | cut -d: -f1)
  [ -z "$class_line" ] && return 1
  local header
  header=$(sed -n "1,${class_line}p" "$file")
  local tag_pattern='^[[:space:]]*///[[:space:]]*(requires|ensures|states|modifies|throws):'
  echo "$header" | command grep -qP "$tag_pattern"
}

# 对单个接口文件统计：成员总数、已有契约标签的成员数、缺失清单
# 结果写入全局变量（供 format 函数读取），命名前缀带文件名避免冲突
count_contract_completeness_for_file() {
  local file_path="$1" file_name="$2"
  local lines
  lines=$(_extract_member_lines "$file_path")

  local total=0
  local with_tag=0
  local missing_list=""
  local has_group_contract=0
  if _has_class_level_group_contract "$file_path"; then
    has_group_contract=1
  fi

  if [ -n "$lines" ]; then
    while IFS= read -r entry; do
      [ -z "$entry" ] && continue
      local line_no line_text member_name
      line_no=$(echo "$entry" | cut -d: -f1)
      line_text=$(echo "$entry" | cut -d: -f2-)
      member_name=$(_member_name_from_line "$line_text")
      [ -z "$member_name" ] && member_name="<unnamed:${line_no}>"

      total=$((total + 1))
      if _has_contract_tag_above "$file_path" "$line_no"; then
        with_tag=$((with_tag + 1))
      elif [ "$has_group_contract" -eq 1 ]; then
        # D3 组契约：整个接口共享一份类级契约，各 getter 自身可以只有
        # 一行中文意图而不重复契约标签 —— 视为"已覆盖"，不计入缺失。
        with_tag=$((with_tag + 1))
      else
        if [ -z "$missing_list" ]; then
          missing_list="${member_name}:${line_no}"
        else
          missing_list="${missing_list}
${member_name}:${line_no}"
        fi
      fi
    done <<< "$lines"
  fi

  # dispose() 在 EngineStateView 中是显式方法声明，_extract_member_lines
  # 的方法模式已覆盖（形如 `void dispose();`），不需要额外特判。

  local var_prefix
  var_prefix=$(echo "$file_name" | tr '.' '_' | tr '-' '_')
  eval "CC_TOTAL_${var_prefix}=${total}"
  eval "CC_WITH_TAG_${var_prefix}=${with_tag}"
  eval "CC_MISSING_${var_prefix}=\$(printf '%s' \"\$missing_list\")"
  eval "CC_GROUP_CONTRACT_${var_prefix}=${has_group_contract}"
}

# ---------------------------------------------------------------------------
# main：遍历 7 个接口文件，逐一统计，打印结果，决定退出码
# ---------------------------------------------------------------------------
main() {
  local any_missing=0
  local total_files=0

  echo "=== Phase 15 Contract Completeness Audit ==="
  echo "(Wave 0: script built before Plan 02 writes contracts — missing"
  echo " tags on the 6 control interfaces below is EXPECTED at this stage)"
  echo

  for file_name in "${INTERFACE_FILES[@]}"; do
    local file_path="$ENGINE_DIR/$file_name"
    if [ ! -f "$file_path" ]; then
      echo "ERROR: interface file not found: $file_path" >&2
      any_missing=1
      continue
    fi
    total_files=$((total_files + 1))
    count_contract_completeness_for_file "$file_path" "$file_name"

    local var_prefix
    var_prefix=$(echo "$file_name" | tr '.' '_' | tr '-' '_')
    local total with_tag missing_list group_contract
    eval "total=\$CC_TOTAL_${var_prefix}"
    eval "with_tag=\$CC_WITH_TAG_${var_prefix}"
    eval "missing_list=\$CC_MISSING_${var_prefix}"
    eval "group_contract=\$CC_GROUP_CONTRACT_${var_prefix}"

    echo "--- $file_name ---"
    echo "  Members: $total | With contract tag: $with_tag | Group contract at class level: $([ "$group_contract" -eq 1 ] && echo yes || echo no)"
    if [ -n "$missing_list" ]; then
      any_missing=1
      echo "  Missing contract tags:"
      printf '%s\n' "$missing_list" | sed 's/^/    - /'
    else
      echo "  All members have contract coverage."
    fi
    echo
  done

  echo "=== Summary ==="
  echo "Interface files scanned: $total_files / ${#INTERFACE_FILES[@]}"
  if [ "$any_missing" -eq 1 ]; then
    echo "Status: INCOMPLETE (expected pre-Plan-02; re-run after contract docs are written)"
    exit 1
  else
    echo "Status: COMPLETE — every member across all 7 ISP interfaces has a contract tag"
    exit 0
  fi
}

main "$@"
