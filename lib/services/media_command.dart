enum MediaOperation { convert, audio, compress, trim }

extension MediaOperationLabel on MediaOperation {
  String get label => ['格式转换', '提取音频', '视频压缩', '视频剪切'][index];
}

class MediaFormat {
  final String extension;
  final String description;
  final String videoLabel;
  final String audioLabel;
  const MediaFormat(
      this.extension, this.description, this.videoLabel, this.audioLabel);

  static const video = [
    MediaFormat('mp4', '兼容大多数设备', 'H.264', 'AAC · 192 kbps'),
    MediaFormat('mkv', '灵活的媒体容器', 'H.264', 'AAC · 192 kbps'),
    MediaFormat('mov', '常用剪辑容器', 'H.264', 'AAC · 192 kbps'),
    MediaFormat('webm', '适合网页播放，VP9 编码耗时较长', 'VP9', 'Opus · 128 kbps'),
    MediaFormat('avi', '兼容传统播放器与旧设备', 'MPEG-4 Part 2', 'MP3 · 192 kbps'),
    MediaFormat('flv', '传统 Flash 视频容器', 'H.264', 'AAC · 192 kbps'),
    MediaFormat('ts', 'MPEG 传输流，适合广播与流媒体流程', 'H.264', 'AAC · 192 kbps'),
  ];
  static const audio = [
    MediaFormat('mp3', '通用音频格式', '不保留视频', 'MP3 · 192 kbps'),
    MediaFormat('m4a', '高效 AAC 音频', '不保留视频', 'AAC · 192 kbps'),
    MediaFormat('flac', '无损压缩，适合音乐收藏；不会恢复源文件已丢失的音质', '不保留视频', 'FLAC · 16 bit'),
    MediaFormat('wav', '无损 PCM 音频', '不保留视频', 'PCM · 16 bit'),
  ];
}

class MediaCommand {
  static double parseTime(String value) {
    final parts = value.trim().split(':');
    if (parts.isEmpty || parts.length > 3) {
      throw const FormatException('时间格式应为秒数或 HH:MM:SS');
    }
    double seconds = 0;
    for (var i = 0; i < parts.length; i++) {
      final number = double.tryParse(parts[i]);
      if (number == null ||
          !number.isFinite ||
          number < 0 ||
          (parts.length > 1 && i > 0 && number >= 60) ||
          (i < parts.length - 1 && number != number.truncateToDouble())) {
        throw const FormatException('请输入有效时间，例如 00:01:30 或 90.5');
      }
      seconds = seconds * 60 + number;
    }
    return seconds;
  }

  static List<String> build({
    required MediaOperation operation,
    required String input,
    required String output,
    String format = 'mp4',
    int crf = 28,
    int audioBitrate = 192,
    String start = '0',
    String end = '10',
  }) {
    if (input.isEmpty || output.isEmpty || input == output) {
      throw const FormatException('输入和输出必须是不同的文件');
    }
    final supported = operation == MediaOperation.audio
        ? MediaFormat.audio
        : operation == MediaOperation.convert
            ? [...MediaFormat.video, ...MediaFormat.audio]
            : MediaFormat.video;
    if (!supported.any((item) => item.extension == format)) {
      throw const FormatException('不支持的输出格式');
    }
    final args = ['-hide_banner', '-nostdin', '-n', '-i', input];
    if (operation == MediaOperation.trim) {
      final from = parseTime(start);
      final to = parseTime(end);
      if (to <= from) throw const FormatException('结束时间必须晚于开始时间');
      args.addAll(['-ss', '$from', '-t', '${to - from}']);
    }
    if (MediaFormat.audio.any((item) => item.extension == format)) {
      if (![128, 192, 256, 320].contains(audioBitrate)) {
        throw const FormatException('音频码率应为 128、192、256 或 320 kbps');
      }
      args.addAll(['-map', '0:a:0', '-vn']);
      args.addAll(switch (format) {
        'mp3' => ['-c:a', 'libmp3lame', '-b:a', '${audioBitrate}k'],
        'm4a' => ['-c:a', 'aac', '-b:a', '${audioBitrate}k'],
        'flac' => ['-c:a', 'flac', '-sample_fmt', 's16'],
        _ => ['-c:a', 'pcm_s16le'],
      });
    } else {
      if (crf < 18 || crf > 35) throw const FormatException('压缩质量应在 18–35 之间');
      args.addAll([
        '-map',
        '0:v:0',
        '-map',
        '0:a:0?',
        '-vf',
        'pad=ceil(iw/2)*2:ceil(ih/2)*2',
        '-pix_fmt',
        'yuv420p',
      ]);
      switch (format) {
        case 'webm':
          args.addAll([
            '-c:v',
            'libvpx-vp9',
            '-crf',
            '30',
            '-b:v',
            '0',
            '-deadline',
            'good',
            '-cpu-used',
            '2',
            '-c:a',
            'libopus',
            '-b:a',
            '128k'
          ]);
        case 'avi':
          args.addAll([
            '-c:v',
            'mpeg4',
            '-q:v',
            '3',
            '-c:a',
            'libmp3lame',
            '-b:a',
            '192k'
          ]);
        default:
          args.addAll([
            '-c:v',
            'libx264',
            '-preset',
            'medium',
            '-crf',
            operation == MediaOperation.compress ? '$crf' : '23',
            '-c:a',
            'aac',
            '-b:a',
            '192k'
          ]);
      }
      if (format == 'mp4' || format == 'mov') {
        args.addAll(['-movflags', '+faststart']);
      }
    }
    args.addAll(['-progress', 'pipe:1', '-nostats', output]);
    return args;
  }
}
