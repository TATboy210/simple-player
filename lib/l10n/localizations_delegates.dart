import 'package:cupertino_ui/cupertino_ui.dart' as cui;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart' as fl;
import 'package:material_ui/material_ui.dart' as mui;

import 'app_localizations.dart';

/// MaterialApp 的 localizationsDelegates 单源 — 生产（app.dart）与测试夹具
/// 共用，保证两边看到同一组 Localizations 类型。
///
/// 为什么手动组装而不是用生成的 `AppLocalizations.localizationsDelegates`：
/// Flutter 3.50 把 GlobalMaterial/GlobalCupertino 拆出到 material_ui/
/// cupertino_ui，且两个包的 MaterialLocalizations/CupertinoLocalizations
/// 与 SDK 的**不是同一 Type**。框架按 delegate.type 去重校验每个声明
/// locale（`_debugCheckLocalizations`），缺任一侧都会打印 "locale is not
/// supported by all delegates" 警告并使测试失败。SDK 三件覆盖 flutter/
/// widgets 组件链，mui/cui 两件覆盖 material_ui/cupertino_ui 组件链。
///
/// SDK 的 Global* 已在 3.50 弃用；gen-l10n 模板迁移到 mui/cui 后，SDK 两件
/// 可移除（GlobalWidgets 仍需要）。
const List<LocalizationsDelegate<Object>> l10nDelegates =
    <LocalizationsDelegate<Object>>[
  AppLocalizations.delegate,
  // ignore: deprecated_member_use
  fl.GlobalMaterialLocalizations.delegate,
  fl.GlobalWidgetsLocalizations.delegate,
  // ignore: deprecated_member_use
  fl.GlobalCupertinoLocalizations.delegate,
  mui.GlobalMaterialLocalizations.delegate,
  cui.GlobalCupertinoLocalizations.delegate,
];
