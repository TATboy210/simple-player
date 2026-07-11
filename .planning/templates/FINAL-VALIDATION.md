---
status: pass|fail
depth: deep
agent: flutter-integration-validator
timestamp: {timestamp}
---

# Final Validation — Phase {phase_id}

## Automated Checks

| Check | Status | Details |
|-------|--------|---------|
| flutter analyze | PASS/FAIL | {error_count} errors, {warning_count} warnings |
| dart format | PASS/FAIL | All formatted / {file_count} files need formatting |
| dart fix | PASS/FAIL | Applied / {file_count} fixes applied |
| flutter test | PASS/FAIL | {pass_count}/{total_count} tests passing |
| Coverage | PASS/WARN | {percent}% (target: 80%) |
| Layer boundary | PASS/FAIL | No violations / {count} violations |
| Dependency direction | PASS/FAIL | All correct / {count} violations |

## Coverage Report

| Module | Coverage | Target | Status |
|--------|----------|--------|--------|
| kernel/engine/ | {percent}% | 80% | ✓/✗ |
| kernel/services/ | {percent}% | 80% | ✓/✗ |
| kernel/models/ | {percent}% | 80% | ✓/✗ |
| kernel/utils/ | {percent}% | 80% | ✓/✗ |
| ui/player/ | {percent}% | 80% | ✓/✗ |
| ui/playlist/ | {percent}% | 80% | ✓/✗ |
| ui/shared/ | {percent}% | 80% | ✓/✗ |
| ui/dialogs/ | {percent}% | 80% | ✓/✗ |

## Architecture Review

| Check | Status | Details |
|-------|--------|---------|
| Layer boundary | PASS/FAIL | kernel/ → ui/ imports: {count} |
| Dependency direction | PASS/FAIL | All imports follow correct direction |
| State pattern | PASS/FAIL | ValueNotifier used correctly |
| File size | PASS/FAIL | {count} files > 500 lines |
| Function size | PASS/FAIL | {count} functions > 50 lines |

## Gate Decision

<!--
- PASS: 所有检查通过，可以提交
- FAIL: 有阻塞错误，需要修复
- WARN: 有非阻塞问题，可以提交但建议修复
-->

Status: {status}
Decision: {gate_decision}

## Failure Details (if any)

<!-- 只有 status 为 fail 时才填写此节 -->

### Blocking Issues
- {file}:{line}: {description}

### Coverage Gaps
- {module}: {percent}% (target: 80%)

## Summary

- Depth: deep (全量验证 + 覆盖率 + 架构复查)
- Total checks: {count}
- Passed: {count}
- Failed: {count}
- Warnings: {count}
- Result: {result}

<!--
模板说明:
- status: pass (全部通过) | fail (有阻塞错误)
- depth 固定为 deep: 全量验证 + 覆盖率 + 架构复查
- 包含所有 standard 检查 + 覆盖率报告 + 架构层级边界复查
- Gate 决策: pass → 可以提交, fail → 阻塞等待修复
- 输出由 flutter-integration-validator agent 在 verify:pre 阶段自动生成
-->
