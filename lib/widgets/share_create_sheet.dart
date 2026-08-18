import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../models/file_item.dart';
import '../providers/api_provider.dart';
import 'file_icon.dart';
import 'view_panel.dart';

enum _PasswordMode { none, random, custom }

/// 创建分享弹层。
///
/// 支持无密码 / 随机密码 / 自定义密码、README 展示、超时自动过期、
/// 创建成功后展示分享链接，并可选择链接中是否携带密码。
class ShareCreateSheet extends ConsumerStatefulWidget {
  final FileItem file;

  const ShareCreateSheet({super.key, required this.file});

  @override
  ConsumerState<ShareCreateSheet> createState() => _ShareCreateSheetState();
}

class _ShareCreateSheetState extends ConsumerState<ShareCreateSheet> {
  static const List<(String, int)> _expiryOptions = [
    ('1 小时', 3600),
    ('1 天', 24 * 3600),
    ('3 天', 3 * 24 * 3600),
    ('7 天', 7 * 24 * 3600),
    ('30 天', 30 * 24 * 3600),
  ];

  _PasswordMode _passwordMode = _PasswordMode.none;
  final TextEditingController _customPasswordController =
      TextEditingController();
  final TextEditingController _randomPasswordController =
      TextEditingController();
  String _randomPassword = '';
  bool _obscureCustom = true;

  bool _shareView = true;
  bool _showReadme = false;
  bool _expireEnabled = false;
  int _expireSeconds = 7 * 24 * 3600;

  bool _submitting = false;
  String? _error;

  String? _resultUrl;
  bool _includePassword = true;

  @override
  void dispose() {
    _customPasswordController.dispose();
    _randomPasswordController.dispose();
    super.dispose();
  }

  bool get _isPrivate => _passwordMode != _PasswordMode.none;

  String _generateRandomPassword() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }

  void _selectPasswordMode(_PasswordMode mode) {
    setState(() {
      _passwordMode = mode;
      _error = null;
      if (mode == _PasswordMode.random && _randomPassword.isEmpty) {
        _randomPassword = _generateRandomPassword();
        _randomPasswordController.text = _randomPassword;
      }
    });
  }

  void _regenerateRandom() {
    final password = _generateRandomPassword();
    setState(() {
      _randomPassword = password;
      _randomPasswordController.text = password;
      _error = null;
    });
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    final String? password;
    if (_passwordMode == _PasswordMode.custom) {
      final pwd = _customPasswordController.text.trim();
      if (pwd.isEmpty) {
        setState(() {
          _submitting = false;
          _error = '请输入自定义密码';
        });
        return;
      }
      if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(pwd)) {
        setState(() {
          _submitting = false;
          _error = '密码只能包含字母和数字';
        });
        return;
      }
      password = pwd;
    } else if (_passwordMode == _PasswordMode.random) {
      password = _randomPassword;
    } else {
      password = null;
    }

    try {
      final url = await ref.read(apiProvider).createShare(
            uri: widget.file.path,
            isPrivate: _isPrivate ? true : null,
            password: password,
            expire: _expireEnabled ? _expireSeconds : null,
            shareView: _shareView,
            showReadme: _showReadme,
          );
      if (!mounted) return;
      if (url.isEmpty) {
        setState(() {
          _submitting = false;
          _error = '创建分享失败，服务器未返回链接';
        });
        return;
      }
      setState(() {
        _submitting = false;
        _resultUrl = url;
        _includePassword = _isPrivate;
      });
    } catch (e) {
      print('[ShareCreateSheet] 创建分享失败: $e');
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = '创建分享失败，请重试';
      });
    }
  }

  String get _displayUrl {
    final url = _resultUrl;
    if (url == null) return '';
    if (!_isPrivate || _includePassword) return url;
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length >= 3) {
      final newPath = '/${segments.sublist(0, 2).join('/')}';
      return uri.replace(path: newPath, query: null, fragment: null).toString();
    }
    return url;
  }

  Future<void> _copyUrl() async {
    final url = _displayUrl;
    if (url.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('链接已复制')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Material(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: _resultUrl != null
              ? _buildResult(context)
              : _buildForm(context),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final colors = context.appColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '创建分享',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        _buildFileInfo(context),
        const SizedBox(height: 16),
        Text('访问密码',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colors.textPrimary)),
        const SizedBox(height: 8),
        SegmentedGroup<_PasswordMode>(
          options: const [
            (Icons.lock_open_outlined, '无密码', _PasswordMode.none),
            (Icons.shuffle, '随机密码', _PasswordMode.random),
            (Icons.password, '自定义密码', _PasswordMode.custom),
          ],
          value: _passwordMode,
          onChanged: _selectPasswordMode,
        ),
        if (_passwordMode == _PasswordMode.random) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _randomPasswordController,
            readOnly: true,
            enabled: !_submitting,
            decoration: InputDecoration(
              hintText: '随机密码',
              prefixIcon: Icon(Icons.shuffle,
                  size: 18, color: colors.textMuted),
              suffixIcon: IconButton(
                tooltip: '重新生成',
                icon: Icon(Icons.refresh,
                    size: 18, color: colors.textMuted),
                onPressed: _regenerateRandom,
              ),
              filled: true,
              fillColor: colors.surfaceMuted,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
        if (_passwordMode == _PasswordMode.custom) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _customPasswordController,
            obscureText: _obscureCustom,
            enabled: !_submitting,
            decoration: InputDecoration(
              hintText: '请输入自定义密码',
              prefixIcon: Icon(Icons.password,
                  size: 18, color: colors.textMuted),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureCustom
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                  color: colors.textMuted,
                ),
                onPressed: () =>
                    setState(() => _obscureCustom = !_obscureCustom),
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
                borderSide:
                    BorderSide(color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        SwitchListTile(
          value: _shareView,
          onChanged: (v) => setState(() => _shareView = v),
          title: Text('允许查看分享设置',
              style: TextStyle(fontSize: 14, color: colors.textPrimary)),
          subtitle: Text(
            '勾选后，其他用户访问此共享文件夹时可以看到你保存在服务器的视图设置 (布局、排序等)。',
            style: TextStyle(fontSize: 12, color: colors.textMuted),
          ),
          contentPadding: EdgeInsets.zero,
          activeColor: Theme.of(context).colorScheme.primary,
        ),
        SwitchListTile(
          value: _showReadme,
          onChanged: (v) => setState(() => _showReadme = v),
          title: Text('展示 README 文件',
              style: TextStyle(fontSize: 14, color: colors.textPrimary)),
          subtitle: Text(
            '勾选后，会自动为访问者展示目录下的 README.md (区分大小写) 文件。',
            style: TextStyle(fontSize: 12, color: colors.textMuted),
          ),
          contentPadding: EdgeInsets.zero,
          activeColor: Theme.of(context).colorScheme.primary,
        ),
        SwitchListTile(
          value: _expireEnabled,
          onChanged: (v) => setState(() => _expireEnabled = v),
          title: Text('超时自动过期',
              style: TextStyle(fontSize: 14, color: colors.textPrimary)),
          subtitle: Text(
            '开启后，分享链接将在指定时间后自动失效',
            style: TextStyle(fontSize: 12, color: colors.textMuted),
          ),
          contentPadding: EdgeInsets.zero,
          activeColor: Theme.of(context).colorScheme.primary,
        ),
        if (_expireEnabled) ...[
          const SizedBox(height: 4),
          DropdownButtonFormField<int>(
            value: _expireSeconds,
            decoration: InputDecoration(
              labelText: '过期时间',
              filled: true,
              fillColor: colors.surfaceMuted,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            items: _expiryOptions
                .map((e) => DropdownMenuItem(value: e.$2, child: Text(e.$1)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _expireSeconds = v);
            },
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(
                fontSize: 12, color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? '创建中…' : '创建分享'),
        ),
      ],
    );
  }

  Widget _buildResult(BuildContext context) {
    final colors = context.appColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        Icon(Icons.check_circle,
            size: 48, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        Text(
          '分享创建成功',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
          decoration: BoxDecoration(
            color: colors.surfaceMuted,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  _displayUrl,
                  style: TextStyle(
                      fontSize: 13, color: colors.textPrimary),
                ),
              ),
              IconButton(
                tooltip: '复制链接',
                icon: Icon(Icons.copy,
                    size: 20, color: colors.textSecondary),
                onPressed: _copyUrl,
              ),
            ],
          ),
        ),
        if (_isPrivate) ...[
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _includePassword,
            onChanged: (v) => setState(() => _includePassword = v ?? true),
            title: Text('在链接中包含密码',
                style: TextStyle(
                    fontSize: 14, color: colors.textPrimary)),
            subtitle: Text(
              '取消勾选后，访问者需要另行输入密码',
              style: TextStyle(fontSize: 12, color: colors.textMuted),
            ),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: Theme.of(context).colorScheme.primary,
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('完成'),
        ),
      ],
    );
  }

  Widget _buildFileInfo(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
      ),
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
              fileIcon(widget.file),
              size: 20,
              color: fileIconColor(context, widget.file),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
                if (!widget.file.isFolder)
                  Text(
                    formatSize(widget.file.size),
                    style:
                        TextStyle(fontSize: 12, color: colors.textMuted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}