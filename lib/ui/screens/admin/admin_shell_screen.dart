import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../navigation/destinations.dart';
import 'widgets/admin_drawer.dart';

class AdminShellScreen extends StatelessWidget {
  final Widget child;

  const AdminShellScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final currentPath = GoRouterState.of(context).uri.path;
    final canGoBack = !isWide && _isSubPage(currentPath);

    return Scaffold(
      appBar: AppBar(
        leading: isWide
            ? null
            : canGoBack
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.pop(),
                  )
                : Builder(
                    builder: (ctx) => IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ),
        title: const Text('Server Administration'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Exit Admin',
            onPressed: () => context.go(Destinations.home),
          ),
        ],
      ),
      drawer: isWide ? null : AdminDrawer(currentPath: currentPath),
      body: isWide
          ? Row(
              children: [
                SizedBox(
                  width: 280,
                  child: AdminDrawer(
                    currentPath: currentPath,
                    isEmbedded: true,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: child),
              ],
            )
          : child,
    );
  }

  static const _topLevelPaths = {
    Destinations.admin,
    Destinations.adminUsers,
    Destinations.adminLibraries,
    Destinations.adminSettings,
    Destinations.adminTasks,
    Destinations.adminPlugins,
    Destinations.adminRepositories,
    Destinations.adminActivity,
    Destinations.adminDevices,
  };

  static bool _isSubPage(String path) => !_topLevelPaths.contains(path);
}
