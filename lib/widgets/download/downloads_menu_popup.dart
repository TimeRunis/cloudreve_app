import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../popup/app_popup.dart';
import '../popup/popup_item.dart';

/// 下载页「更多」菜单动作。
enum DownloadsMenuAction {
  resumeAll,
  pauseAll,
  clearCompleted,
  downloadSettings,
}

/// 下载页的更多操作菜单。
///
/// 与其它悬浮窗共用 [AppPopup] 的外观；点击项通过 `Navigator.pop(action)`
/// 把动作交回页面处理。
class DownloadsMenuPopup extends StatelessWidget {
  const DownloadsMenuPopup({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPopup(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.45,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PopupItem(
              icon: Icons.play_arrow_rounded,
              label: '全部开始',
              onTap: () => Navigator.of(context).pop(
                DownloadsMenuAction.resumeAll,
              ),
            ),
            PopupItem(
              icon: Icons.pause_rounded,
              label: '全部暂停',
              onTap: () => Navigator.of(context).pop(
                DownloadsMenuAction.pauseAll,
              ),
            ),
            PopupItem(
              icon: Icons.delete_sweep_outlined,
              label: '清空已完成',
              onTap: () => Navigator.of(context).pop(
                DownloadsMenuAction.clearCompleted,
              ),
            ),
            Divider(height: 1, color: context.appColors.border),
            PopupItem(
              icon: Icons.settings_outlined,
              label: '下载设置',
              onTap: () => Navigator.of(context).pop(
                DownloadsMenuAction.downloadSettings,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
