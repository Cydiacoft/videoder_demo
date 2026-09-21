import 'browser_cookies.dart';
import '../../../services/expert_command.dart';

/// Options shared by the editor and the process argument builder.
class DownloadOptions {
  static const fields = <String, String>{
    'format': '自定义格式选择（如 bv*+ba/b）',
    'merge-output-format': '合并容器（如 mp4 / mkv / webm）',
    'audio-format': '提取音频格式（如 mp3 / flac / opus）',
    'audio-quality': '音频质量（如 0 或 192K）',
    'sub-langs': '字幕语言（如 zh.*,en）',
    'playlist-items': '播放列表范围（如 1:5 或 1,3,7）',
    'limit-rate': '下载限速（如 5M）',
    'concurrent-fragments': '并发片段数（原生下载器）',
    'retries': '失败重试次数（整数或 infinite）',
    'socket-timeout': '网络超时（秒）',
    'proxy': '代理地址（如 http://127.0.0.1:7890）',
    'referer': 'Referer 请求来源',
    'user-agent': 'User-Agent',
    'output': '文件名模板（如 %(title)s [%(id)s].%(ext)s）',
    'download-archive': '下载记录文件（跳过已下载条目）',
  };
  static const toggles = <String, String>{
    'yes-playlist': '下载整个播放列表',
    'write-subs': '保存字幕',
    'write-auto-subs': '包含自动字幕',
    'embed-subs': '嵌入字幕',
    'embed-metadata': '嵌入媒体信息',
    'write-thumbnail': '保存封面',
    'embed-thumbnail': '嵌入封面',
    'write-info-json': '保存信息 JSON',
  };

  static List<String> build(Map<String, String> options) {
    final args = <String>[...BrowserCookies.arguments(options)];
    for (final key in fields.keys) {
      final value = (options[key] ?? '').trim();
      if (value.isEmpty) continue;
      if (['concurrent-fragments', 'retries', 'socket-timeout'].contains(key)) {
        final number = int.tryParse(value);
        if (!(key == 'retries' && value == 'infinite') &&
            (number == null || number < (key == 'retries' ? 0 : 1))) {
          throw FormatException('${fields[key]}：请输入有效整数');
        }
      }
      args.addAll(['--$key', value]);
    }
    // Keep playlist behavior explicit; a single video URL should not unexpectedly queue a playlist.
    args.add(
        options['yes-playlist'] == 'true' ? '--yes-playlist' : '--no-playlist');
    for (final key in toggles.keys.where((key) => key != 'yes-playlist')) {
      if (options[key] == 'true') args.add('--$key');
    }
    args.addAll(ArgumentCodec.parse(options['custom'] ?? ''));
    return args;
  }
}
