---
status: clean|warning
files_reviewed: {count}
critical: {count}
warning: {count}
info: {count}
total: {count}
agents: [flutter-code-reviewer, flutter-performance, flutter-security, dart-testing, dart-architecture, dart-correctness, dart-performance, dart-security, gsd-code-fixer]
timestamp: {timestamp}
---

# Code Review — Phase {phase_id}

## Summary

| Category | Critical | Warning | Info | Total |
|----------|----------|---------|------|-------|
| Code Quality | {c} | {w} | {i} | {t} |
| Performance | {c} | {w} | {i} | {t} |
| Security | {c} | {w} | {i} | {t} |
| Dart Language | {c} | {w} | {i} | {t} |
| Testing | {c} | {w} | {i} | {t} |
| **Total** | **{c}** | **{w}** | **{i}** | **{t}** |

## Warnings

<!-- 只有 warning 数量 > 0 时才填写此节 -->

### WR-{id}: {file}:{line}
**Category:** {category}
**Severity:** WARNING
{description}
Suggestion: {suggestion}

## Info

<!-- 只有 info 数量 > 0 时才填写此节 -->

### IN-{id}: {file}:{line}
**Category:** {category}
**Severity:** INFO
{description}

## Statistics

- Files reviewed: {count}
- Lines of code: {count}
- Test coverage: {percent}% (target: 80%)
- Agents executed: {count}
- Execution time: {seconds}s

## Agent Results

### Flutter Quality Group
- flutter-code-reviewer: {issues} issues ({time}s)
- flutter-performance: {issues} issues ({time}s)
- flutter-security: {issues} issues ({time}s)

### Dart Language Group
- dart-testing: {issues} issues ({time}s)
- dart-architecture: {issues} issues ({time}s)
- dart-correctness: {issues} issues ({time}s)

### Testing & Architecture Group
- dart-performance: {issues} issues ({time}s)
- dart-security: {issues} issues ({time}s)
- gsd-code-fixer: {issues} issues ({time}s)

<!--
模板说明:
- status: clean (无 critical/warning) | warning (有 warning 但无 critical)
- 由 9 个 agent 并行执行后合并结果
- 3 组: Flutter Quality (3), Dart Language (3), Testing & Architecture (3)
- Gate 策略: 只有 analyze errors + test failures 阻塞; quality/perf/security 为 escalation (warn only)
- 输出由 flutter-quality-gate workflow 在 execute:post 阶段自动生成
-->
