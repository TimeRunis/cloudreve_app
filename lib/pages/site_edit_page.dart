import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/site.dart';
import '../providers/sites_provider.dart';

/// 新增 / 编辑站点。
class SiteEditPage extends ConsumerStatefulWidget {
  final Site? site;

  const SiteEditPage({super.key, this.site});

  @override
  ConsumerState<SiteEditPage> createState() => _SiteEditPageState();
}

class _SiteEditPageState extends ConsumerState<SiteEditPage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _urlCtrl;
  bool _saving = false;
  bool _skipTls = false;

  bool get _isEdit => widget.site != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.site?.name ?? '');
    _urlCtrl = TextEditingController(text: widget.site?.baseUrl ?? '');
    _skipTls = widget.site?.skipTlsVerify ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  String _normalizeUrl(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final url = _normalizeUrl(_urlCtrl.text);
    if (name.isEmpty) {
      _toast('请输入站点名称');
      return;
    }
    if (url.isEmpty || !(url.startsWith('http://') || url.startsWith('https://'))) {
      _toast('请输入合法的站点地址（以 http(s):// 开头）');
      return;
    }

    setState(() => _saving = true);
    final site = Site(
      id: _isEdit ? widget.site!.id : DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      baseUrl: url,
      skipTlsVerify: _skipTls,
    );
    await ref.read(sitesProvider.notifier).addSite(site);
    if (mounted) {
      setState(() => _saving = false);
      Navigator.of(context).pop();
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? '编辑站点' : '添加站点')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: '站点名称',
                hintText: '例如：我的网盘',
                prefixIcon: Icon(Icons.label_outline),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlCtrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: '站点地址',
                hintText: 'https://your-cloudreve-site.com',
                prefixIcon: Icon(Icons.link),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              value: _skipTls,
              onChanged: (v) => setState(() => _skipTls = v),
              title: const Text('跳过 HTTPS 证书校验'),
              subtitle: const Text('站点使用自签名证书或证书链不完整时开启'),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}
