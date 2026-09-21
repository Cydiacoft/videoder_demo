import 'package:flutter_test/flutter_test.dart';
import 'package:videoader/plugins/yt_dlp/services/browser_cookies.dart';
import 'package:videoader/plugins/yt_dlp/services/download_options.dart';

void main() {
  test('browser cookies use an explicit source and never export a cookies file',
      () {
    expect(BrowserCookies.enabled({}), isFalse);
    expect(BrowserCookies.arguments({}), isEmpty);
    expect(BrowserCookies.arguments({'cookie-browser': 'firefox'}),
        ['--cookies-from-browser', 'firefox']);
    final args = DownloadOptions.build(
        {'cookie-browser': 'edge', 'cookie-profile': r'C:\Browser Profile'});
    expect(args, contains(r'edge:C:\Browser Profile'));
    expect(args, isNot(contains('--cookies')));
    expect(() => BrowserCookies.arguments({'cookie-browser': 'unknown'}),
        throwsFormatException);
    expect(
        () => BrowserCookies.arguments(
            {'cookie-browser': 'chrome', 'cookie-profile': 'a\nb'}),
        throwsFormatException);
  });
}
