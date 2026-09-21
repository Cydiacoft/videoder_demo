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
