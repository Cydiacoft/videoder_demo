import 'package:flutter/material.dart';
import '../services/download_options.dart';

class DownloadOptionsPanel extends StatefulWidget {
  const DownloadOptionsPanel(
      {super.key,
      required this.options,
      required this.busy,
      required this.onApply});
  final Map<String, String> options;
  final bool busy;
  final Future<void> Function(Map<String, String>) onApply;
  @override
  State<DownloadOptionsPanel> createState() => _DownloadOptionsPanelState();
}

class _DownloadOptionsPanelState extends State<DownloadOptionsPanel> {
  late final Map<String, String> _draft = Map.of(widget.options);
  String? _error;
  bool _saving = false;
  bool _dirty = false;
  @override
  void didUpdateWidget(covariant DownloadOptionsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dirty && oldWidget.options != widget.options) {
      _draft
        ..clear()
        ..addAll(widget.options);
    }
  }

  @override
  Widget build(BuildContext context) => ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('下载参数',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(_dirty ? '有未应用的修改' : '字幕、播放列表、网络与自定义参数',
            style: const TextStyle(fontSize: 12)),
        children: [
          const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text('留空使用默认值。高级格式参数优先于上方画质设置；自定义参数最后应用。修改后点击“应用参数”。')),
          Wrap(spacing: 12, runSpacing: 16, children: [
            for (final field in DownloadOptions.fields.entries)
              SizedBox(
                  width: 310,
                  child: TextFormField(
                    initialValue: _draft[field.key] ?? '',
                    enabled: !widget.busy && !_saving,
                    decoration: InputDecoration(labelText: field.value),
                    onChanged: (value) => setState(() {
                      _draft[field.key] = value;
                      _dirty = true;
                    }),
                  )),
          ]),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final field in DownloadOptions.toggles.entries)
              FilterChip(
                  label: Text(field.value),
                  selected: _draft[field.key] == 'true',
                  onSelected: widget.busy || _saving
                      ? null
                      : (value) => setState(() {
                            _draft[field.key] = '$value';
                            _dirty = true;
                          })),
          ]),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: _draft['custom'] ?? '',
            minLines: 3,
            maxLines: 8,
            enabled: !widget.busy && !_saving,
            decoration: const InputDecoration(
                labelText: '自定义 yt-dlp 参数',
                hintText: '--extractor-args "youtube:player_client=default"',
                helperText: '只填写参数，不含程序名和链接；带空格的值使用引号。参数会保存在本机。'),
            onChanged: (value) => setState(() {
              _draft['custom'] = value;
              _dirty = true;
            }),
          ),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.all(8),
                child: Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error))),
          Align(
              alignment: Alignment.centerRight,
              child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: FilledButton.tonal(
                    onPressed: widget.busy || _saving
                        ? null
                        : () async {
                            setState(() {
                              _saving = true;
                              _error = null;
                            });
                            try {
                              DownloadOptions.build(_draft);
                              await widget.onApply(Map.of(_draft));
                              if (mounted) {
                                setState(() => _dirty = false);
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                    const SnackBar(content: Text('下载参数已应用')));
                              }
                            } catch (error) {
                              if (mounted) {
                                setState(() => _error = error.toString());
                              }
                            } finally {
                              if (mounted) setState(() => _saving = false);
                            }
                          },
                    child: const Text('应用参数'),
                  ))),
        ],
      );
}
