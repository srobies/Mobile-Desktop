import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:server_core/server_core.dart';

import '../admin_plugin_version_utils.dart';
import '../providers/admin_user_providers.dart';

final _packageInfoProvider =
    FutureProvider.family<PackageInfo?, String>((ref, pluginId) async {
  final client = GetIt.instance<MediaServerClient>();
  try {
    final packages = await client.adminPluginsApi.getAvailablePackages();
    for (final pkg in packages) {
      if (pkg.id == pluginId) return pkg;
    }
    return null;
  } catch (_) {
    return null;
  }
});

class AdminPluginDetailScreen extends ConsumerStatefulWidget {
  final String pluginId;
  const AdminPluginDetailScreen({super.key, required this.pluginId});

  @override
  ConsumerState<AdminPluginDetailScreen> createState() =>
      _AdminPluginDetailScreenState();
}

class _AdminPluginDetailScreenState
    extends ConsumerState<AdminPluginDetailScreen> {
  bool _loadingConfig = false;
  Map<String, dynamic>? _config;
  String? _configError;
  bool _savingConfig = false;
  bool _toggling = false;

  AdminPluginsApi get _api =>
      GetIt.instance<MediaServerClient>().adminPluginsApi;

  PluginInfo? _findPlugin(List<PluginInfo> plugins) {
    for (final p in plugins) {
      if (p.id == widget.pluginId) return p;
    }
    return null;
  }

  Future<void> _loadConfig(PluginInfo plugin) async {
    if (plugin.configurationFileName == null) return;
    setState(() {
      _loadingConfig = true;
      _configError = null;
    });
    try {
      final config = await _api.getPluginConfiguration(plugin.id);
      if (mounted) setState(() => _config = config);
    } catch (e) {
      if (mounted) setState(() => _configError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingConfig = false);
    }
  }

  Future<void> _saveConfig(PluginInfo plugin) async {
    if (_config == null) return;
    setState(() => _savingConfig = true);
    try {
      await _api.updatePluginConfiguration(plugin.id, _config!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Configuration saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save configuration: $e')));
      }
    } finally {
      if (mounted) setState(() => _savingConfig = false);
    }
  }

  Future<void> _togglePlugin(PluginInfo plugin) async {
    setState(() => _toggling = true);
    try {
      if (plugin.status == PluginStatus.disabled) {
        await _api.enablePlugin(plugin.id, plugin.version);
      } else {
        await _api.disablePlugin(plugin.id, plugin.version);
      }
      ref.invalidate(adminInstalledPluginsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to toggle plugin: $e')));
      }
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  Future<void> _uninstallPlugin(PluginInfo plugin) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Uninstall Plugin'),
        content: Text('Are you sure you want to uninstall "${plugin.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Uninstall'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _api.uninstallPlugin(plugin.id, plugin.version);
      ref.invalidate(adminInstalledPluginsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '"${plugin.name}" will be removed after server restart')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to uninstall: $e')));
      }
    }
  }

  Future<void> _installPluginUpdate(
    PluginInfo plugin,
    PackageInfo package,
    VersionInfo version,
  ) async {
    try {
      await _api.installPackage(
        package.name,
        assemblyGuid: package.id,
        version: version.version,
        repositoryUrl:
            version.repositoryUrl.isNotEmpty ? version.repositoryUrl : null,
      );

      ref.invalidate(adminInstalledPluginsProvider);
      ref.invalidate(adminAvailablePackagesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Updating "${plugin.name}" to v${version.version}...',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to install update: $e')),
        );
      }
    }
  }

  String _pluginImageUrl(PluginInfo plugin) {
    final client = GetIt.instance<MediaServerClient>();
    return '${client.baseUrl}/Plugins/${plugin.id}/${plugin.version}/Image';
  }

  @override
  Widget build(BuildContext context) {
    final pluginsAsync = ref.watch(adminInstalledPluginsProvider);
    final packageInfoAsync = ref.watch(_packageInfoProvider(widget.pluginId));

    return pluginsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Failed to load plugin: $error'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => ref.invalidate(adminInstalledPluginsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (plugins) {
        final plugin = _findPlugin(plugins);
        if (plugin == null) {
          return const Center(child: Text('Plugin not found'));
        }
        final packageInfo = packageInfoAsync.valueOrNull;
        return _buildContent(context, plugin, packageInfo);
      },
    );
  }

  Widget _buildContent(
      BuildContext context, PluginInfo plugin, PackageInfo? packageInfo) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 800;
    final latestUpdateVersion = packageInfo == null || plugin.version.isEmpty
      ? null
      : latestVersionInfoAfter(plugin.version, packageInfo.versions);

    if (plugin.configurationFileName != null &&
        _config == null &&
        !_loadingConfig &&
        _configError == null) {
      Future.microtask(() => _loadConfig(plugin));
    }

    final statusBanner = _buildStatusBanner(context, plugin);

    if (isWide) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (statusBanner != null) ...[statusBanner, const SizedBox(height: 12)],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plugin.name, style: theme.textTheme.headlineMedium),
                    if (packageInfo?.description.isNotEmpty == true ||
                        plugin.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        packageInfo?.description ?? plugin.description,
                        style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (plugin.configurationFileName != null)
                      _ConfigSection(
                        config: _config,
                        loading: _loadingConfig,
                        saving: _savingConfig,
                        error: _configError,
                        onLoad: () => _loadConfig(plugin),
                        onSave: () => _saveConfig(plugin),
                        onConfigChanged: (config) =>
                            setState(() => _config = config),
                      ),
                    if (packageInfo != null &&
                        packageInfo.versions.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _RevisionHistory(
                        versions: packageInfo.versions,
                        installedVersion: plugin.version,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 24),
              SizedBox(
                width: 300,
                child: Column(
                  children: [
                    _PluginImage(
                      imageUrl: plugin.hasImage
                          ? _pluginImageUrl(plugin)
                          : packageInfo?.imageUrl,
                    ),
                    const SizedBox(height: 16),
                    if (plugin.canUninstall) ...[
                      _ActionsSection(
                        plugin: plugin,
                        toggling: _toggling,
                        latestUpdateVersion: latestUpdateVersion?.version,
                        onToggle: () => _togglePlugin(plugin),
                        onInstallUpdate: latestUpdateVersion == null ||
                                packageInfo == null
                            ? null
                            : () => _installPluginUpdate(
                                  plugin,
                                  packageInfo,
                                  latestUpdateVersion,
                                ),
                        onUninstall: () => _uninstallPlugin(plugin),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _DetailsTable(
                      plugin: plugin,
                      packageInfo: packageInfo,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (statusBanner != null) ...[statusBanner, const SizedBox(height: 12)],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PluginImage(
              imageUrl: plugin.hasImage
                  ? _pluginImageUrl(plugin)
                  : packageInfo?.imageUrl,
              size: 64,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plugin.name, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text('Version ${plugin.version}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),

        if (packageInfo?.description.isNotEmpty == true ||
            plugin.description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            packageInfo?.description ?? plugin.description,
            style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant),
          ),
        ],

        if (plugin.canUninstall) ...[
          const SizedBox(height: 16),
          _ActionsSection(
            plugin: plugin,
            toggling: _toggling,
            latestUpdateVersion: latestUpdateVersion?.version,
            onToggle: () => _togglePlugin(plugin),
            onInstallUpdate: latestUpdateVersion == null || packageInfo == null
                ? null
                : () => _installPluginUpdate(
                      plugin,
                      packageInfo,
                      latestUpdateVersion,
                    ),
            onUninstall: () => _uninstallPlugin(plugin),
          ),
        ],

        const SizedBox(height: 16),
        _DetailsTable(plugin: plugin, packageInfo: packageInfo),

        if (plugin.configurationFileName != null) ...[
          const SizedBox(height: 16),
          _ConfigSection(
            config: _config,
            loading: _loadingConfig,
            saving: _savingConfig,
            error: _configError,
            onLoad: () => _loadConfig(plugin),
            onSave: () => _saveConfig(plugin),
            onConfigChanged: (config) =>
                setState(() => _config = config),
          ),
        ],

        if (packageInfo != null && packageInfo.versions.isNotEmpty) ...[
          const SizedBox(height: 16),
          _RevisionHistory(
            versions: packageInfo.versions,
            installedVersion: plugin.version,
          ),
        ],
      ],
    );
  }

  Widget? _buildStatusBanner(BuildContext context, PluginInfo plugin) {
    final theme = Theme.of(context);
    String? message;
    Color? color;

    switch (plugin.status) {
      case PluginStatus.restart:
        message = 'A server restart is required for changes to take effect.';
        color = theme.colorScheme.tertiary;
      case PluginStatus.deleted:
        message = 'This plugin will be removed after server restart.';
        color = theme.colorScheme.error;
      case PluginStatus.malfunctioned:
        message = 'This plugin has malfunctioned and may not work correctly.';
        color = theme.colorScheme.error;
      case PluginStatus.notSupported:
        message = 'This plugin is not supported by the current server version.';
        color = theme.colorScheme.error;
      case PluginStatus.superseded:
        message = 'This plugin has been superseded by a newer version.';
        color = theme.colorScheme.tertiary;
      default:
        return null;
    }

    return Card(
      color: color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message,
                  style: theme.textTheme.bodyMedium?.copyWith(color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PluginImage extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const _PluginImage({
    this.imageUrl,
    this.size = 120,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null) return _fallback(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(context),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.extension, size: size * 0.45,
          color: theme.colorScheme.onSurfaceVariant),
    );
  }
}

class _ActionsSection extends StatelessWidget {
  final PluginInfo plugin;
  final bool toggling;
  final String? latestUpdateVersion;
  final VoidCallback onToggle;
  final VoidCallback? onInstallUpdate;
  final VoidCallback onUninstall;

  const _ActionsSection({
    required this.plugin,
    required this.toggling,
    this.latestUpdateVersion,
    required this.onToggle,
    this.onInstallUpdate,
    required this.onUninstall,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRestartPending = plugin.status == PluginStatus.restart;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable Plugin'),
              value: plugin.status != PluginStatus.disabled,
              onChanged: (isRestartPending || toggling)
                  ? null
                  : (_) => onToggle(),
            ),
            const Divider(),
            if (onInstallUpdate != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.download,
                  color: theme.colorScheme.primary,
                ),
                title: Text(
                  latestUpdateVersion != null
                      ? 'Install update (v$latestUpdateVersion)'
                      : 'Install update',
                ),
                onTap: onInstallUpdate,
              ),
            if (onInstallUpdate != null) const Divider(),
            ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                title: Text('Uninstall',
                    style: TextStyle(color: theme.colorScheme.error)),
                onTap: onUninstall,
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailsTable extends StatelessWidget {
  final PluginInfo plugin;
  final PackageInfo? packageInfo;

  const _DetailsTable({
    required this.plugin,
    this.packageInfo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final developer = packageInfo?.owner;
    final repoName = packageInfo?.versions.isNotEmpty == true
        ? packageInfo!.versions.first.repositoryName
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Details', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _row(context, 'Status', plugin.status.label),
            _row(context, 'Version', plugin.version),
            _row(context, 'Developer', developer ?? 'Unknown'),
            _row(
              context,
              'Repository',
              plugin.canUninstall
                  ? (repoName ?? 'Unknown')
                  : 'Bundled',
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _RevisionHistory extends StatelessWidget {
  final List<VersionInfo> versions;
  final String installedVersion;

  const _RevisionHistory({
    required this.versions,
    required this.installedVersion,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Revision History', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...versions.take(10).map((v) {
              final isInstalled = v.version == installedVersion;
              return ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Row(
                  children: [
                    Text(v.version,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: isInstalled
                                ? FontWeight.bold
                                : FontWeight.normal)),
                    if (isInstalled) ...[
                      const SizedBox(width: 8),
                      Chip(
                        label: const Text('Installed'),
                        visualDensity: VisualDensity.compact,
                        labelStyle: theme.textTheme.labelSmall,
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ],
                ),
                subtitle: v.timestamp != null
                    ? Text(v.timestamp!,
                        style: theme.textTheme.bodySmall)
                    : null,
                children: [
                  if (v.changelog != null && v.changelog!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 16, right: 16, bottom: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(v.changelog!,
                            style: theme.textTheme.bodySmall),
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(left: 16, bottom: 12),
                      child: Text('No changelog available.'),
                    ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ConfigSection extends StatelessWidget {
  final Map<String, dynamic>? config;
  final bool loading;
  final bool saving;
  final String? error;
  final VoidCallback onLoad;
  final VoidCallback onSave;
  final ValueChanged<Map<String, dynamic>> onConfigChanged;

  const _ConfigSection({
    required this.config,
    required this.loading,
    required this.saving,
    required this.error,
    required this.onLoad,
    required this.onSave,
    required this.onConfigChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Settings', style: theme.textTheme.titleMedium),
                const Spacer(),
                if (config != null)
                  FilledButton.tonalIcon(
                    onPressed: saving ? null : onSave,
                    icon: saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: const Text('Save'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (error != null)
              Column(
                children: [
                  Text('Error loading settings: $error'),
                  const SizedBox(height: 8),
                  ElevatedButton(onPressed: onLoad, child: const Text('Retry')),
                ],
              )
            else if (config != null)
              _ConfigForm(
                config: config!,
                onChanged: onConfigChanged,
              ),
          ],
        ),
      ),
    );
  }
}

class _ConfigForm extends StatelessWidget {
  final Map<String, dynamic> config;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final List<String> _path;

  const _ConfigForm({
    required this.config,
    required this.onChanged,
  }) : _path = const [];

  const _ConfigForm._nested({
    required this.config,
    required this.onChanged,
    required List<String> path,
  }) : _path = path;

  @override
  Widget build(BuildContext context) {
    final entries = config.entries.toList();
    if (entries.isEmpty) {
      return const Text('No configuration options available');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries.map((entry) {
        return _buildField(context, entry.key, entry.value);
      }).toList(),
    );
  }

  void _update(String key, dynamic newValue) {
    final updated = Map<String, dynamic>.from(config);
    updated[key] = newValue;
    onChanged(updated);
  }

  Widget _buildField(BuildContext context, String key, dynamic value) {
    if (value is bool) {
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(_formatKey(key)),
        value: value,
        onChanged: (v) => _update(key, v),
      );
    }

    if (value is int) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: TextFormField(
          key: ValueKey([..._path, key].join('.')),
          initialValue: value.toString(),
          decoration: InputDecoration(
            labelText: _formatKey(key),
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          onChanged: (v) => _update(key, int.tryParse(v) ?? value),
        ),
      );
    }

    if (value is double) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: TextFormField(
          key: ValueKey([..._path, key].join('.')),
          initialValue: value.toString(),
          decoration: InputDecoration(
            labelText: _formatKey(key),
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          onChanged: (v) => _update(key, double.tryParse(v) ?? value),
        ),
      );
    }

    if (value is String) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: TextFormField(
          key: ValueKey([..._path, key].join('.')),
          initialValue: value,
          decoration: InputDecoration(
            labelText: _formatKey(key),
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) => _update(key, v),
        ),
      );
    }

    if (value is List) {
      return _ListField(
        label: _formatKey(key),
        list: value,
        onChanged: (newList) => _update(key, newList),
      );
    }

    if (value is Map) {
      final mapValue = Map<String, dynamic>.from(value);
      return _NestedMapSection(
        label: _formatKey(key),
        map: mapValue,
        path: [..._path, key],
        onChanged: (newMap) => _update(key, newMap),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: _formatKey(key),
          border: const OutlineInputBorder(),
        ),
        child: Text(value?.toString() ?? 'null'),
      ),
    );
  }

  static String _formatKey(String key) {
    return key.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (m) => '${m[1]} ${m[2]}',
    );
  }
}

class _NestedMapSection extends StatelessWidget {
  final String label;
  final Map<String, dynamic> map;
  final List<String> path;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const _NestedMapSection({
    required this.label,
    required this.map,
    required this.path,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(label, style: theme.textTheme.titleSmall),
        subtitle: Text('${map.length} properties',
            style: theme.textTheme.bodySmall),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: _ConfigForm._nested(
              config: map,
              onChanged: onChanged,
              path: path,
            ),
          ),
        ],
      ),
    );
  }
}

class _ListField extends StatefulWidget {
  final String label;
  final List<dynamic> list;
  final ValueChanged<List<dynamic>> onChanged;

  const _ListField({
    required this.label,
    required this.list,
    required this.onChanged,
  });

  @override
  State<_ListField> createState() => _ListFieldState();
}

class _ListFieldState extends State<_ListField> {
  late List<dynamic> _items;

  @override
  void initState() {
    super.initState();
    _items = List<dynamic>.from(widget.list);
  }

  @override
  void didUpdateWidget(_ListField old) {
    super.didUpdateWidget(old);
    if (old.list != widget.list) {
      _items = List<dynamic>.from(widget.list);
    }
  }

  bool get _isPrimitiveList =>
      _items.isEmpty || _items.every((e) => e is String || e is num || e is bool);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_isPrimitiveList) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(widget.label, style: theme.textTheme.titleSmall),
          subtitle: Text('${_items.length} items',
              style: theme.textTheme.bodySmall),
          children: [
            for (var i = 0; i < _items.length; i++)
              if (_items[i] is Map)
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: _NestedMapSection(
                    label: '${widget.label} [$i]',
                    map: Map<String, dynamic>.from(_items[i] as Map),
                    path: [widget.label, '$i'],
                    onChanged: (newMap) {
                      _items[i] = newMap;
                      widget.onChanged(List<dynamic>.from(_items));
                    },
                  ),
                )
              else
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.only(left: 16),
                  title: Text(_items[i].toString()),
                ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_items.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (var i = 0; i < _items.length; i++)
                    Chip(
                      label: Text(_items[i].toString()),
                      onDeleted: () {
                        setState(() => _items.removeAt(i));
                        widget.onChanged(List<dynamic>.from(_items));
                      },
                    ),
                ],
              ),
            const SizedBox(height: 4),
            _AddItemButton(
              onAdd: (value) {
                setState(() => _items.add(value));
                widget.onChanged(List<dynamic>.from(_items));
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AddItemButton extends StatefulWidget {
  final ValueChanged<String> onAdd;
  const _AddItemButton({required this.onAdd});

  @override
  State<_AddItemButton> createState() => _AddItemButtonState();
}

class _AddItemButtonState extends State<_AddItemButton> {
  bool _editing = false;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_editing) {
      return TextButton.icon(
        onPressed: () => setState(() => _editing = true),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add item'),
      );
    }
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter value',
              isDense: true,
              border: InputBorder.none,
            ),
            onSubmitted: _submit,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.check, size: 18),
          onPressed: () => _submit(_controller.text),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 18),
          onPressed: () => setState(() {
            _editing = false;
            _controller.clear();
          }),
        ),
      ],
    );
  }

  void _submit(String value) {
    if (value.trim().isEmpty) return;
    widget.onAdd(value.trim());
    _controller.clear();
    setState(() => _editing = false);
  }
}
