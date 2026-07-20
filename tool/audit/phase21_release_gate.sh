#!/usr/bin/env bash
# tool/audit/phase21_release_gate.sh
#
# Release 构建冒烟脚本 — 验证 release 产物中无 debugPrint 泄漏 (Phase 21, D15)。
#
# 流程:
#   1. flutter build windows --release
#   2. 在构建产物中 grep debugPrint/debug(.info( 字符串
#   3. 发现泄漏则 exit 1 + 打印证据
#
# 使用方法:
#   bash tool/audit/phase21_release_gate.sh
#
# 设计原则:
#   - 只读检查构建产物，无写入（除 flutter build 本身）
#   - 排除已知合法的二进制文件（.dll, .exe, .pdb 等）
#   - 检查 Dart AOT snapshot / kernel binary 中的残留字符串
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$REPO_ROOT/build/windows/x64/runner/Release"

echo "=== Phase 21 Release Gate (D15) ==="
echo ""

# Step 1: 构建 release
echo "[1/3] Building release..."
if ! (cd "$REPO_ROOT" && flutter build windows --release 2>&1); then
  echo "FAIL: flutter build windows --release failed."
  exit 1
fi
echo "  Build succeeded."

# Step 2: 检查构建产物目录是否存在
echo ""
echo "[2/3] Scanning build artifacts..."
if [ ! -d "$BUILD_DIR" ]; then
  echo "FAIL: Build output directory not found: $BUILD_DIR"
  exit 1
fi

# Step 3: 在 Dart AOT snapshot 中搜索 debugPrint 泄漏
# 排除二进制格式文件（.dll, .exe, .pdb, .ilk, .exp, .lib, .obj）
# 只检查 Dart kernel binary / AOT snapshot（.dill, .so 等文本可搜索格式）
echo ""
echo "[3/3] Checking for debugPrint/debug/info leaks in build artifacts..."

LEAK_PATTERNS="debugPrint|\.debug\(|KernelLogger\.debug|debugPrint("

# 在 Dart 源文件编译产物中搜索（.dill 文件是文本可搜索的 kernel binary）
leak_found=0
leak_evidence=""

# 搜索 .dill 文件（Dart kernel binary，含源码字符串引用）
while IFS= read -r -d '' file; do
  local_hits=$(grep -n "$LEAK_PATTERNS" "$file" 2>/dev/null || true)
  if [ -n "$local_hits" ]; then
    leak_found=1
    leak_evidence="${leak_evidence}  File: ${file#$REPO_ROOT/}\n"
    leak_evidence="${leak_evidence}${local_hits}\n\n"
  fi
done < <(find "$BUILD_DIR" -type f \( -name "*.dill" -o -name "*.dill.dill" \) -print0 2>/dev/null || true)

# 搜索 Dart AOT snapshot 中的字符串（app.so 等）
while IFS= read -r -d '' file; do
  # 对二进制文件用 strings 提取可读字符串后再 grep
  if command -v strings >/dev/null 2>&1; then
    local_hits=$(strings "$file" 2>/dev/null | grep -n "$LEAK_PATTERNS" || true)
  else
    # fallback: 直接 grep（可能输出乱码但能检测到）
    local_hits=$(grep -ao "$LEAK_PATTERNS" "$file" 2>/dev/null | head -5 || true)
  fi
  if [ -n "$local_hits" ]; then
    leak_found=1
    leak_evidence="${leak_evidence}  File: ${file#$REPO_ROOT/} (binary, strings extracted)\n"
    leak_evidence="${leak_evidence}  Matches: ${local_hits}\n\n"
  fi
done < <(find "$BUILD_DIR" -type f \( -name "app.so" -o -name "*.snapshot" \) -print0 2>/dev/null || true)

echo ""
if [ "$leak_found" -eq 1 ]; then
  echo "FAIL: debugPrint/debug leaks found in release build artifacts:"
  printf '%b' "$leak_evidence"
  exit 1
fi

echo "PASS: No debugPrint/debug leaks found in release build artifacts."
echo ""
echo "=== Release Gate PASSED ==="
