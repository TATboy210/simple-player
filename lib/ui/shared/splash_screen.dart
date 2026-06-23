import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 启动 Splash — 品牌名 + 进度指示器
///
/// 在 MaterialApp 加载完成前显示（此时无 localization context）。
/// 使用 const 品牌名，不依赖 AppLocalizations。
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  static const _brandName = 'S I M P L E   P L A Y E R';

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _brandName,
              style: TextStyle(
                fontSize: Tokens.fontBranding,
                fontWeight: Tokens.weightExtraLight,
                color: Tokens.textPrimary,
                letterSpacing: 4,
              ),
            ),
            SizedBox(height: Tokens.spXl),
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Tokens.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
