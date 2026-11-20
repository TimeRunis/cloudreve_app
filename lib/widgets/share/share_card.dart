import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/share.dart';
import '../file/file_icon.dart';
import '../popup/app_popup.dart';
import '../popup/popup_item.dart';
import '../../core/i18n/app_localizations.dart';

/// 分享卡片上可执行的操作。
enum ShareCardAction { open, copyLink, delete }

/// 「我的分享」列表里的一张卡片。
///
/// 纯展示组件：分享数据 + 点击/菜单动作回调，菜单用 [AppPopup] 锚定按钮弹出。
class ShareCard extends StatefulWidget {
  final ShareLink share;
  final VoidCallback onTap;
  final ValueChanged<ShareCardAction> onAction;

  const ShareCard({
    super.key,
    required this.share,
    required this.onTap,
    required this.onAction,
  });

  @override
  State<ShareCard> createState() => _ShareCardState();
}

class _ShareCardState extends State<ShareCard> {
  /// 「⋮」按钮，作为菜单悬浮窗的锚点。
  final GlobalKey _menuKey = GlobalKey();

  Future<void> _openMenu() async {
    final action = await showAppPopup<ShareCardAction>(
      context: context,
      anchorKey: _menuKey,
      builder: (_) => const _ShareMenu(),
    );
    if (!mounted || action == null) return;
    widget.onAction(action);
  }

  @override
  Widget build(BuildContext context) {
    final share = widget.share;
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    share.isFolder
                        ? Icons.folder_outlined
                        : fileIconForName(share.name),
                    size: 22,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (share.isPrivate == true) ...[
                            Icon(Icons.lock_outline,
                                size: 14, color: colors.textMuted),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: Text(
                              share.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                          if (share.expired) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: colors.border,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                tr('已失效'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(share.createdAt),
                        style: TextStyle(fontSize: 12, color: colors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (share.visited > 0) ...[
                  Icon(Icons.visibility_outlined,
                      size: 16, color: colors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    '${share.visited}',
                    style: TextStyle(fontSize: 13, color: colors.textSecondary),
                  ),
                ],
                KeyedSubtree(
                  key: _menuKey,
                  child: IconButton(
                    tooltip: tr('更多操作'),
                    icon: Icon(Icons.more_vert,
                        size: 20, color: colors.textSecondary),
                    onPressed: _openMenu,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String raw) {
    final date = DateTime.tryParse(raw);
    if (date == null) return raw;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}/${two(date.month)}/${two(date.day)} '
        '${two(date.hour)}:${two(date.minute)}:${two(date.second)}';
  }
}

/// 卡片右上角菜单。
class _ShareMenu extends StatelessWidget {
  const _ShareMenu();

  @override
  Widget build(BuildContext context) {
    return AppPopup(
      child: SizedBox(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PopupItem(
              icon: Icons.open_in_new,
              label: tr('打开'),
              onTap: () => Navigator.of(context).pop(ShareCardAction.open),
            ),
            PopupItem(
              icon: Icons.copy,
              label: tr('复制链接到剪切板'),
              onTap: () => Navigator.of(context).pop(ShareCardAction.copyLink),
            ),
            PopupItem(
              icon: Icons.delete_outline,
              label: tr('删除'),
              onTap: () => Navigator.of(context).pop(ShareCardAction.delete),
            ),
          ],
        ),
      ),
    );
  }
}
