---
status: testing
phase: 04-error-feedback-settings
source: [04-VERIFICATION.md]
started: 2026-09-01T03:10:00+08:00
updated: 2026-09-01T03:10:00+08:00
---

## Current Test

number: 1
name: 实机开关切换 + 日志文件分布(SET-01/SET-02)
expected: |
  设置→通用→关闭错误卡片开关:已显示卡片同帧消失;触发错误→错误仍写入日志(卡片不弹);
  重新开启:队列中最新错误恢复显示。日志路径配置为新目录后触发错误:新目录出现 error.log
  且含新记录,旧文件保留全部旧行(切换不丢不乱序)。
awaiting: user response

## Tests

### 1. 实机开关切换(SET-01)
expected: |
  设置→通用→关闭错误卡片开关:已显示卡片同帧消失;触发错误→错误仍写入日志(卡片不弹);
  重新开启:队列中最新错误恢复显示。log 固定写软件根目录 logs/(无路径配置入口——用户决策移除)。
result: [pending]

### 2. 开关重启持久化(SET-03)
expected: |
  切换开关后完全退出并重启应用:开关状态仍保留(settings.json 位于 exe 旁;debug run 时
  位于项目运行目录旁;MSIX 下回退 Application Support 层)。
result: [pending]

### 3. 已移除(用户决策:路径配置功能整体移除)
expected: 日志路径配置入口不再存在;log 固定软件根目录 logs/,exe 不可写时静默回退 Application Support。
result: skipped
reason: "Deferred follow-up: 用户决策——更改 log 保存路径的功能太鸡肋,移除该细节(gap 闭环计划执行后此项作废)"

### 4. MSIX ACL 冒烟(设置双层回退)
expected: |
  MSIX 安装包运行:exe 旁 settings.json 探测失败 → 设置静默回退到 Application Support
  settings.json;切换开关后重启仍保留(落在 AS 层);无崩溃。
result: [pending]

### 5. 已移除(同 Test 3)
expected: 路径配置 UI 不再存在。
result: skipped
reason: "Deferred follow-up: 同 Test 3——路径配置功能整体移除"

### 6. 快速开关并发确认(简化后)
expected: |
  快速连续切换卡片开关数次:最终状态 = 最后一次操作;无卡死/崩溃。
result: [pending]

## Summary

total: 6
passed: 0
issues: 0
pending: 4
skipped: 2
blocked: 0

## Gaps
