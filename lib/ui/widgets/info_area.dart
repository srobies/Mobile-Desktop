import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../data/models/aggregated_item.dart';
import '../../data/repositories/mdblist_repository.dart';
import '../../preference/user_preferences.dart';
import '../../util/platform_detection.dart';
import 'rating_display.dart';
import 'simple_info_row.dart';

const _textShadows = [Shadow(blurRadius: 4, color: Colors.black54)];

class InfoArea extends StatelessWidget {
  final AggregatedItem? item;

  const InfoArea({super.key, this.item});

  @override
  Widget build(BuildContext context) {
    final item = this.item;
    if (item == null) {
      final isMobile = PlatformDetection.useMobileUi;
      return SizedBox(
        width: double.infinity,
        height: isMobile ? 160 : 190,
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _InfoAreaContent(key: ValueKey(item.id), item: item),
    );
  }
}

class _InfoAreaContent extends StatefulWidget {
  final AggregatedItem item;

  const _InfoAreaContent({super.key, required this.item});

  @override
  State<_InfoAreaContent> createState() => _InfoAreaContentState();
}

class _InfoAreaContentState extends State<_InfoAreaContent> {
  Map<String, double> _ratings = const {};

  @override
  void initState() {
    super.initState();
    _loadRatings();
  }

  Future<void> _loadRatings() async {
    final prefs = GetIt.instance<UserPreferences>();
    if (!prefs.get(UserPreferences.enableAdditionalRatings)) return;

    final tmdbId = widget.item.tmdbId;
    if (tmdbId == null) return;

    final result = await GetIt.instance<MdbListRepository>().getRatings(
      tmdbId: tmdbId,
      mediaType: widget.item.type ?? 'Movie',
    );
    if (mounted && result != null && result.isNotEmpty) {
      setState(() => _ratings = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final theme = Theme.of(context);
    final isMobile = PlatformDetection.useMobileUi;
    final prefs = GetIt.instance<UserPreferences>();

    final showRatings = _ratings.isNotEmpty ||
        item.communityRating != null ||
        item.criticRating != null;

    final title = item.type == 'Episode'
        ? [item.seriesName, item.name]
            .where((s) => s != null && s.isNotEmpty)
            .join(' - ')
        : item.displayTitle;

    final overviewStyle = (isMobile
            ? theme.textTheme.bodySmall
            : theme.textTheme.bodyMedium)
        ?.copyWith(
      color: Colors.white.withValues(alpha: 0.9),
      shadows: _textShadows,
    );
    final overviewLineHeight =
        (overviewStyle?.fontSize ?? 14) * (overviewStyle?.height ?? 1.4);

    return SizedBox(
      width: double.infinity,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
          Text(
            title,
            style: (isMobile
                    ? theme.textTheme.titleLarge
                    : theme.textTheme.headlineSmall)
                ?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              shadows: _textShadows,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          SimpleInfoRow(item: item, showRating: !showRatings),
          const SizedBox(height: 8),
          SizedBox(
            height: 20,
            child: showRatings ? RatingsRow(
              ratings: _ratings,
              communityRating: item.communityRating,
              criticRating: item.criticRating,
              enableAdditionalRatings:
                  prefs.get(UserPreferences.enableAdditionalRatings),
              enabledRatings: prefs.get(UserPreferences.enabledRatings),
              blockedRatings: prefs.get(UserPreferences.blockedRatings),
              showLabels: prefs.get(UserPreferences.showRatingLabels),
            ) : const SizedBox.shrink(),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: overviewLineHeight * 3,
            child: Text(
              item.overview ?? '',
              style: overviewStyle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
