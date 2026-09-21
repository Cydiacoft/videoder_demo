import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:videoader/services/audio_expert_command.dart';
import 'package:videoader/services/expert_command.dart';
import 'package:videoader/services/media_inspector.dart';
import 'package:videoader/services/tool_process.dart';

void main() {
  test(
      'audio wizard rejects invalid ranges, output extensions and MP3 sample rate',
      () {
    expect(
        () => AudioExpertCommand.build(
            preset: AudioPreset.trim,
            inputs: ['in.wav'],
            output: 'out.mp3',
            start: '2',
            end: '1'),
        throwsFormatException);
    expect(
        () => AudioExpertCommand.build(
            preset: AudioPreset.convert,
            inputs: ['in.wav'],
            output: 'out.mp3',
            sampleRate: 96000),
        throwsFormatException);
    expect(
        () => AudioExpertCommand.build(
            preset: AudioPreset.merge, inputs: ['in.wav'], output: 'out.mp3'),
        throwsFormatException);
    expect(
        () => AudioExpertCommand.build(
            preset: AudioPreset.convert, inputs: ['in.wav'], output: 'out.wav'),
        throwsFormatException);
  });
  final ffmpeg = Platform.environment['FFMPEG_TEST_PATH'];
  test('audio wizard converts trims joins and normalizes actual audio',
      () async {
    final dir = await Directory.systemTemp.createTemp('audio-wizard-');
    addTearDown(() => dir.delete(recursive: true));
    final inputs = <String>[];
    for (var i = 0; i < 2; i++) {
      final input = '${dir.path}/input$i.wav';
      inputs.add(input);
      final result = await runTool(ffmpeg!, [
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=${440 + i * 220}:sample_rate=${i == 0 ? 44100 : 48000}',
        '-t',
        '4',
        '-ac',
        '${i + 1}',
        input
      ]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
    }
    for (final preset in AudioPreset.values) {
      final output = '${dir.path}/${preset.name}.wav';
      final args = AudioExpertCommand.build(
          preset: preset,
          inputs: preset == AudioPreset.merge ? inputs : [inputs.first],
          output: output,
          format: 'wav',
          channels: 1,
          sampleRate: 48000,
          start: '1',
          end: '3');
      final result =
          await runTool(ffmpeg!, ExpertCommand.executionArguments(args));
      expect(result.exitCode, 0, reason: '${preset.name}: ${result.stderr}');
      final data = await MediaInspector.inspect(ffmpeg, output);
      final streams = data['streams'] as List;
      expect(streams.length, 1);
      expect(streams.single['codec_name'], 'pcm_s16le');
      expect(streams.single['sample_rate'], '48000');
      expect(streams.single['channels'], 1);
      expect(
          double.parse(data['format']['duration'] as String),
          closeTo(
              preset == AudioPreset.trim
                  ? 2
                  : preset == AudioPreset.merge
                      ? 8
                      : 4,
              0.1));
      if (preset == AudioPreset.normalize) {
        final measured = await runTool(ffmpeg, [
          '-i',
          output,
          '-af',
          'loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json',
          '-f',
          'null',
          '-'
        ]);
        final match = RegExp(r'"input_i"\s*:\s*"(-?[0-9.]+)"')
            .firstMatch(measured.stderr.toString());
        expect(match, isNotNull);
        expect(double.parse(match!.group(1)!), closeTo(-16, 1));
      }
    }
  },
      skip: ffmpeg == null
          ? 'Set FFMPEG_TEST_PATH for real audio checks'
          : false);
}
