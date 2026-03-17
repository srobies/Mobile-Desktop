import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:server_core/server_core.dart';

import '../../../navigation/destinations.dart';
import '../providers/admin_user_providers.dart';

class AdminPluginsScreen extends ConsumerStatefulWidget {
  const AdminPluginsScreen({super.key});

  @override
  ConsumerState<AdminPluginsScreen> createState() => _AdminPluginsScreenState();
}

class _AdminPluginsScreenState extends ConsumerState<AdminPluginsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _categoryFilter;

  AdminPluginsApi get _api =>
      GetIt.instance<MediaServerClient>().adminPluginsApi;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search plugins...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Installed'),
                  Tab(text: 'Catalog'),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _InstalledTab(
                searchQuery: _searchQuery,
                onToggle: _togglePlugin,
                onUninstall: _uninstallPlugin,
              ),
              _CatalogTab(
                searchQuery: _searchQuery,
                categoryFilter: _categoryFilter,
                onCategoryChanged: (c) =>
                    setState(() => _categoryFilter = c),
                onInstall: _installPackage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _togglePlugin(PluginInfo plugin) async {
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
            SnackBar(content: Text('Failed to uninstall plugin: $e')));
      }
    }
  }

  Future<void> _installPackage(PackageInfo package, VersionInfo version) async {
    try {
      await _api.installPackage(
        package.name,
        assemblyGuid: package.id,
        version: version.version,
        repositoryUrl: version.repositoryUrl.isNotEmpty
            ? version.repositoryUrl
            : null,
      );
      ref.invalidate(adminInstalledPluginsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('"${package.name}" is being installed...')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to install package: $e')));
      }
    }
  }
}

class _InstalledTab extends ConsumerWidget {
  final String searchQuery;
  final Future<void> Function(PluginInfo) onToggle;
  final Future<void> Function(PluginInfo) onUninstall;

  const _InstalledTab({
    required this.searchQuery,
    required this.onToggle,
    required this.onUninstall,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pluginsAsync = ref.watch(adminInstalledPluginsProvider);

    return pluginsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Failed to load plugins: $error'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => ref.invalidate(adminInstalledPluginsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (plugins) {
        var filtered = plugins;
        if (searchQuery.isNotEmpty) {
          final q = searchQuery.toLowerCase();
          filtered = filtered
              .where((p) =>
                  p.name.toLowerCase().contains(q) ||
                  p.description.toLowerCase().contains(q))
              .toList();
        }

        if (filtered.isEmpty) {
          return Center(
            child: Text(searchQuery.isNotEmpty
                ? 'No plugins match your search'
                : 'No plugins installed'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final plugin = filtered[index];
            return _InstalledPluginTile(
              plugin: plugin,
              onTap: () =>
                  context.push(Destinations.adminPlugin(plugin.id)),
              onToggle: () => onToggle(plugin),
              onUninstall: () => onUninstall(plugin),
            );
          },
        );
      },
    );
  }
}

class _InstalledPluginTile extends StatelessWidget {
  final PluginInfo plugin;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onUninstall;

  const _InstalledPluginTile({
    required this.plugin,
    required this.onTap,
    required this.onToggle,
    required this.onUninstall,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(plugin.status, theme);

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.extension),
      ),
      title: Text(plugin.name),
      subtitle: Row(
        children: [
          Text('v${plugin.version}'),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              plugin.status.label,
              style: TextStyle(fontSize: 11, color: statusColor),
            ),
          ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'toggle':
              onToggle();
            case 'uninstall':
              onUninstall();
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'toggle',
            child: Text(plugin.status == PluginStatus.disabled
                ? 'Enable'
                : 'Disable'),
          ),
          if (plugin.canUninstall)
            const PopupMenuItem(
              value: 'uninstall',
              child: Text('Uninstall'),
            ),
        ],
      ),
    );
  }

  Color _statusColor(PluginStatus status, ThemeData theme) {
    switch (status) {
      case PluginStatus.active:
        return Colors.green;
      case PluginStatus.disabled:
        return theme.colorScheme.onSurfaceVariant;
      case PluginStatus.restart:
        return Colors.orange;
      case PluginStatus.malfunctioned:
        return theme.colorScheme.error;
      case PluginStatus.notSupported:
        return theme.colorScheme.error;
      case PluginStatus.superseded:
      case PluginStatus.deleted:
        return theme.colorScheme.onSurfaceVariant;
    }
  }
}

class _CatalogTab extends ConsumerWidget {
  final String searchQuery;
  final String? categoryFilter;
  final ValueChanged<String?> onCategoryChanged;
  final Future<void> Function(PackageInfo, VersionInfo) onInstall;

  const _CatalogTab({
    required this.searchQuery,
    required this.categoryFilter,
    required this.onCategoryChanged,
    required this.onInstall,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packagesAsync = ref.watch(adminAvailablePackagesProvider);

    return packagesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Failed to load catalog: $error'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => ref.invalidate(adminAvailablePackagesProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (packages) {
        final categories = packages
            .map((p) => p.category)
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

        var filtered = packages;
        if (categoryFilter != null) {
          filtered = filtered
              .where((p) => p.category == categoryFilter)
              .toList();
        }
        if (searchQuery.isNotEmpty) {
          final q = searchQuery.toLowerCase();
          filtered = filtered
              .where((p) =>
                  p.name.toLowerCase().contains(q) ||
                  p.overview.toLowerCase().contains(q) ||
                  p.description.toLowerCase().contains(q))
              .toList();
        }

        return Column(
          children: [
            if (categories.isNotEmpty)
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        label: const Text('All'),
                        selected: categoryFilter == null,
                        onSelected: (_) => onCategoryChanged(null),
                      ),
                    ),
                    ...categories.map((c) => Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          child: FilterChip(
                            label: Text(c),
                            selected: categoryFilter == c,
                            onSelected: (_) => onCategoryChanged(
                                categoryFilter == c ? null : c),
                          ),
                        )),
                  ],
                ),
              ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(searchQuery.isNotEmpty
                          ? 'No packages match your search'
                          : 'No packages available'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final pkg = filtered[index];
                        return _CatalogPackageTile(
                          package: pkg,
                          onInstall: (version) =>
                              onInstall(pkg, version),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _CatalogPackageTile extends StatelessWidget {
  final PackageInfo package;
  final void Function(VersionInfo version) onInstall;

  const _CatalogPackageTile({
    required this.package,
    required this.onInstall,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latestVersion =
        package.versions.isNotEmpty ? package.versions.first : null;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.extension),
      ),
      title: Text(package.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (package.overview.isNotEmpty)
            Text(
              package.overview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 2),
          Row(
            children: [
              if (package.owner.isNotEmpty)
                Text(package.owner,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              if (latestVersion != null) ...[
                if (package.owner.isNotEmpty)
                  Text(' · ',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                Text('v${latestVersion.version}',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ],
            ],
          ),
        ],
      ),
      trailing: latestVersion != null
          ? IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Install',
              onPressed: () => onInstall(latestVersion),
            )
          : null,
    );
  }
}
