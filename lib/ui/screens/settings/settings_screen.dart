import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/repositories/session_repository.dart';
import '../../../di/providers.dart';
import '../../navigation/destinations.dart';
import '../admin/providers/admin_status_providers.dart';
import '../../../util/platform_detection.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final adminBadgeCount = isAdmin
        ? ref.watch(adminNotificationSummaryProvider).valueOrNull?.count ?? 0
        : 0;
    final theme = Theme.of(context);
    final accountEntries = <_SettingsEntry>[
      _SettingsEntry(
        icon: Icons.manage_accounts,
        title: 'Authentication',
        subtitle: 'Auto login, server management',
        onTap: () => context.push(Destinations.settingsAuth),
      ),
      _SettingsEntry(
        icon: Icons.pin,
        title: 'PIN Code',
        subtitle: 'Set up PIN code protection',
        onTap: () => context.push(Destinations.settingsPinCode),
      ),
      _SettingsEntry(
        icon: Icons.child_care,
        title: 'Parental Controls',
        subtitle: 'Content rating restrictions',
        onTap: () => context.push(Destinations.settingsParental),
      ),
    ];

    final customizationEntries = <_SettingsEntry>[
      _SettingsEntry(
        icon: Icons.palette,
        title: 'Theme & Appearance',
        subtitle: PlatformDetection.isMobile
            ? 'Watched indicators, backdrops'
            : 'Focus color, watched indicators, backdrops',
        onTap: () => context.push(Destinations.settingsAppearance),
      ),
      _SettingsEntry(
        icon: Icons.view_sidebar,
        title: 'Navigation',
        subtitle: 'Navbar style, toolbar buttons',
        onTap: () => context.push(Destinations.settingsNavigation),
      ),
      _SettingsEntry(
        icon: Icons.home,
        title: 'Home Sections',
        subtitle: 'Reorder and toggle home rows',
        onTap: () => context.push(Destinations.settingsHomeSections),
      ),
      _SettingsEntry(
        icon: Icons.featured_play_list,
        title: 'Media Bar',
        subtitle: 'Featured content, appearance',
        onTap: () => context.push(Destinations.settingsMediaBar),
      ),
      _SettingsEntry(
        icon: Icons.photo_library,
        title: 'Library Display',
        subtitle: 'Poster size, image type, folder view',
        onTap: () => context.push(Destinations.settingsLibrary),
      ),
    ];

    final playbackEntries = <_SettingsEntry>[
      _SettingsEntry(
        icon: Icons.play_circle_fill,
        title: 'Playback',
        subtitle: 'Bitrate, resolution, behavior',
        onTap: () => context.push(Destinations.settingsPlayback),
      ),
      _SettingsEntry(
        icon: Icons.subtitles,
        title: 'Subtitles',
        subtitle: 'Language, size, appearance',
        onTap: () => context.push(Destinations.settingsSubtitles),
      ),
      _SettingsEntry(
        icon: Icons.download,
        title: 'Downloads',
        subtitle: 'Quality, storage',
        onTap: () => context.push(Destinations.settingsDownloads),
      ),
    ];

    final moonfinEntries = <_SettingsEntry>[
      _SettingsEntry(
        iconBuilder: (size, color) => Image.asset(
          'assets/icons/moonfin.png',
          width: size,
          height: size,
          color: color,
          fit: BoxFit.contain,
        ),
        title: 'Moonfin Settings',
        subtitle: 'Plugin sync, theme music, ratings',
        onTap: () => context.push(Destinations.settingsMoonfin),
      ),
      _SettingsEntry(
        iconBuilder: (size, color) => Image.asset(
          'assets/icons/seerr.png',
          width: size,
          height: size,
          color: color,
          fit: BoxFit.contain,
        ),
        title: 'Seerr',
        subtitle: 'Media request integration',
        onTap: () => context.push(Destinations.settingsSeerr),
      ),
    ];

    final otherEntries = <_SettingsEntry>[
      _SettingsEntry(
        icon: Icons.swap_horiz,
        title: 'Switch Server',
        onTap: () => context.go(Destinations.serverSelect),
      ),
      _SettingsEntry(
        icon: Icons.logout,
        title: 'Sign Out',
        onTap: () async {
          await GetIt.instance<SessionRepository>().destroyCurrentSession();
          if (context.mounted) context.go(Destinations.serverSelect);
        },
      ),
      _SettingsEntry(
        icon: Icons.info,
        title: 'About',
        subtitle: 'Version, licenses',
        onTap: () => context.push(Destinations.settingsAbout),
      ),
    ];

    final sections = <_SettingsSectionData>[
      _SettingsSectionData(
        icon: Icons.manage_accounts,
        title: 'Account',
        subtitle: 'Sign-in and security',
        entries: accountEntries,
      ),
      if (isAdmin)
        _SettingsSectionData(
          icon: Icons.admin_panel_settings,
          title: 'Administration',
          subtitle: 'Server settings, users, libraries',
          entries: const [],
          badgeCount: adminBadgeCount,
          onTap: () => context.push(Destinations.admin),
        ),
      _SettingsSectionData(
        icon: Icons.brush,
        title: 'Customization',
        subtitle: 'Theme and layout',
        entries: customizationEntries,
      ),
      _SettingsSectionData(
        icon: Icons.play_circle,
        title: 'Playback',
        subtitle: 'Video and subtitles',
        entries: playbackEntries,
      ),
      _SettingsSectionData(
        iconBuilder: (size, color) => Image.asset(
          'assets/icons/moonfin.png',
          width: size,
          height: size,
          color: color,
          fit: BoxFit.contain,
        ),
        title: 'Moonfin',
        subtitle: 'Integrations',
        entries: moonfinEntries,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primaryContainer,
                  theme.colorScheme.secondaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.tune),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Customize account, playback, and interface behavior',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final columns = width >= 900
                  ? 3
                  : width >= 360
                      ? 2
                      : 1;
              final cardWidth = (width - (columns - 1) * 10) / columns;
              final cardHeight = columns >= 3
                  ? (cardWidth * 0.94).clamp(176.0, 222.0)
                  : (cardWidth * 0.92).clamp(178.0, 240.0);

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sections.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  mainAxisExtent: cardHeight,
                ),
                itemBuilder: (context, index) {
                  final section = sections[index];
                  return _SettingsSectionCard(
                    section: section,
                    onTap: () {
                      if (section.onTap != null) {
                        section.onTap!();
                      } else {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => _SectionDetailScreen(section: section),
                          ),
                        );
                      }
                    },
                  );
                },
              );
            },
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              'Other',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _SettingsListCard(entries: otherEntries),
        ],
      ),
    );
  }
}

class _SettingsSectionData {
  final IconData? icon;
  final Widget Function(double size, Color color)? iconBuilder;
  final String title;
  final String subtitle;
  final List<_SettingsEntry> entries;
  final VoidCallback? onTap;
  final int badgeCount;

  const _SettingsSectionData({
    this.icon,
    this.iconBuilder,
    required this.title,
    required this.subtitle,
    required this.entries,
    this.onTap,
    this.badgeCount = 0,
  });
}

class _SettingsSectionCard extends StatelessWidget {
  final _SettingsSectionData section;
  final VoidCallback onTap;

  const _SettingsSectionCard({
    required this.section,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(11, 11, 11, 9),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.65),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: section.iconBuilder != null
                          ? section.iconBuilder!(22, Colors.white)
                          : Icon(section.icon, size: 22),
                    ),
                    if (section.badgeCount > 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.error,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            section.badgeCount > 9 ? '9+' : '${section.badgeCount}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onError,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                section.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                section.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
              const Spacer(),
              Row(
                children: [
                  if (section.entries.isNotEmpty)
                    Text(
                      '${section.entries.length} options',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward,
                    size: 26,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionDetailScreen extends StatelessWidget {
  final _SettingsSectionData section;

  const _SectionDetailScreen({required this.section});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(section.title),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              children: [
                for (var i = 0; i < section.entries.length; i++) ...[
                  _SettingsEntryTile(entry: section.entries[i]),
                  if (i != section.entries.length - 1)
                    Divider(
                      height: 1,
                      indent: 70,
                      endIndent: 12,
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                    ),
                ],
                const SizedBox(height: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsListCard extends StatelessWidget {
  final List<_SettingsEntry> entries;

  const _SettingsListCard({required this.entries});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            _SettingsEntryTile(entry: entries[i]),
            if (i != entries.length - 1)
              Divider(
                height: 1,
                indent: 70,
                endIndent: 12,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
          ],
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _SettingsEntry {
  final IconData? icon;
  final Widget Function(double size, Color color)? iconBuilder;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingsEntry({
    this.icon,
    this.iconBuilder,
    required this.title,
    required this.onTap,
    this.subtitle,
  });
}

class _SettingsEntryTile extends StatelessWidget {
  final _SettingsEntry entry;

  const _SettingsEntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      minLeadingWidth: 40,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
        ),
        child: entry.iconBuilder != null
            ? entry.iconBuilder!(20, Colors.white)
            : Icon(entry.icon, size: 20),
      ),
      title: Text(
        entry.title,
        style: theme.textTheme.titleSmall,
      ),
      subtitle: entry.subtitle != null
          ? Text(
              entry.subtitle!,
              style: theme.textTheme.bodySmall,
            )
          : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: entry.onTap,
    );
  }
}
