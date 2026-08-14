import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// 顶部搜索弹窗（纯组件：只把提交的搜索词通过回调传出）。
class SearchPopup extends StatefulWidget {
  final ValueChanged<String> onSubmitted;

  const SearchPopup({super.key, required this.onSubmitted});

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
    return Material(
      color: context.appColors.surface,
      borderRadius: BorderRadius.circular(12),
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
                decoration: const InputDecoration(
                  hintText: '搜索文件...',
                  border: InputBorder.none,
                  isDense: true,
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: widget.onSubmitted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
