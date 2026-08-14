import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../core/network/cloudreve_api.dart';
import '../providers/api_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/site_config_provider.dart';
import '../widgets/theme_menu.dart';
import 'site_list_page.dart';

/// 登录页。
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _captchaCtrl = TextEditingController();

  bool _obscure = true;
  bool _submitting = false;
  CaptchaResult? _captcha;
  bool _captchaLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _captchaCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCaptcha() async {
    final api = ref.read(apiProvider);
    setState(() => _captchaLoading = true);
    try {
      final c = await api.getCaptcha();
      if (mounted) setState(() => _captcha = c);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('验证码加载失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _captchaLoading = false);
    }
  }

  Future<void> _login() async {
    final site = ref.read(currentSiteProvider);
    if (site == null) return;
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      _toast('请输入邮箱和密码');
      return;
    }
    final needCaptcha =
        ref.read(loginConfigProvider).valueOrNull?.captchaEnabled ?? false;
    if (needCaptcha && _captchaCtrl.text.trim().isEmpty) {
      _toast('请输入验证码');
      return;
    }

    setState(() => _submitting = true);
    try {
      final api = ref.read(apiProvider);
      final result = await api.login(
        email: email,
        password: password,
        captcha: needCaptcha ? _captchaCtrl.text.trim() : null,
        ticket: needCaptcha ? _captcha?.ticket : null,
      );
      await ref
          .read(authProvider.notifier)
          .signIn(site, result.token, result.user);
    } on ApiException catch (e) {
      if (mounted) {
        if (e.isTwoFactor) {
          _toast('该账号需要两步验证，暂不支持');
        } else {
          _toast(e.message.isEmpty ? '登录失败' : e.message);
        }
        if (needCaptcha) _loadCaptcha();
        _captchaCtrl.clear();
      }
    } catch (e) {
      if (mounted) _toast('登录失败：$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final site = ref.watch(currentSiteProvider);
    final config = ref.watch(siteConfigProvider).valueOrNull;
    final needCaptcha =
        ref.watch(loginConfigProvider).valueOrNull?.captchaEnabled ?? false;

    if (needCaptcha && _captcha == null && !_captchaLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadCaptcha());
    }

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(site?.name ?? '登录'),
        actions: const [
          ThemeModeMenu(),
          SizedBox(width: 4),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.cloud_outlined,
                    size: 72, color: scheme.primary),
                const SizedBox(height: 12),
                Text(
                  config?.title ?? 'Cloudreve',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: '邮箱',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: '密码',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                if (needCaptcha) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _captchaCtrl,
                          decoration: const InputDecoration(
                            labelText: '验证码',
                            prefixIcon: Icon(Icons.verified_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildCaptchaImage(),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _submitting ? null : _login,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('登录'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SiteListPage()),
                  ),
                  child: const Text('切换 / 管理站点'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCaptchaImage() {
    final c = _captcha;
    return InkWell(
      onTap: _captchaLoading ? null : _loadCaptcha,
      child: Container(
        width: 120,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(4),
        ),
        child: c == null
            ? const SizedBox(
                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : _imageFromDataUri(c.image),
      ),
    );
  }

  Widget _imageFromDataUri(String dataUri) {
    if (!dataUri.startsWith('data:') || !dataUri.contains(',')) {
      return const Text('点击刷新');
    }
    final base64 = dataUri.substring(dataUri.indexOf(',') + 1);
    try {
      final bytes = base64Decode(base64);
      return Image.memory(bytes, fit: BoxFit.cover);
    } catch (_) {
      return const Text('点击刷新');
    }
  }
}
