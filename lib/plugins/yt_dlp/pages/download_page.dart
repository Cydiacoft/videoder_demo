import '../../../widgets/task_status_bar.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'download_options_panel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/download_provider.dart';
import '../providers/activity_provider.dart';
import '../../../providers/app_provider.dart' as core;

class DownloadPage extends ConsumerStatefulWidget {
  const DownloadPage({super.key});
  @override
  ConsumerState<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends ConsumerState<DownloadPage> {
  final _urls = TextEditingController();
  bool _batchRunning = false;
  bool _stopQueue = false;
  bool _logsExpanded = false;
  @override
  void dispose() {
    _stopQueue = true;
    _urls.dispose();
    super.dispose();
  }

  String _parse(String value) =>
      (RegExp(r'https?://[^\s<>"\[\]]+').firstMatch(value)?.group(0) ??
              value.trim())
          .replaceFirst(RegExp(r'[),.;]+$'), '');
  Future<void> _download() async {
    final urls = _urls.text
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map(_parse)
        .toList();
    if (urls.isEmpty) return;
    ref.read(downloadQueueProvider.notifier).state = true;
    setState(() {
      _batchRunning = true;
      _stopQueue = false;
    });
    try {
      for (final url in urls) {
        if (_stopQueue || !mounted) break;
        await ref.read(downloadProvider.notifier).startDownload(url);
      }
    } finally {
      ref.read(downloadQueueProvider.notifier).state = false;
      if (mounted) setState(() => _batchRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coreSettings = ref.watch(core.appSettingsProvider);
    final settings = ref.watch(downloadSettingsProvider).copyWith(
        ffmpegPath: coreSettings.ffmpegPath,
        downloadPath: coreSettings.downloadPath);
    final downloads = ref.watch(downloadProvider);
    final logs = ref.watch(appLogsProvider);
    final colors = Theme.of(context).colorScheme;
    final busy = _batchRunning ||
        downloads.isDownloading ||
        ref.watch(downloadMaintenanceProvider);
    final notifier = ref.read(downloadSettingsProvider.notifier);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.outlineVariant))),
          child: Text('网络下载', style: Theme.of(context).textTheme.titleLarge)),
      Expanded(
          child: ListView(padding: const EdgeInsets.all(24), children: [
        Text('使用 yt-dlp 下载媒体；多个链接按行输入，依次处理。',
            style: TextStyle(color: colors.onSurfaceVariant)),
        const SizedBox(height: 18),
        TextField(
            controller: _urls,
            enabled: !busy,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
                labelText: '媒体链接',
                hintText: 'https://…',
                alignLabelWithHint: true)),
        const SizedBox(height: 16),
        Wrap(spacing: 12, runSpacing: 12, children: [
          SizedBox(
              width: 160,
              child: DropdownButtonFormField<DownloadFormat>(
                  isExpanded: true,
                  initialValue: settings.format,
                  decoration: const InputDecoration(labelText: '下载内容'),
                  items: DownloadFormat.values
                      .map((v) => DropdownMenuItem(
                          value: v,
                          child: Text(['视频＋音频', '音频', '封面'][v.index])))
                      .toList(),
                  onChanged: busy ? null : (v) => notifier.setFormat(v!))),
          SizedBox(
              width: 160,
              child: DropdownButtonFormField<VideoQuality>(
                  isExpanded: true,
                  initialValue: settings.quality,
                  decoration: const InputDecoration(labelText: '画质'),
                  items: VideoQuality.values
                      .map((v) => DropdownMenuItem(
                          value: v,
                          child: Text([
                            '最佳',
                            '1080p',
                            '720p',
                            '480p',
                            '360p',
                            '1440p',
                            '2160p（4K）'
                          ][v.index])))
                      .toList(),
                  onChanged: busy ? null : (v) => notifier.setQuality(v!))),
          SizedBox(
              width: 210,
              child: DropdownButtonFormField<DownloadMode>(
                  isExpanded: true,
                  initialValue: settings.downloadMode,
                  decoration: const InputDecoration(labelText: '下载器'),
                  items: DownloadMode.values
                      .map((v) => DropdownMenuItem(
                          value: v, child: Text(v.displayName)))
                      .toList(),
                  onChanged:
                      busy ? null : (v) => notifier.setDownloadMode(v!))),
        ]),
        const SizedBox(height: 14),
        DownloadOptionsPanel(
            options: settings.options,
            busy: busy,
            onApply: (options) => notifier.setOptions({
                  ...options,
                  'cookie-browser': ref
                          .read(downloadSettingsProvider)
                          .options['cookie-browser'] ??
                      'files',
                  'cookie-profile': ref
                          .read(downloadSettingsProvider)
                          .options['cookie-profile'] ??
                      '',
                })),
        const SizedBox(height: 14),
        if (settings.format == DownloadFormat.video)
          const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text('视频与音频自动合并为 MKV，完成后校验音轨。可在下载参数中修改合并容器。',
                  style: TextStyle(fontSize: 12))),
        Text('保存到：${settings.downloadPath ?? '请在设置与扩展中配置'}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(
              onPressed: busy || !settings.isConfigured ? null : _download,
              icon: const Icon(Icons.download, size: 16),
              label: const Text('开始下载')),
          OutlinedButton(
              onPressed: busy
                  ? null
                  : () async {
                      try {
                        final result = await FilePicker.platform.pickFiles();
                        final path = result?.files.single.path;
                        if (path != null) {
                          final text = await File(path).readAsString();
                          if (mounted) _urls.text = text;
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('导入失败：$e')));
                        }
                      }
                    },
              child: const Text('导入链接文件')),
          if (busy)
            OutlinedButton(
                onPressed: () => setState(() => _stopQueue = true),
                child: Text(_stopQueue ? '当前任务完成后停止' : '停止后续任务')),
        ]),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        Text('本次会话记录 (${downloads.tasks.length})',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        for (final task in downloads.tasks.reversed)
          ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                  task.status.index == 2
                      ? Icons.check_circle_outline
                      : task.status.index == 3
                          ? Icons.error_outline
                          : Icons.downloading,
                  size: 18),
              title:
                  Text(task.url, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle:
                  task.errorMessage == null ? null : Text(task.errorMessage!),
              trailing: Text(['等待', '下载中', '完成', '失败', '跳过'][task.status.index],
                  style: const TextStyle(fontSize: 12))),
      ])),
      TaskStatusBar(
        running: downloads.isDownloading,
        status: downloads.progress.stage,
        fraction: downloads.progress.fraction,
        failed: downloads.progress.stage.contains('失败'),
        details: downloads.isDownloading
            ? '${downloads.progress.speed.isEmpty ? '速度暂不可用' : downloads.progress.speed} · ETA ${downloads.progress.eta.isEmpty ? '暂不可用' : downloads.progress.eta}'
            : '',
      ),
      const Divider(),
      Container(
          height: 34,
          color: colors.surfaceContainerLow,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(children: [
            const Icon(Icons.terminal, size: 15),
            const SizedBox(width: 8),
            Expanded(
                child: InkWell(
                    onTap: () => setState(() => _logsExpanded = !_logsExpanded),
                    child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                            _logsExpanded ? '下载日志 · 点击收起' : '下载日志 · 点击展开',
                            style: const TextStyle(fontSize: 12))))),
            IconButton(
                tooltip: _logsExpanded ? '收起下载日志' : '展开下载日志',
                onPressed: () => setState(() => _logsExpanded = !_logsExpanded),
                icon: Icon(
                    _logsExpanded ? Icons.expand_more : Icons.expand_less,
                    size: 16)),
            IconButton(
                tooltip: '复制诊断日志',
                onPressed: logs.isEmpty
                    ? null
                    : () =>
                        Clipboard.setData(ClipboardData(text: logs.join('\n'))),
                icon: const Icon(Icons.copy_outlined, size: 15)),
            TextButton(
                onPressed: () => ref.read(appLogsProvider.notifier).clear(),
                child: const Text('清空'))
          ])),
      if (_logsExpanded)
        SizedBox(
            height: 150,
            child: SingleChildScrollView(
                reverse: true,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: SelectableText(
                    logs.isEmpty ? '等待下载任务…' : logs.join('\n'),
                    style: TextStyle(
                        fontFamily: 'Consolas',
                        fontFamilyFallback: const [
                          'Microsoft YaHei UI',
                          'Microsoft YaHei',
                          'PingFang SC',
                          'Noto Sans CJK SC'
                        ],
                        fontSize: 12,
                        color: colors.onSurfaceVariant)))),
    ]);
  }
}
