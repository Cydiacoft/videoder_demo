import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../extensions/toolbox_extension.dart';
import 'pages/download_page.dart';
import 'pages/download_settings_page.dart';
import 'providers/download_provider.dart';
import 'providers/activity_provider.dart';

class YtDlpExtension extends ToolboxExtension {
  @override
  String get id => 'yt-dlp';
  @override
  String get name => 'yt-dlp 网络下载';
  @override
  String get description => '网络视频下载、批量链接、画质选择、Aria2 加速与 Cookie 管理。';
  @override
  List<ExtensionPage> get pages => [
        ExtensionPage(
            id: 'downloads',
            label: '网络下载',
            icon: Icons.download_outlined,
            build: () => const DownloadPage()),
        ExtensionPage(
            id: 'download-settings',
            label: '下载与 Cookie',
            icon: Icons.cookie_outlined,
            build: () => const DownloadSettingsPage()),
      ];
  @override
  bool isBusy(WidgetRef ref) =>
      (ref.exists(downloadProvider) &&
          ref.watch(downloadProvider).isDownloading) ||
      ref.watch(downloadMaintenanceProvider) ||
      ref.watch(downloadQueueProvider);
}
