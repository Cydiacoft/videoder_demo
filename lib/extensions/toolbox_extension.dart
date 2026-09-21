import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExtensionPage {
  final String id;
  final String label;
  final IconData icon;
  final Widget Function() build;
  const ExtensionPage(
      {required this.id,
      required this.label,
      required this.icon,
      required this.build});
}

abstract class ToolboxExtension {
  String get id;
  String get name;
  String get description;
  List<ExtensionPage> get pages;
  bool isBusy(WidgetRef ref);
}

class ExtensionState {
  final bool loaded;
  final Set<String> enabled;
  const ExtensionState({this.loaded = false, this.enabled = const {}});
}

class ExtensionManager extends StateNotifier<ExtensionState> {
  ExtensionManager() : super(const ExtensionState()) {
    ready = _load();
  }
  late final Future<void> ready;
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('enabled_extensions');
    // Preserve the downloader for existing installations; new installs start with FFmpeg only.
    final enabled = saved?.toSet() ??
        (prefs.containsKey('yt_dlp_path') ? {'yt-dlp'} : <String>{});
    if (mounted) state = ExtensionState(loaded: true, enabled: enabled);
  }

  Future<void> setEnabled(String id, bool value) async {
    await ready;
    final enabled = {...state.enabled};
    if (value) {
      enabled.add(id);
    } else {
      enabled.remove(id);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('enabled_extensions', enabled.toList());
    if (mounted) state = ExtensionState(loaded: true, enabled: enabled);
  }
}

final extensionManagerProvider =
    StateNotifierProvider<ExtensionManager, ExtensionState>(
        (ref) => ExtensionManager());
