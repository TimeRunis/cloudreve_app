import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/i18n/app_localizations.dart';

/// 加密分享的密码输入视图。
///
/// 纯展示组件：校验由调用方完成，输入结果通过 [onSubmit] 传出。
class SharePasswordView extends StatefulWidget {
  final String shareName;
  final String initialPassword;
  final String? errorText;
  final bool loading;
  final ValueChanged<String> onSubmit;

  const SharePasswordView({
    super.key,
    required this.shareName,
    required this.initialPassword,
    this.errorText,
    this.loading = false,
    required this.onSubmit,
  });

  @override
  State<SharePasswordView> createState() => _SharePasswordViewState();
}

class _SharePasswordViewState extends State<SharePasswordView> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialPassword);
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_outline,
                    size: 28, color: colors.textSecondary),
              ),
              const SizedBox(height: 16),
              Text(
                tr('该分享已加密'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.shareName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: colors.textMuted),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                obscureText: _obscure,
                enabled: !widget.loading,
                decoration: InputDecoration(
                  hintText: tr('请输入访问密码'),
                  prefixIcon:
                      Icon(Icons.password, size: 18, color: colors.textMuted),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                      color: colors.textMuted,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  filled: true,
                  fillColor: colors.surfaceMuted,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
              if (widget.errorText != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.errorText!,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: widget.loading ? null : _submit,
                  child: Text(widget.loading ? tr('校验中…') : tr('进入分享')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
  }
}
