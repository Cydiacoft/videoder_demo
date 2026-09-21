import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:videoader/plugins/yt_dlp/services/download_progress.dart';
import 'package:videoader/widgets/task_status_bar.dart';

void main() {
  test('structured progress handles known, estimated and missing totals', () {
    DownloadProgress parse(Map<String, dynamic> data) => DownloadProgress.parse(
        '${DownloadProgress.marker}${jsonEncode(data)}')!;
    final known = parse({
      'downloaded_bytes': 50,
      'total_bytes': 100,
      'speed': 2097152,
      'eta': 12
    });
    expect(known.fraction, .5);
    expect(known.speed, '2.00 MiB/s');
    expect(known.eta, '12 秒');
    expect(
        parse({
          'downloaded_bytes': 50,
          'total_bytes': 'NA',
          'total_bytes_estimate': 200
        }).fraction,
        .25);
    expect(parse({'total_bytes': 0, 'eta': 'NA'}).fraction, isNull);
    expect(
        parse({
          'status': 'finished',
          'downloaded_bytes': 100,
          'total_bytes': 100
        }).stage,
        contains('等待后续处理'));
    expect(DownloadProgress.parse('${DownloadProgress.marker}broken'), isNull);
  });
  test('Aria2 and postprocessing do not retain stale ETA or completion', () {
    final aria = DownloadProgress.parse(
        '[#abc 50MiB/100MiB(50%) CN:16 DL:2MiB ETA:25s]')!;
    expect(aria.fraction, .5);
    expect(aria.eta, '25s');
    final merge =
        DownloadProgress.parse('${DownloadProgress.postMarker}"Merger"')!;
    expect(merge.stage, '正在合并音视频');
    expect(merge.fraction, isNull);
    expect(merge.eta, isEmpty);
    expect(
        DownloadProgress.parse('[Merger] Merging formats')!.stage, merge.stage);
  });
  testWidgets(
      'status remains visible through downloading, merging and completion without logs',
      (tester) async {
    Future<void> show(String stage, bool running, {double? fraction}) =>
        tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: TaskStatusBar(
                    status: stage,
                    running: running,
                    fraction: fraction,
                    details: running && fraction != null
                        ? '2 MiB/s · ETA 12 秒'
                        : ''))));
    await show('正在下载', true, fraction: .5);
    expect(find.text('50.0%'), findsOneWidget);
    expect(find.text('2 MiB/s · ETA 12 秒'), findsOneWidget);
    await show('正在合并音视频', true);
    expect(find.text('正在合并音视频'), findsOneWidget);
    expect(
        tester
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator))
            .value,
        isNull);
    await show('下载完成', false);
    expect(find.text('下载完成'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
