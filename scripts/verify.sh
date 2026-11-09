#!/usr/bin/env bash
# 一键本地验证：format → analyze → test（与 CI 的 analyze/test 门禁对齐）。
# One-shot local gate: any failing step aborts with a non-zero exit code.
#
# 用法 / Usage:
#   scripts/verify.sh            # 全量
#   scripts/verify.sh test/ui    # 仅跑指定测试路径（format/analyze 仍全量）
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> dart format --set-exit-if-changed lib test"
dart format --set-exit-if-changed lib test

echo "==> flutter analyze --fatal-infos"
flutter analyze --no-pub --fatal-infos

echo "==> flutter test ${*:-(all)}"
# --timeout 90s 与 CI 一致；时序类用例在高负载下可能抖动，失败后先单文件复跑再判断。
flutter test --no-pub --timeout 90s "$@"
