import 'package:flutter/material.dart';

import '../../../kernel/services/video_processing_service.dart';
import '../../../kernel/ui/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/video_processing_tab.dart';

/// 画面处理 tab — 包装 VideoProcessingTab
class VideoTab extends StatelessWidget {
  final VideoProcessingService? videoProcessing;
  const VideoTab({super.key, this.videoProcessing});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (videoProcessing != null) {
      return VideoProcessingTab(service: videoProcessing!);
    }
    return Center(
      child: Text(
        l10n.videoProcessingUnavailable,
        style: const TextStyle(color: Tokens.textSecondary),
      ),
    );
  }
}
