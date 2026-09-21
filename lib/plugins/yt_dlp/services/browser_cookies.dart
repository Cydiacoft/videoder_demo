class BrowserCookies {
  static const browsers = {
    'files': '手动导入的 Cookie',
    'firefox': 'Firefox',
    'edge': 'Microsoft Edge',
    'chrome': 'Google Chrome',
    'brave': 'Brave',
    'chromium': 'Chromium',
    'opera': 'Opera',
    'vivaldi': 'Vivaldi',
    'safari': 'Safari（macOS）'
  };
  static bool enabled(Map<String, String> options) =>
      (options['cookie-browser'] ?? 'files') != 'files';
  static List<String> arguments(Map<String, String> options) {
    final browser = options['cookie-browser'] ?? 'files';
    if (!browsers.containsKey(browser)) {
      throw const FormatException('不支持的 Cookie 浏览器');
    }
    if (browser == 'files') return [];
    final profile = (options['cookie-profile'] ?? '').trim();
    if (profile.contains('\n') || profile.contains('\r')) {
      throw const FormatException('浏览器配置不能包含换行');
    }
    return [
      '--cookies-from-browser',
      profile.isEmpty ? browser : '$browser:$profile'
    ];
  }
}
