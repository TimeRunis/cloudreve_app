import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'app_popup.dart';
import '../../core/i18n/app_localizations.dart';

/// 顶部搜索弹窗（纯组件：提交搜索词、打开分享历史都通过回调传出）。
class SearchPopup extends StatefulWidget {
  final ValueChanged<String> onSubmitted;
  final VoidCallback onShareHistory;

  const SearchPopup({
    super.key,
    required this.onSubmitted,
    required this.onShareHistory,
  });

  @override
  State<SearchPopup> createState() => _SearchPopupState();
}

class _SearchPopupState extends State<SearchPopup> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPopup(
      width: MediaQuery.sizeOf(context).width,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.search, color: context.appColors.textMuted, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _controller,
                autofocus: true,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: tr('搜索文件...'),
                  border: InputBorder.none,
                  isDense: true,
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: widget.onSubmitted,
              ),
            ),
            IconButton(
              tooltip: tr('分享历史'),
              onPressed: widget.onShareHistory,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.share_outlined,
                size: 20,
                color: context.appColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
