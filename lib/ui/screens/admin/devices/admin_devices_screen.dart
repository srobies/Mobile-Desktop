import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:server_core/server_core.dart';

final adminDevicesProvider = FutureProvider<List<DeviceInfoDto>>((ref) async {
  final client = GetIt.instance<MediaServerClient>();
  return client.adminDevicesApi.getDevices();
});

class AdminDevicesScreen extends ConsumerStatefulWidget {
  const AdminDevicesScreen({super.key});

  @override
  ConsumerState<AdminDevicesScreen> createState() => _AdminDevicesScreenState();
}

class _AdminDevicesScreenState extends ConsumerState<AdminDevicesScreen> {
  AdminDevicesApi get _api => GetIt.instance<MediaServerClient>().adminDevicesApi;

  Future<void> _editDeviceName(DeviceInfoDto device) async {
    final controller = TextEditingController(text: device.displayName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Device Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Custom Name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.pop(ctx, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName == null || !mounted) return;

    try {
      final options = DeviceOptionsDto(
        customName: newName.isEmpty ? null : newName,
      );
      await _api.updateDeviceOptions(device.id, options);
      ref.invalidate(adminDevicesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device name updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update device: $e')),
        );
      }
    }
  }

  Future<void> _deleteDevice(DeviceInfoDto device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Device'),
        content: Text(
          "Remove device '${device.displayName}'?\n\n"
          'The user will need to sign in again on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _api.deleteDevice(device.id);
      ref.invalidate(adminDevicesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete device: $e')),
        );
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Never';
    final local = date.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(adminDevicesProvider);
    final theme = Theme.of(context);
    final currentDeviceId = GetIt.instance<MediaServerClient>().deviceInfo.id;

    return devicesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Failed to load devices', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('$e', style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => ref.invalidate(adminDevicesProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (devices) => devices.isEmpty
          ? const Center(child: Text('No devices found'))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                final isCurrentDevice = device.id == currentDeviceId;
                final appInfo = [device.appName, device.appVersion]
                    .where((v) => v != null && v.isNotEmpty)
                    .join(' ');

                return Card(
                  child: ListTile(
                    leading: Icon(
                      _deviceIcon(device.appName),
                      size: 32,
                      color: theme.colorScheme.primary,
                    ),
                    title: Row(
                      children: [
                        Flexible(child: Text(device.displayName)),
                        if (isCurrentDevice) ...[
                          const SizedBox(width: 8),
                          Chip(
                            label: const Text('This Device'),
                            labelStyle: theme.textTheme.labelSmall,
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (appInfo.isNotEmpty) Text(appInfo),
                        Row(
                          children: [
                            if (device.lastUserName != null) ...[
                              Icon(Icons.person, size: 14,
                                  color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(device.lastUserName!,
                                  style: theme.textTheme.bodySmall),
                              const SizedBox(width: 12),
                            ],
                            Icon(Icons.access_time, size: 14,
                                color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(_formatDate(device.dateLastActivity),
                                style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: 'Edit Name',
                          onPressed: () => _editDeviceName(device),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          tooltip: 'Delete',
                          color: isCurrentDevice ? theme.disabledColor : theme.colorScheme.error,
                          onPressed: isCurrentDevice ? null : () => _deleteDevice(device),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  static IconData _deviceIcon(String? appName) {
    if (appName == null) return Icons.devices;
    final lower = appName.toLowerCase();
    if (lower.contains('android')) return Icons.phone_android;
    if (lower.contains('ios') || lower.contains('iphone') || lower.contains('ipad')) return Icons.phone_iphone;
    if (lower.contains('tv') || lower.contains('tizen') || lower.contains('webos') || lower.contains('roku')) return Icons.tv;
    if (lower.contains('web') || lower.contains('chrome') || lower.contains('firefox') || lower.contains('safari')) return Icons.language;
    if (lower.contains('windows') || lower.contains('linux') || lower.contains('mac')) return Icons.computer;
    return Icons.devices;
  }
}
