import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_update.dart';
import '../theme/studio_theme.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});
  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = '';
  String _status = '检查是否有可用的新版本';
  String _notes = '';
  bool _checking = false;
  bool _available = false;
  @override
  void initState() {
    super.initState();
    AppUpdate.currentVersion().then((value) {
      if (mounted) setState(() => _version = value);
    }).catchError((Object e) {
      if (mounted) setState(() => _status = '$e');
    });
  }

  Future<void> _open(String url) async {
    try {
      if (!await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication)) {
        throw Exception('无法打开浏览器');
      }
    } catch (e) {
      if (mounted) setState(() => _status = '$e');
    }
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _available = false;
      _notes = '';
      _status = '正在连接更新服务…';
    });
    try {
      final data = await AppUpdate.check();
      if (!mounted) return;
      setState(() {
        if (data == null) {
          _status = '暂无可用的公开正式版本，或发布源不可访问。';
          return;
        }
        final latest = data['tag_name'] as String;
        _available = AppUpdate.compareVersions(latest, _version) > 0;
        _status = _available ? '发现新版本 $latest' : '当前版本无需更新（最新发布：$latest）';
        _notes = data['body'] as String? ?? '';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _status =
            error is HttpException ? error.message : '检查更新失败，请检查网络或稍后重试。');
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('关于 Videoader')),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(padding: const EdgeInsets.all(28), children: [
                  Image.asset('assets/branding/app_icon.png',
                      width: 72, height: 72),
                  const SizedBox(height: 16),
                  Text('Videoader · FFmpeg Studio',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(_version.isEmpty ? '正在读取版本…' : '版本 $_version',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  const Text('本地音视频工具箱 · 按需启用下载扩展',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 28),
                  StudioPanel(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        const Text('应用更新',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        Text(_status),
                        const SizedBox(height: 16),
                        Wrap(spacing: 12, runSpacing: 8, children: [
                          FilledButton.icon(
                              onPressed:
                                  _checking || _version.isEmpty ? null : _check,
                              icon: const Icon(Icons.refresh, size: 18),
                              label: Text(_checking ? '正在检查…' : '检查更新')),
                          if (_available)
                            OutlinedButton(
                                onPressed: () => _open(
                                    '${AppUpdate.repository}/releases/latest'),
                                child: const Text('前往下载新版本')),
                        ]),
                        if (_notes.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const Text('更新说明'),
                          const SizedBox(height: 8),
                          SelectableText(_notes)
                        ],
                      ])),
                  const SizedBox(height: 18),
                  StudioPanel(
                      padding: EdgeInsets.zero,
                      child: Column(children: [
                        ListTile(
                            title: const Text('项目主页'),
                            trailing: const Icon(Icons.open_in_new, size: 18),
                            onTap: () => _open(AppUpdate.repository)),
                        const Divider(),
                        ListTile(
                            title: const Text('版本发布记录'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () =>
                                _open('${AppUpdate.repository}/releases')),
                        const Divider(),
                        ListTile(
                            title: const Text('开源许可'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => showLicensePage(
                                context: context,
                                applicationName: 'Videoader',
                                applicationVersion: _version)),
                      ])),
                ]))),
      );
}
