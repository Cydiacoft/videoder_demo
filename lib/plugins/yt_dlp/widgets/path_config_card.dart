import 'dart:io';

import 'package:flutter/material.dart';

class PathConfigCard extends StatelessWidget {
  final String title;
  final String description;
  final String? currentPath;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDirectory;
  final VoidCallback? onClear;

  const PathConfigCard({
    super.key,
    required this.title,
    required this.description,
    required this.currentPath,
    required this.icon,
    required this.onTap,
    this.isDirectory = false,
    this.onClear,
  });

  Future<void> _openFolder(BuildContext context) async {
    if (currentPath == null || currentPath!.isEmpty) return;

    try {
      if (Platform.isWindows) {
        await Process.run('explorer',
            [isDirectory ? currentPath! : File(currentPath!).parent.path]);
      } else if (Platform.isMacOS) {
        await Process.run('open',
            [isDirectory ? currentPath! : File(currentPath!).parent.path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open',
            [isDirectory ? currentPath! : File(currentPath!).parent.path]);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('无法打开: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSet = currentPath != null && currentPath!.isNotEmpty;
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
      title: Text(title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: Text(isSet ? currentPath! : description,
          maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (onClear != null)
          IconButton(
              tooltip: '清除路径',
              onPressed: onClear,
              icon: const Icon(Icons.close, size: 16)),
        if (isSet)
          IconButton(
              tooltip: '打开所在目录',
              onPressed: () => _openFolder(context),
              icon: const Icon(Icons.folder_open, size: 16)),
        OutlinedButton(onPressed: onTap, child: const Text('浏览…')),
      ]),
    );
  }
}
