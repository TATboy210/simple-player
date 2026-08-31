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

### 1. 实机开关切换 + 日志文件分布(SET-01/SET-02)
expected: |
  设置→通用→关闭错误卡片开关:已显示卡片同帧消失;触发错误→错误仍写入日志(卡片不弹);
  重新开启:队列中最新错误恢复显示。日志路径配置为新目录后触发错误:新目录出现 error.log
  且含新记录,旧文件保留全部旧行。
result: [pending]

### 2. 路径修改 + 重启持久化(SET-03)
expected: |
  修改路径/开关后完全退出并重启应用:设置仍保留(settings.json 位于 exe 旁;debug run 时
  位于项目运行目录旁)。重启后开关状态与日志路径生效。
result: [pending]

### 3. 一次性回退 OSD(D-04)
expected: |
  配置一个无效路径(如指向一个文件):设置页行内显示 ✗ 与回退原因;OSD pill「日志已回退到
  默认位置」出现恰一次,不重复刷屏;错误记录不间断(自动落回默认位置)。
result: [pending]

### 4. MSIX ACL 冒烟(WR-06 回退层)
expected: |
  MSIX 安装包运行:exe 旁 settings.json 探测失败 → 设置静默回退到 Application Support
  settings.json;修改设置后重启仍保留(落在 AS 层);无崩溃。
result: [pending]

### 5. 非法路径行内呈现 + 浏览按钮(SET-02 UI)
expected: |
  手输非法路径(指向一个文件/纯空格/相对路径):行内即时 ✗ 与具体原因,不保存;
  「浏览」选目录回填后校验 ✓ 并保存;取消选择无副作用。
result: [pending]

### 6. 并发/重定向实机确认(WR-01/WR-05)
expected: |
  快速连续修改日志路径数次(模拟并发 apply):最终卡片/行内显示的有效路径与实际写入
  位置一致(诊断证据不误路由);快速开关设置项:最终状态 = 最后一次操作。
result: [pending]

## Summary

total: 6
passed: 0
issues: 0
pending: 6
skipped: 0
blocked: 0

## Gaps
