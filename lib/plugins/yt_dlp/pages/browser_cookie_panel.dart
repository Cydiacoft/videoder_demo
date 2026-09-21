import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/download_provider.dart';
import '../providers/activity_provider.dart';
import '../services/browser_cookies.dart';

class BrowserCookiePanel extends ConsumerStatefulWidget {
  const BrowserCookiePanel({super.key});
  @override
  ConsumerState<BrowserCookiePanel> createState() => _BrowserCookiePanelState();
}

class _BrowserCookiePanelState extends ConsumerState<BrowserCookiePanel> {
  final _profile = TextEditingController();
  String? _browser;
  String _status = '';
  bool _saving = false;
  bool _dirty = false;
  @override
  void dispose() {
    _profile.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(downloadSettingsProvider);
    final busy = _saving ||
        ref.watch(downloadProvider).isDownloading ||
        ref.watch(downloadQueueProvider) ||
        ref.watch(downloadMaintenanceProvider);
    if (!_dirty) {
      _browser = settings.options['cookie-browser'] ?? 'files';
      final profile = settings.options['cookie-profile'] ?? '';
      if (_profile.text != profile) _profile.text = profile;
    }
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('使用浏览器登录状态',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text(
                      '先在浏览器登录网站，再选择来源并应用。下载时由 yt-dlp 读取，不需要复制 Cookie；不会导出整个浏览器的 Cookie 文件。'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                      key: ValueKey(_browser),
                      initialValue: _browser,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Cookie 来源'),
                      items: [
                        for (final entry in BrowserCookies.browsers.entries)
                          DropdownMenuItem(
                              value: entry.key, child: Text(entry.value))
                      ],
                      onChanged: busy
                          ? null
                          : (value) => setState(() {
                                _browser = value;
                                _dirty = true;
                              })),
                  if (_browser != 'files') ...[
                    const SizedBox(height: 16),
                    TextField(
                        controller: _profile,
                        enabled: !busy,
                        onChanged: (_) => _dirty = true,
                        decoration: const InputDecoration(
                            labelText: '浏览器配置文件（可选）',
                            hintText: '留空自动选择，或填写 Default / Profile 1 / 配置目录')),
                    const SizedBox(height: 12),
                    const Text(
                        'Windows 下 Chrome/Edge 的加密或文件占用可能导致读取失败，可尝试 Firefox 或保留手动导入。浏览器模式优先于下面保存的 Cookie。'),
                  ],
                  const SizedBox(height: 12),
                  Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.tonal(
                          onPressed: busy
                              ? null
                              : () async {
                                  setState(() {
                                    _saving = true;
                                    _status = '';
                                  });
                                  try {
                                    await ref
                                        .read(downloadSettingsProvider.notifier)
                                        .setOptions({
                                      ...ref
                                          .read(downloadSettingsProvider)
                                          .options,
                                      'cookie-browser': _browser ?? 'files',
                                      'cookie-profile': _profile.text.trim()
                                    });
                                    if (mounted) {
                                      setState(() {
                                        _dirty = false;
                                        _status = '已应用，下次下载时生效';
                                      });
                                    }
                                  } catch (e) {
                                    if (mounted) setState(() => _status = '$e');
                                  } finally {
                                    if (mounted) {
                                      setState(() => _saving = false);
                                    }
                                  }
                                },
                          child: const Text('应用 Cookie 来源'))),
                  if (_status.isNotEmpty) Text(_status),
                ])));
  }
}
