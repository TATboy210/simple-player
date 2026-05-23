---
phase: 01-zero-risk-rendering-fixes
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/kernel/utils/platform_decoders.dart
  - lib/main.dart
  - lib/models/playlist_item.dart
autonomous: true
requirements: [PERF-02, ARCH-03]
user_setup: []

must_haves:
  truths:
    - "fvp使用D3D11硬件解码而非D3D9-to-D3D11表面复制"
    - "GPU加速YUV-to-RGB转换已启用"
    - "调试日志格式化开销已消除"
    - "lib/models/playlist_item.dart死代码已清理"
  artifacts:
    - path: "lib/kernel/utils/platform_decoders.dart"
      provides: "D3D11解码器配置"
      contains: "MFT:d3d=11"
    - path: "lib/main.dart"
      provides: "fvp注册配置"
      contains: "log"
    - path: "lib/models/playlist_item.dart"
      provides: null
      deleted: true
  key_links:
    - from: "lib/main.dart"
      to: "lib/kernel/utils/platform_decoders.dart"
      via: "getOptimalDecoders()"
      pattern: "decoders.join\\(.*\\)"
---

<objective>
修复fvp渲染配置，消除已知性能瓶颈

Purpose: 将D3D9解码升级为D3D11，启用GPU着色器转换，关闭调试日志
Output: 更新后的fvp配置 + 清理死代码
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/01-zero-risk-rendering-fixes/01-CONTEXT.md

<interfaces>
From lib/kernel/utils/platform_decoders.dart:
```dart
List<String>? getOptimalDecoders() // 返回解码器列表或null
```

From lib/main.dart:
```dart
fvp.registerWith(options: {'video.decoders': decoders.join(':')}) // 当前错误格式
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: 修复解码器配置 — D3D11 + shader_resource</name>
  <files>lib/kernel/utils/platform_decoders.dart</files>
  <read_first>
    - lib/kernel/utils/platform_decoders.dart
    - .planning/phases/01-zero-risk-rendering-fixes/01-CONTEXT.md
  </read_first>
  <action>
    修改getOptimalDecoders()函数的Windows解码器配置（per D-01, D-02）：

    1. 将MFT:d3d=1改为MFT:d3d=11（启用D3D11硬件解码）
    2. 将D3D11改为D3D11:shader_resource=1（启用GPU着色器YUV-to-RGB转换）

    具体修改：
    - Windows非ARM分支：`['MFT:d3d=11', 'NVDEC', 'D3D11:shader_resource=1', 'FFmpeg']`
    - Windows ARM分支：`['MFT:d3d=11', 'D3D11:shader_resource=1', 'FFmpeg']`
    - Linux和macOS配置保持不变

    不要修改函数签名或返回类型。
  </action>
  <verify>
    <automated>flutter analyze lib/kernel/utils/platform_decoders.dart</automated>
  </verify>
  <acceptance_criteria>
    - Windows非ARM分支返回`['MFT:d3d=11', 'NVDEC', 'D3D11:shader_resource=1', 'FFmpeg']`
    - Windows ARM分支返回`['MFT:d3d=11', 'D3D11:shader_resource=1', 'FFmpeg']`
    - 不包含`MFT:d3d=1`（无11后缀的版本）
    - 不包含单独的`D3D11`（必须带shader_resource=1属性）
    - Linux和macOS配置未修改
    - 文件通过flutter analyze无错误
  </acceptance_criteria>
  <done>D3D11硬件解码和GPU着色器转换已启用</done>
</task>

<task type="auto">
  <name>Task 2: 修复fvp注册 — List格式 + log级别</name>
  <files>lib/main.dart</files>
  <read_first>
    - lib/main.dart
    - lib/kernel/utils/platform_decoders.dart
    - .planning/phases/01-zero-risk-rendering-fixes/01-CONTEXT.md
  </read_first>
  <action>
    修改main()函数中的fvp.registerWith()调用（per D-03, D-04）：

    1. 移除join(':')调用 — getOptimalDecoders()已返回List<String>，直接传递
    2. 添加log=warning选项 — 消除调试字符串格式化开销

    修改后的registerWith调用格式：
    - 有解码器时：`fvp.registerWith(options: {'video.decoders': decoders, 'log': 'warning'})`
    - 无解码器时：`fvp.registerWith(options: {'log': 'warning'})`

    保持null检查逻辑不变，仅修改options参数。
  </action>
  <verify>
    <automated>flutter analyze lib/main.dart</automated>
  </verify>
  <acceptance_criteria>
    - registerWith调用中不包含`join(':')`或`join(":")`字符串
    - options参数包含`'log': 'warning'`键值对
    - video.decoders的值是decoders变量（List<String>?类型），不是字符串
    - null检查逻辑保持不变
    - 文件通过flutter analyze无错误
  </acceptance_criteria>
  <done>fvp注册使用正确的List格式和日志级别</done>
</task>

<task type="auto">
  <name>Task 3: 删除死代码 — lib/models/playlist_item.dart</name>
  <files>lib/models/playlist_item.dart</files>
  <read_first>
    - lib/models/playlist_item.dart
    - lib/kernel/models/playlist_item.dart
  </read_first>
  <action>
    删除死代码文件lib/models/playlist_item.dart（per D-05, D-06）：

    1. 验证lib/models/playlist_item.dart确实没有被任何文件导入
    2. 删除该文件
    3. 验证lib/kernel/models/playlist_item.dart是唯一使用的版本

    删除前用grep确认：在整个lib/目录中搜索对`models/playlist_item`的导入，确保都指向`kernel/models/playlist_item`路径。

    删除后，如果lib/models/目录变空，也删除该目录。
  </action>
  <verify>
    <automated>flutter analyze</automated>
  </verify>
  <acceptance_criteria>
    - 文件lib/models/playlist_item.dart不存在
    - grep搜索`import.*models/playlist_item`只返回kernel/models/路径的引用
    - 整个项目通过flutter analyze无错误
    - 运行中的代码功能不受影响（其他文件使用正确的kernel版本）
  </acceptance_criteria>
  <done>死代码已清理，仅保留活跃的kernel版本</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| config→fvp | fvp.registerWith options传递MDK引擎配置 |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-01-01 | Tampering | npm/pip/cargo installs | mitigate | 本次无新包安装，仅修改配置 |
</threat_model>

<verification>
完成所有任务后验证：
1. `flutter analyze` — 零错误
2. `flutter run -d windows` — 应用启动正常
3. 视频播放正常，无渲染异常
4. lib/models/目录不存在或为空
</verification>

<success_criteria>
- fvp使用D3D11硬件解码（MFT:d3d=11）
- GPU着色器转换启用（shader_resource=1）
- 调试日志关闭（log=warning）
- 死代码lib/models/playlist_item.dart已删除
- 项目通过flutter analyze
</success_criteria>

<output>
创建 `.planning/phases/01-zero-risk-rendering-fixes/01-01-SUMMARY.md` when done
</output>
