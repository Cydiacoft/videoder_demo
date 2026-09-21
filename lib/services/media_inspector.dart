import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'tool_process.dart';

class MediaInspector {
  static String sibling(String configured, String name) {
    final ffmpeg = resolveExecutable(configured, 'ffmpeg');
    final tool = Platform.isWindows ? '$name.exe' : name;
    return p.dirname(ffmpeg) == '.' ? tool : p.join(p.dirname(ffmpeg), tool);
  }

  static Future<Map<String, dynamic>> inspect(
      String configured, String input) async {
    if (!await File(input).exists()) throw const FormatException('输入文件不存在');
    final result = await runTool(sibling(configured, 'ffprobe'),
        ['-v', 'error', '-show_format', '-show_streams', '-of', 'json', input]);
    if (result.exitCode != 0) throw Exception('媒体信息读取失败：${result.stderr}');
    return jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
  }

  static Future<
          ({List<String> video, List<String> audio, List<String> hardware})>
      capabilities(String configured) async {
    final executable = resolveExecutable(configured, 'ffmpeg');
    final results = await Future.wait([
      runTool(executable, ['-hide_banner', '-encoders']),
      runTool(executable, ['-hide_banner', '-hwaccels'])
    ]);
    for (final result in results) {
      if (result.exitCode != 0) throw Exception('读取引擎能力失败：${result.stderr}');
    }
    List<String> codecs(String type) =>
        RegExp('^\\s*$type[A-Z.]{5}\\s+(\\S+)', multiLine: true)
            .allMatches(results[0].stdout.toString())
            .map((m) => m.group(1)!)
            .where((v) => v != '=')
            .toList();
    final hardware = results[1]
        .stdout
        .toString()
        .split('\n')
        .map((s) => s.trim())
        .where((s) => RegExp(r'^[a-z][a-z0-9_]+$').hasMatch(s))
        .toList();
    return (video: codecs('V'), audio: codecs('A'), hardware: hardware);
  }
}
