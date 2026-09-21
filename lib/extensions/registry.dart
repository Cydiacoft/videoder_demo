import '../plugins/yt_dlp/yt_dlp_extension.dart';
import 'toolbox_extension.dart';

// Compile-time registry: the host depends on the extension interface only.
// Add future built-in extensions here; executable binaries are managed by each extension.
final List<ToolboxExtension> bundledExtensions = [YtDlpExtension()];
