import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:videoader/services/app_update.dart';

void main() {
  test('versions compare numerically, including prereleases and build metadata',
      () {
    expect(AppUpdate.compareVersions('v1.10.0', '1.9.9+1'), greaterThan(0));
    expect(AppUpdate.compareVersions('1.0.0', '1.0.0+99'), 0);
    expect(AppUpdate.compareVersions('1.0.0', '1.0.0-rc.1'), greaterThan(0));
    expect(
        AppUpdate.compareVersions('1.0.0-rc.10', '1.0.0-rc.2'), greaterThan(0));
    expect(() => AppUpdate.compareVersions('latest', '1.0.0'),
        throwsFormatException);
  });
  test('date releases and Flutter build numbers agree with installed version',
      () {
    expect(AppUpdate.compareVersions('v26.9.21', '26.9.21+4'), 0);
    expect(
        AppUpdate.compareVersions(' V26.10.1 ', '26.9.21+4'), greaterThan(0));
    expect(
        AppUpdate.compareVersions('26.9.21+10', '26.9.21+4'), greaterThan(0));
    expect(AppUpdate.versionStatus('v26.9.21', '26.9.22+5'), contains('高于'));
    expect(AppUpdate.versionStatus('v26.9.21', '26.9.21+4'), contains('已是最新'));
    expect(
        AppUpdate.releaseVersion(
            {'tag_name': 'Windows', 'name': 'Videoader v26.3.11 Windows'}),
        'v26.3.11');
    expect(() => AppUpdate.releaseVersion({'tag_name': 'Windows'}),
        throwsFormatException);
    expect(AppUpdate.releaseUrl({'tag_name': 'v26.9.21+4'}),
        endsWith('v26.9.21%2B4'));
  });
  test(
      'update source distinguishes release, missing release and network errors',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var status = 200;
    var body =
        '{"tag_name":"v1.2.0","body":"Changes","prerelease":false,"draft":false}';
    server.listen((request) async {
      request.response.statusCode = status;
      request.response.write(body);
      await request.response.close();
    });
    final endpoint = Uri.parse('http://127.0.0.1:${server.port}/latest');
    expect((await AppUpdate.check(endpoint: endpoint))?['tag_name'], 'v1.2.0');
    body = '{"tag_name":"Windows","name":"v26.9.21 Windows"}';
    expect((await AppUpdate.check(endpoint: endpoint))?['version'], 'v26.9.21');
    status = 404;
    expect(await AppUpdate.check(endpoint: endpoint), isNull);
    status = 403;
    await expectLater(
        AppUpdate.check(endpoint: endpoint), throwsA(isA<HttpException>()));
    status = 200;
    body = 'not json';
    await expectLater(
        AppUpdate.check(endpoint: endpoint), throwsFormatException);
  });
}
