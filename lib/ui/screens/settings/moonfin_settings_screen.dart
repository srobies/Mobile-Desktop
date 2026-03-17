import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../preference/user_preferences.dart';
import '../../../util/platform_detection.dart';
import '../../navigation/destinations.dart';
import '../../widgets/settings/preference_tiles.dart';

class MoonfinSettingsScreen extends StatelessWidget {
  const MoonfinSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Moonfin Settings')),
      body: ListView(
        children: [
          SwitchPreferenceTile(
            preference: UserPreferences.pluginSyncEnabled,
            title: 'Server Plugin Sync',
            subtitle: 'Sync settings with Moonfin server plugin',
            icon: Icons.sync,
          ),
          const Divider(),
          SwitchPreferenceTile(
            preference: UserPreferences.themeMusicEnabled,
            title: 'Theme Music',
            subtitle: 'Play theme music on detail pages',
            icon: Icons.music_note,
          ),
          SliderPreferenceTile(
            preference: UserPreferences.themeMusicVolume,
            title: 'Theme Music Volume',
            icon: Icons.volume_up,
            min: 0,
            max: 100,
            divisions: 20,
            labelOf: (v) => '$v%',
          ),
          if (!PlatformDetection.isMobile)
            SwitchPreferenceTile(
              preference: UserPreferences.themeMusicOnHomeRows,
              title: 'Theme Music on Home Rows',
              subtitle: 'Play when browsing home screen',
              icon: Icons.queue_music,
            ),
          const Divider(),
          StringPickerPreferenceTile(
            preference: UserPreferences.seasonalSurprise,
            title: 'Seasonal Effects',
            icon: Icons.celebration,
            options: const {
              'none': 'None',
              'snow': 'Snow',
              'fireworks': 'Fireworks',
              'confetti': 'Confetti',
              'leaves': 'Falling Leaves',
            },
          ),
          const Divider(),
          SwitchPreferenceTile(
            preference: UserPreferences.enableAdditionalRatings,
            title: 'Additional Ratings',
            subtitle: 'Show MDBList and TMDB ratings',
            icon: Icons.star,
          ),
          SwitchPreferenceTile(
            preference: UserPreferences.showRatingLabels,
            title: 'Rating Labels',
            subtitle: 'Show labels next to rating icons',
            icon: Icons.label,
          ),
          SwitchPreferenceTile(
            preference: UserPreferences.enableEpisodeRatings,
            title: 'Episode Ratings',
            subtitle: 'Show ratings on individual episodes',
            icon: Icons.stars,
          ),
          ListTile(
            leading: const Icon(Icons.reorder),
            title: const Text('Rating Sources'),
            subtitle: const Text('Select and reorder rating sources'),
            onTap: () => context.push(Destinations.settingsRatings),
          ),
          const Divider(),
          if (PlatformDetection.isDesktop)
            SwitchPreferenceTile(
              preference: UserPreferences.updateNotificationsEnabled,
              title: 'Update Notifications',
              subtitle: 'Show when updates are available',
              icon: Icons.system_update,
            ),
        ],
      ),
    );
  }
}
