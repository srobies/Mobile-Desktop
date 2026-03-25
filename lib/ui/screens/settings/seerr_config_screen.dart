import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';

import '../../../data/services/plugin_sync_service.dart';
import '../../../preference/user_preferences.dart';
import '../../widgets/settings/preference_tiles.dart';

class SeerrConfigScreen extends StatefulWidget {
  const SeerrConfigScreen({super.key});

  @override
  State<SeerrConfigScreen> createState() => _SeerrConfigScreenState();
}

class _SeerrConfigScreenState extends State<SeerrConfigScreen> {
  late final PluginSyncService _syncService;
  late final UserPreferences _prefs;

  static const _seerrNsfw = Preference(
    key: 'seerr_nsfw_filter',
    defaultValue: true,
  );

  @override
  void initState() {
    super.initState();
    _syncService = GetIt.instance<PluginSyncService>();
    _prefs = GetIt.instance<UserPreferences>();
    _syncService.addListener(_onSyncStateChanged);
    _ensureSeerrDisabledIfUnavailable();
  }

  @override
  void dispose() {
    _syncService.removeListener(_onSyncStateChanged);
    super.dispose();
  }

  void _onSyncStateChanged() {
    if (!mounted) return;
    _ensureSeerrDisabledIfUnavailable();
    setState(() {});
  }

  void _ensureSeerrDisabledIfUnavailable() {
    if (!_syncService.pluginAvailable || !_syncService.seerrEnabled) {
      if (_prefs.get(UserPreferences.seerrEnabled)) {
        _prefs.set(UserPreferences.seerrEnabled, false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEnableSeerr = _syncService.pluginAvailable && _syncService.seerrEnabled;

    return Scaffold(
      appBar: AppBar(title: const Text('Seerr')),
      body: ListView(
        children: [
          if (canEnableSeerr)
            SwitchPreferenceTile(
              preference: UserPreferences.seerrEnabled,
              title: 'Enable Seerr',
              subtitle: 'Show Seerr in navigation (requires server plugin)',
              icon: Icons.movie_filter,
            )
          else
            const ListTile(
              leading: Icon(Icons.movie_filter_outlined),
              title: Text('Enable Seerr'),
              subtitle: Text(
                'Unavailable because server plugin Seerr support is disabled.',
              ),
            ),
          SwitchPreferenceTile(
            preference: _seerrNsfw,
            title: 'NSFW Filter',
            subtitle: 'Hide adult content in results',
            icon: Icons.visibility_off,
          ),
        ],
      ),
    );
  }
}
