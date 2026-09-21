import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

String resolveExecutable(String configured, String tool) {
  final value = configured.trim();
  return Directory(value).existsSync()
      ? p.join(value, Platform.isWindows ? '$tool.exe' : tool)
      : value;
}

Future<ProcessResult> runTool(String executable, List<String> arguments,
    {Duration timeout = const Duration(seconds: 15)}) async {
  final process = await Process.start(executable, arguments);
  final stdout =
      process.stdout.transform(const Utf8Decoder(allowMalformed: true)).join();
  final stderr =
      process.stderr.transform(const Utf8Decoder(allowMalformed: true)).join();
  try {
    final code = await process.exitCode.timeout(timeout);
    return ProcessResult(process.pid, code, await stdout, await stderr);
  } on TimeoutException {
    process.kill();
    throw TimeoutException('工具执行超时，请检查路径或网络连接');
  }
}
