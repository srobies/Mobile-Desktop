import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'di/providers.dart';
import 'ui/navigation/app_router.dart';
import 'ui/theme/app_theme.dart';
import 'ui/widgets/cast_mini_player.dart';
import 'ui/widgets/mini_audio_player.dart';
import 'ui/widgets/offline_banner.dart';

class MoonfinApp extends StatelessWidget {
  const MoonfinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp.router(
        title: 'Moonfin',
        theme: AppTheme.darkTheme,
        routerConfig: appRouter,
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          var path = appRouter.routerDelegate.currentConfiguration.uri.path;
          try {
            path = GoRouterState.of(context).uri.path;
          } catch (_) {}

          final hidePlayer = path.startsWith('/player/') ||
              path == '/live-tv/player' ||
              path == '/' ||
              path == '/server-select' ||
              path == '/server' ||
              path == '/login';

          return Column(
            children: [
              const OfflineBanner(),
              Expanded(
                child: _ConnectivityListener(
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
              if (!hidePlayer) const MiniAudioPlayer(),
              if (!hidePlayer) const CastMiniPlayer(),
            ],
          );
        },
      ),
    );
  }
}

class _ConnectivityListener extends ConsumerStatefulWidget {
  final Widget child;
  const _ConnectivityListener({required this.child});

  @override
  ConsumerState<_ConnectivityListener> createState() =>
      _ConnectivityListenerState();
}

class _ConnectivityListenerState
    extends ConsumerState<_ConnectivityListener> {
  bool? _wasOnline;

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);

    if (_wasOnline != null && _wasOnline != isOnline) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isOnline
                ? 'Back online. Syncing progress...'
                : 'You are offline.'),
            duration: const Duration(seconds: 3),
          ),
        );
      });
    }
    _wasOnline = isOnline;

    return widget.child;
  }
}
