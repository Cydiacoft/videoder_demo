import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:videoader/plugins/yt_dlp/pages/download_options_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videoader/plugins/yt_dlp/services/download_options.dart';
import 'package:videoader/plugins/yt_dlp/providers/download_provider.dart';

void main() {
  testWidgets('parameter editor applies quoted custom arguments and toggles',
      (tester) async {
    Map<String, String>? saved;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: DownloadOptionsPanel(
                    options: const {},
                    busy: false,
                    onApply: (value) async {
                      saved = value;
                    })))));
    await tester.tap(find.text('下载参数'));
    await tester.pumpAndSettle();
    final custom = find.widgetWithText(TextFormField, '自定义 yt-dlp 参数');
    await tester.ensureVisible(custom);
    await tester.enterText(custom, '--retries 7');
    await tester.ensureVisible(find.text('应用参数'));
    await tester.tap(find.text('应用参数'));
    await tester.pumpAndSettle();
    expect(saved?['custom'], '--retries 7');
    expect(find.text('下载参数已应用'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('advanced arguments preserve quoted values and validate numbers', () {
    final args = DownloadOptions.build({
      'format': 'bv*[height<=2160]+ba/b',
      'merge-output-format': 'mkv',
      'write-subs': 'true',
      'sub-langs': 'zh.*,en',
      'yes-playlist': 'true',
      'concurrent-fragments': '4',
      'retries': 'infinite',
      'custom': '--add-header "X-Test: value with spaces" --no-write-subs',
    });
    expect(args, containsAllInOrder(['--format', 'bv*[height<=2160]+ba/b']));
    expect(args, contains('--yes-playlist'));
    expect(args, contains('X-Test: value with spaces'));
    expect(args.last, '--no-write-subs');
    expect(DownloadOptions.build({}), ['--no-playlist']);
    expect(() => DownloadOptions.build({'concurrent-fragments': '0'}),
        throwsFormatException);
    expect(() => DownloadOptions.build({'custom': '"open'}),
        throwsFormatException);
  });
  test('download options persist and survive unrelated settings changes',
      () async {
    SharedPreferences.setMockInitialValues({});
    final settings = DownloadSettingsNotifier();
    await settings.ready;
    await settings.setOptions({'write-subs': 'true', 'limit-rate': '5M'});
    await settings.setQuality(VideoQuality.p1080);
    expect(settings.state.options['limit-rate'], '5M');
    settings.dispose();
    final restored = DownloadSettingsNotifier();
    await restored.ready;
    expect(restored.state.options['write-subs'], 'true');
    restored.dispose();
  });
}
