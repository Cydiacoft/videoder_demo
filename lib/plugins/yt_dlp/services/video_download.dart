import 'dart:convert';
import '../../../services/media_inspector.dart';

class VideoDownload {
  static const marker = '__VIDEOADER_OUTPUT__:';
  static String selector(int? height) {
    final limit = height == null ? '' : '[height<=$height]';
    return 'bestvideo$limit+bestaudio/best$limit[vcodec!=none][acodec!=none]';
  }

  static List<String> outputPaths(String text) => text
      .split(RegExp(r'[\r\n]+'))
      .where((line) => line.startsWith(marker))
      .map((line) => jsonDecode(line.substring(marker.length)) as String)
      .toSet()
      .toList();
  static Future<void> verify(String ffmpeg, String path) async {
    final data = await MediaInspector.inspect(ffmpeg, path);
    final streams = data['streams'] as List;
    if (!streams.any((s) => s['codec_type'] == 'video') ||
        !streams.any((s) => s['codec_type'] == 'audio')) {
      throw const FormatException(
          '最终文件缺少视频或音轨。请检查自定义格式参数；若同名旧文件已存在，请更改输出文件名后重新下载。');
    }
  }
}
