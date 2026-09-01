---
status: complete
phase: 04-error-feedback-settings
source: [04-VERIFICATION.md]
started: 2026-09-01T03:10:00+08:00
updated: 2026-09-01T15:20:00+08:00
---

## Current Test

[testing complete]

## Tests

### 1. 实机开关切换(SET-01)
expected: |
  设置→通用→关闭错误卡片开关:已显示卡片同帧消失;触发错误→错误仍写入日志(卡片不弹);
  重新开启:队列中最新错误恢复显示。log 固定写软件根目录 logs/(无路径配置入口——用户决策移除)。
result: pass

### 2. 开关重启持久化(SET-03)
expected: |
  切换开关后完全退出并重启应用:开关状态仍保留(settings.json 位于 exe 旁;debug run 时
  位于项目运行目录旁;MSIX 下回退 Application Support 层)。
result: pass

### 3. 已移除(用户决策:路径配置功能整体移除)
expected: 日志路径配置入口不再存在;log 固定软件根目录 logs/,exe 不可写时静默回退 Application Support。
result: pass

### 4. MSIX ACL 冒烟(设置双层回退)
expected: |
  MSIX 安装包运行:exe 旁 settings.json 探测失败 → 设置静默回退到 Application Support
  settings.json;切换开关后重启仍保留(落在 AS 层);无崩溃。
result: pass

### 5. 已移除(同 Test 3)
expected: 路径配置 UI 不再存在。
result: pass
note: "04-05 absence 测试证实 UI 不再存在"

### 6. 快速开关并发确认(简化后)
expected: |
  快速连续切换卡片开关数次:最终状态 = 最后一次操作;无卡死/崩溃。
result: pass

## Summary

total: 6
passed: 4
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

- gap_id: G-04-1
  truth: "日志路径配置功能整体移除——通用 tab 仅剩卡片开关;log 固定软件根目录 logs/(双层回退 exe→AS 保留,校验保留作内部探测);SET-02 按修订语义关账"
  status: resolved
  resolved_by: 04-05-PLAN
  resolved_at: 2026-09-01
  reason: "User reported: 只是觉得更改log的保存路径的功能太鸡肋，移除这个细节吧，log文件保存在软件的根目录下"
  severity: minor
  test: 3
  root_cause: "产品决策而非缺陷——功能已按原 SET-02 交付并验证,用户实测后判定不需要;D-07 已锁定修订语义"
  artifacts:
    - path: "lib/ui/dialogs/settings/general_settings_content.dart"
      issue: "路径行/浏览/防抖校验 UI 待移除(保留开关行)"
    - path: "lib/ui/dialogs/settings/error_feedback_settings.dart"
      issue: "logDirectory 字段待移除(保留 errorCardEnabled);双层回退保留"
    - path: "lib/kernel/diagnostics/error_log_location.dart"
      issue: "配置层(configured tier)待移除,链收窄为 exe→AS;validateConfiguredDirectory 保留作内部探测"
    - path: "lib/ui/dialogs/settings/diagnostic_log_target.dart"
      issue: "协调器简化为仅启动激活(运行时重定向 API 无调用方后可收窄)"
  missing:
    - "移除路径行 UI 与 logDirectory 字段及关联测试"
    - "resolve 链收窄为双层;启动激活接线保持"
    - "D-04 通知桥移除(无配置失败场景)"
    - "受影响测试同步收窄(契约翻转用例改写为双层断言)"
  debug_session: ""
