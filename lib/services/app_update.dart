import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

class AppUpdate {
  static const repository = 'https://github.com/Cydiacoft/videoder_demo';
  static Future<String> currentVersion() async {
    final manifest = await rootBundle.loadString('pubspec.yaml');
    final match =
        RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(manifest);
    if (match == null) throw const FormatException('无法读取当前版本');
    return match.group(1)!;
  }

  static int compareVersions(String a, String b) {
    List<String> parts(String value) {
      final match = RegExp(
              r'^v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$')
          .firstMatch(value);
      if (match == null) throw FormatException('无法识别版本号：$value');
      return [match[1]!, match[2]!, match[3]!, match[4] ?? ''];
    }

    final left = parts(a), right = parts(b);
    for (var i = 0; i < 3; i++) {
      final difference = int.parse(left[i]).compareTo(int.parse(right[i]));
      if (difference != 0) return difference;
    }
    if (left[3] == right[3]) return 0;
    if (left[3].isEmpty) return 1;
    if (right[3].isEmpty) return -1;
    final lp = left[3].split('.'), rp = right[3].split('.');
    for (var i = 0; i < lp.length && i < rp.length; i++) {
      final ln = int.tryParse(lp[i]), rn = int.tryParse(rp[i]);
      final result = ln != null && rn != null
          ? ln.compareTo(rn)
          : ln != null
              ? -1
              : rn != null
                  ? 1
                  : lp[i].compareTo(rp[i]);
      if (result != 0) return result;
    }
    return lp.length.compareTo(rp.length);
  }

  static Future<Map<String, dynamic>?> check({Uri? endpoint}) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client
          .getUrl(endpoint ??
              Uri.parse(
                  'https://api.github.com/repos/Cydiacoft/videoder_demo/releases/latest'))
          .timeout(const Duration(seconds: 15));
      request.headers.set('User-Agent', 'Videoader-update-check');
      request.headers.set('Accept', 'application/vnd.github+json');
      final response =
          await request.close().timeout(const Duration(seconds: 15));
      if (response.statusCode == 404) return null;
      if (response.statusCode == 403 || response.statusCode == 429) {
        throw const HttpException('更新服务暂时限流，请稍后重试');
      }
      if (response.statusCode != 200) {
        throw HttpException('检查失败（HTTP ${response.statusCode}）');
      }
      final text = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(text) as Map<String, dynamic>;
      if (data['draft'] == true || data['prerelease'] == true) return null;
      compareVersions(data['tag_name'] as String, '0.0.0');
      return data;
    } finally {
      client.close(force: true);
    }
  }
}
