import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:videoader/plugins/yt_dlp/services/video_download.dart';
import 'package:videoader/services/tool_process.dart';

void main() {
  test('video selection always requests audio and tracks final merged paths',
      () {
    expect(VideoDownload.selector(null),
        'bestvideo+bestaudio/best[vcodec!=none][acodec!=none]');
    expect(VideoDownload.selector(2160),
        contains('bestvideo[height<=2160]+bestaudio'));
    const path = r'C:\Downloads\成品 with spaces.mkv';
    expect(
        VideoDownload.outputPaths(
            'progress\n${VideoDownload.marker}${jsonEncode(path)}\n'),
        [path]);
    expect(VideoDownload.outputPaths('already in archive'), isEmpty);
  });
  final ffmpeg = Platform.environment['FFMPEG_TEST_PATH'];
  test('video-only file fails verification, merged video and audio passes',
      () async {
    final temp = await Directory.systemTemp.createTemp('video-download-');
    addTearDown(() => temp.delete(recursive: true));
    final silent = '${temp.path}/silent.mp4';
    final sound = '${temp.path}/audio.m4a';
    final merged = '${temp.path}/final.mkv';
    final video = await runTool(ffmpeg!, [
      '-f',
      'lavfi',
      '-i',
      'testsrc2=size=128x96:rate=12',
      '-t',
      '1',
      '-c:v',
      'libx264',
      '-an',
      silent
    ]);
    expect(video.exitCode, 0);
    await expectLater(
        VideoDownload.verify(ffmpeg, silent), throwsFormatException);
    final audio = await runTool(ffmpeg, [
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=440',
      '-t',
      '1',
      '-c:a',
      'aac',
      sound
    ]);
    expect(audio.exitCode, 0);
    final result = await runTool(ffmpeg, [
      '-i',
      silent,
      '-i',
      sound,
      '-map',
      '0:v:0',
      '-map',
      '1:a:0',
      '-c',
      'copy',
      merged
    ]);
    expect(result.exitCode, 0);
    await VideoDownload.verify(ffmpeg, merged);
  }, skip: ffmpeg == null ? 'Set FFMPEG_TEST_PATH to verify streams' : false);
}
