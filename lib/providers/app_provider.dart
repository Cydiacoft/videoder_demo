import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/tool_process.dart';

class AppSettings {
  final String? ffmpegPath;
  final String? downloadPath;
  const AppSettings({this.ffmpegPath, this.downloadPath});
  AppSettings copyWith({String? ffmpegPath, String? downloadPath}) =>
      AppSettings(
          ffmpegPath: ffmpegPath ?? this.ffmpegPath,
          downloadPath: downloadPath ?? this.downloadPath);
}

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier() : super(const AppSettings()) {
    ready = _load();
  }
  late final Future<void> ready;
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      state = AppSettings(
          ffmpegPath: prefs.getString('ffmpeg_path'),
          downloadPath: prefs.getString('download_path'));
    }
  }

  Future<void> setFfmpegPath(String path) async {
    await ready;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ffmpeg_path', path);
    if (mounted) state = state.copyWith(ffmpegPath: path);
  }

  Future<void> setDownloadPath(String path) async {
    await ready;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('download_path', path);
    if (mounted) state = state.copyWith(downloadPath: path);
  }

  Future<String> checkFfmpeg() async {
    await ready;
    if (state.ffmpegPath?.isNotEmpty != true) {
      throw const FormatException('请先配置 FFmpeg');
    }
    final result = await runTool(
        resolveExecutable(state.ffmpegPath!, 'ffmpeg'), ['-version']);
    if (result.exitCode != 0) throw Exception('FFmpeg 检测失败：${result.stderr}');
    final output = result.stdout.toString().trim();
    if (!output.startsWith('ffmpeg version')) {
      throw const FormatException('该文件不是可识别的 FFmpeg');
    }
    return output.split('\n').first;
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>(
        (ref) => AppSettingsNotifier());
