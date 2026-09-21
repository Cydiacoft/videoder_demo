import 'package:flutter/material.dart';

/// Always visible above diagnostic logs, including after the task finishes.
class TaskStatusBar extends StatelessWidget {
  const TaskStatusBar(
      {super.key,
      required this.running,
      required this.status,
      this.fraction,
      this.details = '',
      this.failed = false});
  final bool running;
  final String status;
  final double? fraction;
  final String details;
  final bool failed;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          border: Border(top: BorderSide(color: colors.outlineVariant))),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(
              failed
                  ? Icons.error_outline
                  : running
                      ? Icons.timelapse
                      : Icons.task_alt,
              size: 17,
              color: failed ? colors.error : colors.primary),
          const SizedBox(width: 9),
          Expanded(
              child: Text(status,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600))),
          if (running && fraction != null)
            Text('${(fraction! * 100).toStringAsFixed(1)}%'),
        ]),
        if (details.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(details,
                  style:
                      TextStyle(fontSize: 12, color: colors.onSurfaceVariant))),
        if (running)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(value: fraction, minHeight: 3)),
      ]),
    );
  }
}
