#!/usr/bin/env bash
# tool/audit/rollback.sh
#
# 紧急回退脚本 — 将 DelegationPolicy 翻回 all-legacy (Phase 21, D16/D19)。
#
# 触发条件 (D17): 无法播放、崩溃、音画不同步等用户可感知的播放故障。
# 回退范围 (D18): 引擎 + 诊断组件，不涉及 UI/设置/播放列表。
#
# 使用方法:
#   bash tool/audit/rollback.sh          # 执行翻回
#   bash tool/audit/rollback.sh --dry-run # 预览 diff，不修改文件
#
# 翻回后请运行 `flutter test` 验证全绿，然后提交变更。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PLAYER_SERVICES="$REPO_ROOT/lib/kernel/player_services.dart"

DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
  esac
done

echo "=== Emergency Rollback Script (D16/D19) ==="
echo "Target: $PLAYER_SERVICES"
echo ""

if [ ! -f "$PLAYER_SERVICES" ]; then
  echo "ERROR: player_services.dart not found at $PLAYER_SERVICES"
  exit 1
fi

# 备份原文件
BACKUP="${PLAYER_SERVICES}.bak"
cp "$PLAYER_SERVICES" "$BACKUP"

# 策略 1: 替换 DelegationPolicy.all(KernelMode.migrated) → DelegationPolicy.all(KernelMode.legacy)
sed -i 's/DelegationPolicy\.all(KernelMode\.migrated)/DelegationPolicy.all(KernelMode.legacy)/g' "$PLAYER_SERVICES"

# 策略 2: 替换显式 migrated 字段 → legacy
# 匹配形如 `fieldName: KernelMode.migrated` 的模式
sed -i 's/\(stateView:\s*\)KernelMode\.migrated/\1KernelMode.legacy/g' "$PLAYER_SERVICES"
sed -i 's/\(playback:\s*\)KernelMode\.migrated/\1KernelMode.legacy/g' "$PLAYER_SERVICES"
sed -i 's/\(track:\s*\)KernelMode\.migrated/\1KernelMode.legacy/g' "$PLAYER_SERVICES"
sed -i 's/\(subtitle:\s*\)KernelMode\.migrated/\1KernelMode.legacy/g' "$PLAYER_SERVICES"
sed -i 's/\(videoEffect:\s*\)KernelMode\.migrated/\1KernelMode.legacy/g' "$PLAYER_SERVICES"
sed -i 's/\(renderer:\s*\)KernelMode\.migrated/\1KernelMode.legacy/g' "$PLAYER_SERVICES"
sed -i 's/\(volume:\s*\)KernelMode\.migrated/\1KernelMode.legacy/g' "$PLAYER_SERVICES"

# 检查是否实际发生了变化
if diff -q "$PLAYER_SERVICES" "$BACKUP" > /dev/null 2>&1; then
  echo "No changes needed — DelegationPolicy already set to all-legacy."
  rm -f "$BACKUP"
  exit 0
fi

echo "=== Diff (before → after rollback) ==="
diff --color=never "$BACKUP" "$PLAYER_SERVICES" || true
echo ""

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[--dry-run] Restoring original file (no changes applied)."
  mv "$BACKUP" "$PLAYER_SERVICES"
  exit 0
fi

rm -f "$BACKUP"

echo "=== Rollback Complete ==="
echo "DelegationPolicy has been rolled back to all-legacy."
echo ""
echo "Next steps:"
echo "  1. Run: flutter test"
echo "  2. Verify all tests pass"
echo "  3. Commit: git add lib/kernel/player_services.dart && git commit -m 'fix: emergency rollback — DelegationPolicy to all-legacy'"
