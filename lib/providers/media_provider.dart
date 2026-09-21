import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../services/media_command.dart';
import '../services/expert_command.dart';
import '../services/tool_process.dart';

class MediaState {
  final bool running;
  final String status;
  final String? output;
  final List<String> logs;
  const MediaState(
      {this.running = false,
      this.status = '等待处理',
      this.output,
      this.logs = const []});
}

final mediaOperationProvider =
    StateProvider<MediaOperation>((ref) => MediaOperation.convert);
final mediaProvider =
    StateNotifierProvider<MediaNotifier, MediaState>((ref) => MediaNotifier());

class MediaNotifier extends StateNotifier<MediaState> {
  MediaNotifier() : super(const MediaState());
  Process? _process;
  bool _cancelled = false;
  void _log(String line) {
    if (!mounted) return;
    state = MediaState(
        running: state.running,
        status: state.status,
        output: state.output,
        logs: [...state.logs, line]
            .skip(state.logs.length >= 300 ? state.logs.length - 299 : 0)
            .toList());
  }

  void _begin() {
    _cancelled = false;
    state = const MediaState(running: true, status: '准备处理');
  }

  void _error(Object error) {
    if (mounted) {
      state = MediaState(status: '处理失败', logs: [...state.logs, '$error']);
    }
  }

  void _finish() {
    _process = null;
    if (mounted && state.running) {
      state = MediaState(status: '已取消', logs: state.logs);
    }
  }

  Future<void> run(
      {required String executable,
      required MediaOperation operation,
      required String input,
      required String directory,
      required String format,
      int audioBitrate = 192,
      required int crf,
      required String start,
      required String end}) async {
    if (state.running) return;
    _begin();
    try {
      if (executable.trim().isEmpty) {
        throw const FormatException('请先在设置中配置 FFmpeg');
      }
      if (!await File(input).exists()) {
        throw const FormatException('请选择存在的本地媒体文件');
      }
      if (directory.trim().isEmpty) throw const FormatException('请选择输出目录');
      final argsFormat = operation == MediaOperation.compress ||
              operation == MediaOperation.trim
          ? 'mp4'
          : format;
      final output = p.join(p.absolute(directory),
          '${p.basenameWithoutExtension(input)}_${operation.name}_${DateTime.now().microsecondsSinceEpoch}.$argsFormat');
      final args = MediaCommand.build(
          operation: operation,
          input: p.absolute(input),
          output: output,
          format: argsFormat,
          audioBitrate: audioBitrate,
          crf: crf,
          start: start,
          end: end);
      await Directory(directory).create(recursive: true);
      await _execute(executable, args, output: output);
    } catch (e) {
      _error(e);
    } finally {
      _finish();
    }
  }

  Future<void> runArguments(
      {required String executable,
      required List<String> arguments,
      bool overwrite = false}) async {
    if (state.running) return;
    _begin();
    try {
      if (executable.trim().isEmpty) throw const FormatException('请先配置 FFmpeg');
      await _execute(executable,
          ExpertCommand.executionArguments(arguments, overwrite: overwrite));
    } catch (e) {
      _error(e);
    } finally {
      _finish();
    }
  }

  Future<void> _execute(String executable, List<String> args,
      {String? output}) async {
    if (_cancelled || !mounted) return;
    _log('FFmpeg ${ArgumentCodec.format(args)}');
    final process =
        await Process.start(resolveExecutable(executable, 'ffmpeg'), args);
    _process = process;
    if (_cancelled || !mounted) process.kill();
    var producedMedia = false;
    var refusedOverwrite = false;
    final streams = [
      process.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .forEach((line) {
        if (!mounted) return;
        if (line.startsWith('out_time_us=')) {
          producedMedia =
              (int.tryParse(line.substring(12)) ?? 0) > 0 || producedMedia;
        }
        if (line.startsWith('out_time=')) {
          state = MediaState(
              running: true,
              status: '已处理 ${line.substring(9)}',
              logs: state.logs);
        } else if (!RegExp(
                r'^(frame|fps|stream_\d+_\d+_q|bitrate|total_size|out_time_us|out_time_ms|dup_frames|drop_frames|speed|progress)=')
            .hasMatch(line)) {
          _log(line);
        }
      }),
      process.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .forEach((line) {
        if (line.contains('Not overwriting') ||
            line.contains('already exists. Exiting')) {
          refusedOverwrite = true;
        }
        _log(line);
      }),
    ];
    final code = await process.exitCode;
    await Future.wait(streams);
    if (!mounted) return;
    final success = !refusedOverwrite &&
        !_cancelled &&
        code == 0 &&
        (output == null ||
            (producedMedia &&
                await File(output).exists() &&
                await File(output).length() > 0));
    state = MediaState(
        status: _cancelled
            ? '已取消（可能保留未完成文件）'
            : success
                ? output == null
                    ? '命令执行完成'
                    : '处理完成'
                : '执行失败或没有输出媒体（退出码 $code）',
        output: success ? output : null,
        logs: state.logs);
  }

  void cancel() {
    if (!state.running) return;
    _cancelled = true;
    _process?.kill();
  }

  @override
  void dispose() {
    _cancelled = true;
    _process?.kill();
    super.dispose();
  }
}
