import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:videoader/services/expert_command.dart';
import 'package:videoader/services/media_inspector.dart';
import 'package:videoader/services/tool_process.dart';
import 'package:videoader/providers/media_provider.dart';

void main() {
  test('argument editor roundtrips Windows paths, filters and shell literals',
      () {
    final args = [
      '-i',
      r'C:\files with spaces\video & test.mp4',
      '-vf',
      'drawtext=text=\'hello "world"\'',
      '-metadata',
      r'title=$(echo nope); & |',
      '',
      r'\\server\share\video.mp4',
      'C:\\trailing\\'
    ];
    expect(ArgumentCodec.parse(ArgumentCodec.format(args)), args);
    expect(ArgumentCodec.parse(r'-i "C:\files with spaces\video.mp4"'),
        ['-i', r'C:\files with spaces\video.mp4']);
    expect(ArgumentCodec.parse(r'-i "\\server\share\video.mp4"'),
        ['-i', r'\\server\share\video.mp4']);
    expect(() => ArgumentCodec.parse('-i "unfinished'), throwsFormatException);
    expect(() => ExpertCommand.executionArguments(['-i', 'x', '-y', 'out']),
        throwsFormatException);
  });
  test('professional settings preserve rate, filters and hardware placement',
      () {
    final args = ExpertCommand.build(
        preset: ExpertPreset.transcode,
        inputs: ['in.mp4'],
        output: 'out.mp4',
        encoder: 'h264_nvenc',
        hwaccel: 'cuda',
        videoBitrate: '5M',
        videoFilter: 'scale=640:-2',
        audioFilter: 'volume=0.8');
    expect(args.indexOf('-hwaccel'), lessThan(args.indexOf('-i')));
    expect(
        args, containsAll(['h264_nvenc', '5M', 'scale=640:-2', 'volume=0.8']));
    expect(args, isNot(contains('-crf')));
    expect(
        () => ExpertCommand.build(
            preset: ExpertPreset.transcode,
            inputs: ['a'],
            output: 'b',
            encoder: 'copy',
            videoFilter: 'scale=10:10'),
        throwsFormatException);
    expect(
        () => ExpertCommand.build(
            preset: ExpertPreset.merge, inputs: ['a'], output: 'b'),
        throwsFormatException);
  });
  final ffmpeg = Platform.environment['FFMPEG_TEST_PATH'];
  test('all expert presets and custom commands produce verifiable media',
      () async {
    final temp = await Directory.systemTemp.createTemp('videoader-expert-');
    addTearDown(() => temp.delete(recursive: true));
    final source = '${temp.path}/input test.mp4';
    final created = await runTool(ffmpeg!, [
      '-f',
      'lavfi',
      '-i',
      'testsrc2=size=128x96:rate=12',
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=440',
      '-t',
      '2',
      '-c:v',
      'libx264',
      '-c:a',
      'aac',
      source
    ]);
    expect(created.exitCode, 0, reason: '${created.stderr}');
    final subtitles = '${temp.path}/captions.srt';
    await File(subtitles)
        .writeAsString('1\n00:00:00,000 --> 00:00:01,500\nExample subtitle\n');
    for (final preset in ExpertPreset.values) {
      final output =
          '${temp.path}/${preset.name}.${preset == ExpertPreset.gif ? 'gif' : 'mkv'}';
      final inputs = preset == ExpertPreset.merge
          ? [source, source]
          : preset == ExpertPreset.subtitles
              ? [source, subtitles]
              : [source];
      final args =
          ExpertCommand.build(preset: preset, inputs: inputs, output: output);
      final result = await runTool(
          ffmpeg,
          ExpertCommand.executionArguments(
              ArgumentCodec.parse(ArgumentCodec.format(args))),
          timeout: const Duration(seconds: 45));
      expect(result.exitCode, 0, reason: '${preset.name}: ${result.stderr}');
      final data = await MediaInspector.inspect(ffmpeg, output);
      final streams = data['streams'] as List;
      final video =
          streams.firstWhere((s) => s['codec_type'] == 'video') as Map;
      final duration = double.parse(data['format']['duration'] as String);
      if (preset == ExpertPreset.resize) expect(video['width'], 1280);
      if (preset == ExpertPreset.rotate) {
        expect(video['width'], 96);
        expect(video['height'], 128);
      }
      if (preset == ExpertPreset.speed) expect(duration, lessThan(1.4));
      if (preset == ExpertPreset.subtitles) {
        expect(streams.any((s) => s['codec_type'] == 'subtitle'), isTrue);
      }
      if (preset == ExpertPreset.gif) {
        expect(video['codec_name'], 'gif');
        expect(video['width'], 480);
      }
      if (preset == ExpertPreset.merge) expect(duration, closeTo(4, 0.2));
    }
    final caps = await MediaInspector.capabilities(ffmpeg);
    expect(caps.video, contains('libx264'));
    expect(caps.audio, contains('aac'));
    final runner = MediaNotifier();
    addTearDown(runner.dispose);
    final output = '${temp.path}/custom.mp4';
    final command = [
      '-i',
      source,
      '-vf',
      'scale=64:48',
      '-c:v',
      'libx264',
      '-an',
      output
    ];
    await runner.runArguments(executable: ffmpeg, arguments: command);
    expect(runner.state.status, '命令执行完成');
    expect(
        (await MediaInspector.inspect(ffmpeg, output))['streams'][0]['width'],
        64);
    final originalSize = await File(output).length();
    await runner.runArguments(executable: ffmpeg, arguments: command);
    expect(runner.state.status, contains('失败'));
    expect(await File(output).length(), originalSize);
  },
      skip:
          ffmpeg == null ? 'Set FFMPEG_TEST_PATH for real media tests' : false);
}
