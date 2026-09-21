import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import '../extensions/registry.dart';
import '../extensions/toolbox_extension.dart';
import '../theme/studio_theme.dart';

import 'about_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String _status = '';
  bool _checking = false;
  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _status = '$e');
    }
  }

  Widget _heading(IconData icon, String title, String subtitle) {
    final c = Theme.of(context).colorScheme;
    return Row(children: [
      Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: c.primaryContainer,
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 19, color: c.primary)),
      const SizedBox(width: 13),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(subtitle,
            style: TextStyle(fontSize: 12, color: c.onSurfaceVariant))
      ]))
    ]);
  }

  Widget _path(String value, VoidCallback browse) {
    final c = Theme.of(context).colorScheme;
    return Container(
        padding: const EdgeInsets.fromLTRB(13, 5, 5, 5),
        decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: c.outlineVariant)),
        child: Row(children: [
          Expanded(
              child: Text(value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: c.onSurfaceVariant))),
          const SizedBox(width: 10),
          TextButton(onPressed: browse, child: const Text('浏览文件'))
        ]));
  }

  bool _engineOpen = false;
  Widget _group(List<Widget> children) => StudioPanel(
      padding: EdgeInsets.zero,
      child: Column(children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(indent: 56),
          children[i],
        ]
      ]));
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final settings = ref.watch(appSettingsProvider);
    final extensions = ref.watch(extensionManagerProvider);
    return ListView(padding: const EdgeInsets.all(28), children: [
      Row(children: [
        if (_engineOpen)
          IconButton(
              tooltip: '返回设置',
              onPressed: () => setState(() => _engineOpen = false),
              icon: const Icon(Icons.arrow_back)),
        Text(_engineOpen ? 'FFmpeg 引擎' : '设置与扩展',
            style: Theme.of(context).textTheme.titleLarge),
      ]),
      const SizedBox(height: 24),
      if (_engineOpen)
        StudioPanel(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              _heading(Icons.memory_rounded, 'FFmpeg 引擎', '为转换、压缩和剪切提供处理能力'),
              const SizedBox(height: 22),
              _path(
                  settings.ffmpegPath ?? '尚未选择 FFmpeg 可执行文件',
                  () => _guard(() async {
                        final result = await FilePicker.platform.pickFiles();
                        final path = result?.files.single.path;
                        if (path != null && mounted) {
                          await ref
                              .read(appSettingsProvider.notifier)
                              .setFfmpegPath(path);
                        }
                      })),
              const SizedBox(height: 14),
              Wrap(spacing: 10, runSpacing: 8, children: [
                OutlinedButton.icon(
                    onPressed: _checking
                        ? null
                        : () async {
                            setState(() => _checking = true);
                            await _guard(() async {
                              final result = await ref
                                  .read(appSettingsProvider.notifier)
                                  .checkFfmpeg();
                              if (mounted) setState(() => _status = result);
                            });
                            if (mounted) setState(() => _checking = false);
                          },
                    icon: const Icon(Icons.check_circle_outline, size: 15),
                    label: Text(_checking ? '正在检测' : '检测版本')),
                TextButton.icon(
                    onPressed: () => _guard(() async {
                          if (!await launchUrl(
                              Uri.parse('https://ffmpeg.org/download.html'),
                              mode: LaunchMode.externalApplication)) {
                            throw Exception('无法打开下载页');
                          }
                        }),
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: const Text('下载 / 更新 FFmpeg')),
              ]),
              const SizedBox(height: 12),
              Text('下载对应系统的构建包，解压后选择 ffmpeg 可执行文件。',
                  style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
              if (_status.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: SelectableText(_status,
                        style: TextStyle(fontSize: 12, color: c.primary))),
            ]))
      else ...[
        const Text('通用', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        _group([
          ListTile(
              leading: const Icon(Icons.memory_outlined),
              title: const Text('FFmpeg 引擎'),
              subtitle: Text(settings.ffmpegPath ?? '尚未配置',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => setState(() => _engineOpen = true)),
          ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('默认保存位置'),
              subtitle: Text(settings.downloadPath ?? '选择输出文件夹',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _guard(() async {
                    final path = await FilePicker.platform.getDirectoryPath();
                    if (path != null && mounted) {
                      await ref
                          .read(appSettingsProvider.notifier)
                          .setDownloadPath(path);
                    }
                  })),
        ]),
        const SizedBox(height: 26),
        const Text('扩展', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        _group([
          for (final extension in bundledExtensions)
            ListTile(
                leading: const Icon(Icons.extension_outlined),
                title: Text(extension.name),
                subtitle: Text(
                    extension.isBusy(ref) ? '正在工作，完成后可停用' : '停用后保留配置与 Cookie'),
                trailing: Switch(
                    value: extensions.enabled.contains(extension.id),
                    onChanged: !extensions.loaded || extension.isBusy(ref)
                        ? null
                        : (value) => _guard(() => ref
                            .read(extensionManagerProvider.notifier)
                            .setEnabled(extension.id, value)))),
        ]),
        const SizedBox(height: 26),
        const Text('应用信息', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        _group([
          ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('关于 Videoader'),
              subtitle: const Text('版本信息、检查更新与开源许可'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AboutPage()))),
        ]),
        if (_status.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 16), child: Text(_status)),
      ],
    ]);
  }
}
