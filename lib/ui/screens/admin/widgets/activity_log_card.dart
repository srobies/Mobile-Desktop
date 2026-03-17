import 'package:flutter/material.dart';
import 'package:server_core/server_core.dart';

class ActivityLogCard extends StatelessWidget {
  final ActivityLogResult activityLog;

  const ActivityLogCard({super.key, required this.activityLog});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = activityLog.items;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Recent Activity', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No recent activity')),
              )
            else
              ...items.map((entry) {
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: _severityIcon(entry.severity, theme),
                  title: Text(
                    entry.name,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  subtitle: Text(
                    _formatDate(entry.date),
                    style: theme.textTheme.bodySmall,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _severityIcon(String severity, ThemeData theme) {
    switch (severity.toLowerCase()) {
      case 'error':
        return Icon(Icons.error, size: 20, color: theme.colorScheme.error);
      case 'warning':
      case 'warn':
        return Icon(Icons.warning, size: 20, color: Colors.orange);
      default:
        return Icon(Icons.info_outline, size: 20, color: theme.colorScheme.onSurfaceVariant);
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.month}/${date.day}/${date.year}';
  }
}
