enum ExpertPreset {
  transcode,
  remux,
  resize,
  rotate,
  speed,
  subtitles,
  gif,
  merge
}

extension ExpertPresetInfo on ExpertPreset {
  String get label => [
        '自定义转码',
        '无损换封装',
        '缩放视频',
        '旋转视频',
        '调整速度',
        '封装字幕',
        '导出 GIF',
        '合并视频'
      ][index];
  String get hint => [
        '选择编码器和码率，或组合视频与音频滤镜。',
        '复制所有轨道，不重新编码。输出容器需兼容原轨道。',
        '默认缩放至 1280 像素宽，保持比例；可修改滤镜。',
        '默认顺时针旋转 90°；可改为 transpose=2 或 hflip。',
        '默认 2 倍速，视频与音频同步变速。',
        '第一个输入为视频，第二个为 SRT 字幕。保留可开关字幕轨道。',
        '默认导出 480 像素宽、15 fps 的循环 GIF，使用调色板优化。',
        '至少两个视频，按列表顺序合并。各段需含音轨且分辨率一致。',
      ][index];
}

class ArgumentCodec {
  // A predictable argv grammar, not a shell. Backslashes in Windows paths are preserved.
  static List<String> parse(String text) {
    final result = <String>[];
    var token = StringBuffer();
    String? quote;
    var started = false;
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (quote != null) {
        if (char == quote) {
          quote = null;
        } else if (char == '\\' && quote == '"') {
          var count = 1;
          while (i + 1 < text.length && text[i + 1] == '\\') {
            count++;
            i++;
          }
          if (i + 1 < text.length && text[i + 1] == '"') {
            token.write('\\' * (count ~/ 2));
            if (count.isOdd) {
              token.write('"');
            } else {
              quote = null;
            }
            i++;
          } else {
            token.write('\\' * count);
          }
        } else {
          token.write(char);
        }
      } else if (char == '"' || char == "'") {
        quote = char;
        started = true;
      } else if (RegExp(r'\s').hasMatch(char)) {
        if (started) {
          result.add(token.toString());
          token = StringBuffer();
          started = false;
        }
      } else {
        token.write(char);
        started = true;
      }
    }
    if (quote != null) throw const FormatException('参数中有未闭合的引号');
    if (started) result.add(token.toString());
    return result;
  }

  static String quote(String value) {
    final result = StringBuffer('"');
    var slashes = 0;
    for (final char in value.split('')) {
      if (char == '\\') {
        slashes++;
        continue;
      }
      if (char == '"') {
        result.write('\\' * (slashes * 2 + 1));
      } else {
        result.write('\\' * slashes);
      }
      result.write(char);
      slashes = 0;
    }
    result.write('\\' * (slashes * 2));
    result.write('"');
    return result.toString();
  }

  static String format(List<String> args) => args
      .map((v) =>
          v.isNotEmpty && !RegExp('[\\s"\'\\\\]').hasMatch(v) ? v : quote(v))
      .join(' ');
}

class ExpertCommand {
  static List<String> build(
      {required ExpertPreset preset,
      required List<String> inputs,
      required String output,
      String encoder = 'libx264',
      String audioEncoder = 'aac',
      String videoBitrate = '',
      String audioBitrate = '192k',
      String quality = '23',
      String encoderPreset = 'medium',
      String hwaccel = 'none',
      String videoFilter = '',
      String audioFilter = ''}) {
    if (inputs.isEmpty || inputs.any((p) => p.trim().isEmpty)) {
      throw const FormatException('请添加输入文件');
    }
    if (output.trim().isEmpty || inputs.contains(output)) {
      throw const FormatException('请选择不同于输入文件的输出路径');
    }
    if (preset == ExpertPreset.subtitles && inputs.length != 2) {
      throw const FormatException('字幕封装需要一个视频和一个字幕文件');
    }
    if (preset == ExpertPreset.merge && inputs.length < 2) {
      throw const FormatException('合并至少需要两个视频');
    }
    if (preset != ExpertPreset.subtitles &&
        preset != ExpertPreset.merge &&
        inputs.length != 1) {
      throw const FormatException('此预设需要单个输入；多输入可使用命令编辑模式');
    }
    final args = <String>[];
    for (final entry in inputs.asMap().entries) {
      final input = entry.value;
      if (hwaccel != 'none' &&
          preset != ExpertPreset.remux &&
          (preset != ExpertPreset.subtitles || entry.key == 0)) {
        args.addAll(['-hwaccel', hwaccel]);
      }
      args.addAll(['-i', input]);
    }
    if (preset == ExpertPreset.remux) {
      return [...args, '-map', '0', '-c', 'copy', output];
    }
    if (preset == ExpertPreset.gif) {
      if (videoFilter.isNotEmpty || audioFilter.isNotEmpty) {
        throw const FormatException('GIF 预设使用复杂滤镜，请生成命令后直接修改 filter_complex');
      }
      return [
        ...args,
        '-filter_complex',
        '[0:v:0]fps=15,scale=480:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse[gif]',
        '-map',
        '[gif]',
        '-an',
        '-loop',
        '0',
        output
      ];
    }
    for (final value in [
      if (encoder != 'copy') videoBitrate,
      if (!['copy', 'none', 'flac', 'pcm_s16le'].contains(audioEncoder))
        audioBitrate
    ]) {
      if (value.isNotEmpty &&
          !RegExp(r'^\d+(\.\d+)?[kKmM]?$').hasMatch(value)) {
        throw const FormatException('码率格式示例：5M、2500k、192k');
      }
    }
    if (preset == ExpertPreset.merge &&
        (encoder == 'copy' ||
            audioEncoder == 'copy' ||
            audioEncoder == 'none')) {
      throw const FormatException('合并预设需要重新编码视频和音频，请选择编码器');
    }
    if (preset == ExpertPreset.merge) {
      if (videoFilter.isNotEmpty || audioFilter.isNotEmpty) {
        throw const FormatException('合并预设使用复杂滤镜，请生成命令后直接修改 filter_complex');
      }
      final graph = <String>[];
      for (var i = 0; i < inputs.length; i++) {
        graph.add('[$i:v:0]setpts=PTS-STARTPTS[v$i]');
        graph.add('[$i:a:0]asetpts=PTS-STARTPTS[a$i]');
      }
      graph.add(
          '${List.generate(inputs.length, (i) => '[v$i][a$i]').join()}concat=n=${inputs.length}:v=1:a=1[v][a]');
      args.addAll(
          ['-filter_complex', graph.join(';'), '-map', '[v]', '-map', '[a]']);
    } else {
      args.addAll(['-map', '0:v:0', '-map', '0:a:0?']);
      if (preset == ExpertPreset.subtitles) {
        args.addAll([
          '-map',
          '1:0',
          '-c:s',
          output.toLowerCase().endsWith('.mp4') ||
                  output.toLowerCase().endsWith('.mov')
              ? 'mov_text'
              : 'srt'
        ]);
      }
      final vf = videoFilter.trim().isNotEmpty
          ? videoFilter.trim()
          : switch (preset) {
              ExpertPreset.resize => 'scale=1280:-2',
              ExpertPreset.rotate => 'transpose=1',
              ExpertPreset.speed => 'setpts=PTS/2',
              _ => ''
            };
      final af = audioFilter.trim().isNotEmpty
          ? audioFilter.trim()
          : preset == ExpertPreset.speed
              ? 'atempo=2'
              : '';
      if (encoder == 'copy' && vf.isNotEmpty) {
        throw const FormatException('视频流复制不能同时使用视频滤镜');
      }
      if (audioEncoder == 'copy' && af.isNotEmpty) {
        throw const FormatException('音频流复制不能同时使用音频滤镜');
      }
      if (vf.isNotEmpty) args.addAll(['-vf', vf]);
      if (af.isNotEmpty && audioEncoder != 'none') args.addAll(['-af', af]);
    }
    args.addAll(['-c:v', encoder]);
    if (encoder != 'copy') {
      if (videoBitrate.isNotEmpty) {
        args.addAll(['-b:v', videoBitrate]);
      } else if (['libx264', 'libx265', 'libaom-av1', 'libsvtav1', 'libvpx-vp9']
          .contains(encoder)) {
        final q = int.tryParse(quality);
        if (q == null ||
            q < 0 ||
            q > (encoder == 'libx264' || encoder == 'libx265' ? 51 : 63)) {
          throw const FormatException('请输入编码器支持的 CRF 数值');
        }
        args.addAll(['-crf', quality]);
        if (encoder == 'libaom-av1' || encoder == 'libvpx-vp9') {
          args.addAll(['-b:v', '0']);
        }
      }
      if (['libx264', 'libx265'].contains(encoder)) {
        args.addAll(['-preset', encoderPreset, '-pix_fmt', 'yuv420p']);
      }
    }
    if (audioEncoder == 'none') {
      args.add('-an');
    } else {
      args.addAll(['-c:a', audioEncoder]);
      if (audioEncoder != 'copy' &&
          audioEncoder != 'flac' &&
          audioEncoder != 'pcm_s16le' &&
          audioBitrate.isNotEmpty) {
        args.addAll(['-b:a', audioBitrate]);
      }
    }
    args.add(output);
    return args;
  }

  static List<String> executionArguments(List<String> args,
      {bool overwrite = false}) {
    if (args.isEmpty) throw const FormatException('请输入 FFmpeg 参数');
    if (args.any((arg) => [
          '-y',
          '-n',
          '-stdin',
          '-nostdin',
          '-progress',
          '-stats',
          '-nostats'
        ].contains(arg))) {
      throw const FormatException(
          '覆盖、交互和进度选项由工作台管理，请从参数中移除 -y/-n/-stdin/-progress/-stats 等选项');
    }
    return [
      '-hide_banner',
      '-nostdin',
      overwrite ? '-y' : '-n',
      '-progress',
      'pipe:1',
      '-nostats',
      ...args
    ];
  }
}
