---
status: clean|warning|blocked
plan: {plan_id}
agent: flutter-architecture
timestamp: {timestamp}
---

# Architecture Review — Plan {plan_id}

## Checks

| Check | Status | Details |
|-------|--------|---------|
| Layer boundary | PASS/FAIL | kernel/ → ui/ imports: {count} |
| Dependency direction | PASS/FAIL | All imports follow correct direction |
| State pattern | PASS/FAIL | ValueNotifier used correctly |

## Issues (if any)

<!-- 只有 status 为 warning 或 blocked 时才填写此节 -->

### {SEVERITY}: {file}:{line}

{description}

Suggestion: {suggestion}

## Summary

- Total checks: 3
- Passed: {passed}
- Failed: {failed}
- Status: {status}

<!--
模板说明:
- status: clean (全部通过) | warning (有非阻塞问题) | blocked (有阻塞问题)
- 检查项限制为 3 项: 层级边界、依赖方向、状态管理模式
- 不做代码质量/性能/安全检查（那是其他 agent 的职责）
- 输出由 flutter-architecture agent 自动生成
-->
