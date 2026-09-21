import 'package:flutter_riverpod/flutter_riverpod.dart';

final downloadMaintenanceProvider = StateProvider<bool>((ref) => false);
final downloadQueueProvider = StateProvider<bool>((ref) => false);
