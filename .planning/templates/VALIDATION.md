---
status: pass|fail
wave: {wave_number}
agent: flutter-integration-validator
depth: quick
timestamp: {timestamp}
---

# Wave Validation — Quick Check

## Automated Checks

| Check | Status | Details |
|-------|--------|---------|
| flutter analyze | PASS/FAIL | {error_count} errors |
| flutter test | PASS/FAIL | {pass_count}/{total_count} tests passing |

## Gate Decision

<!--
- PASS: 继续下一 wave
- FAIL: 阻塞，等待修复
-->

Status: {status}
Decision: {gate_decision}

## Failure Details (if any)

<!-- 只有 status 为 fail 时才填写此节 -->

### Failed Tests
- {test_name}: {error_message}

### Analyze Errors
- {file}:{line}: {error_message}

## Summary

- Wave: {wave_number}
- Depth: quick (只检查 errors + test failures)
- Result: {result}

<!--
模板说明:
- status: pass (全部通过) | fail (有阻塞错误)
- depth 固定为 quick: 只检查 flutter analyze errors + flutter test failures
- 不运行 dart format/dart fix/coverage
- Gate 决策: pass → 继续, fail → 阻塞等待修复
- 输出由 flutter-integration-validator agent 在 execute:wave:post 阶段自动生成
-->
