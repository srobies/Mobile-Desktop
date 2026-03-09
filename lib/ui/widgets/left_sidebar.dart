import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:server_core/server_core.dart';

import '../../auth/repositories/user_repository.dart';
import '../../data/models/aggregated_library.dart';
import '../../data/repositories/user_views_repository.dart';
import '../../preference/preference_constants.dart';
import '../../preference/user_preferences.dart';
import '../../util/platform_detection.dart';
import '../navigation/destinations.dart';

const _kCollapsedWidth = 56.0;
const _kExpandedWidth = 280.0;
const _kExpandDuration = Duration(milliseconds: 250);
const _kLabelDelay = Duration(milliseconds: 150);
const _kAccent = Color(0xFF00A4DC);
const _kAvatarSize = 32.0;
const _kIconBoxSize = 32.0;
const _kItemHeight = 48.0;
const _kItemBorderRadius = 24.0;

class LeftSidebar extends StatefulWidget {
  final String? activeRoute;
  final FocusNode? contentFocusNode;

  const LeftSidebar({super.key, this.activeRoute, this.contentFocusNode});

  @override
  State<LeftSidebar> createState() => _LeftSidebarState();
}

class _LeftSidebarState extends State<LeftSidebar> {
  final _userRepo = GetIt.instance<UserRepository>();
  final _prefs = GetIt.instance<UserPreferences>();
  final _sidebarFocus = FocusScopeNode(debugLabel: 'LeftSidebar');
  final _scrollController = ScrollController();

  List<AggregatedLibrary> _libraries = [];
  bool _isExpanded = false;
  bool _showLabels = false;
  bool _librariesExpanded = false;
  Timer? _clockTimer;
  Timer? _labelTimer;
  String _currentTime = '';
  StreamSubscription? _userSub;
  String? _userImageUrl;

  @override
  void initState() {
    super.initState();
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) => _updateClock());
    _loadUserImage();
    _userSub = _userRepo.currentUserStream.listen((_) => _loadUserImage());
    _loadLibraries();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _labelTimer?.cancel();
    _sidebarFocus.dispose();
    _scrollController.dispose();
    _userSub?.cancel();
    super.dispose();
  }

  void _updateClock() {
    final now = DateTime.now();
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    if (mounted) setState(() => _currentTime = '$hour:$minute $period');
  }

  void _loadUserImage() {
    final user = _userRepo.currentUser;
    if (user == null) {
      setState(() => _userImageUrl = null);
      return;
    }
    try {
      final client = GetIt.instance<MediaServerClient>();
      setState(() => _userImageUrl = client.imageApi.getUserImageUrl(user.id));
    } catch (_) {
      setState(() => _userImageUrl = null);
    }
  }

  Future<void> _loadLibraries() async {
    try {
      final viewsRepo = GetIt.instance<UserViewsRepository>();
      final libs = await viewsRepo.getUserViews();
      if (mounted) setState(() => _libraries = libs);
    } catch (_) {}
  }

  void _expand() {
    if (_isExpanded) return;
    setState(() => _isExpanded = true);
    _labelTimer?.cancel();
    _labelTimer = Timer(_kLabelDelay, () {
      if (mounted) setState(() => _showLabels = true);
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: _kExpandDuration, curve: Curves.easeInOut);
    }
  }

  void _collapse() {
    if (!_isExpanded) return;
    _labelTimer?.cancel();
    setState(() {
      _isExpanded = false;
      _showLabels = false;
      _librariesExpanded = false;
    });
  }

  void _onSidebarFocusChange(bool hasFocus) {
    if (hasFocus) {
      _expand();
    } else {
      _collapse();
    }
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _collapse();
      widget.contentFocusNode?.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  bool _isActive(String route) => widget.activeRoute == route;

  @override
  Widget build(BuildContext context) {
    final isTV = PlatformDetection.useLeanbackUi;
    final topPad = isTV ? 27.0 : 12.0;

    final clockBehavior = _prefs.get(UserPreferences.clockBehavior);
    final showClock = clockBehavior == ClockBehavior.always ||
        clockBehavior == ClockBehavior.inMenus;

    return MouseRegion(
      onEnter: (_) => _expand(),
      onExit: (_) {
        if (!_sidebarFocus.hasFocus) _collapse();
      },
      child: FocusScope(
        node: _sidebarFocus,
        onFocusChange: _onSidebarFocusChange,
        onKeyEvent: _onKeyEvent,
        child: AnimatedContainer(
          duration: _kExpandDuration,
          curve: Curves.easeInOut,
          width: _isExpanded ? _kExpandedWidth : _kCollapsedWidth,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: _isExpanded
                ? const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color.fromRGBO(0, 0, 0, 0.9),
                      Color.fromRGBO(0, 0, 0, 0.7),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.7, 1.0],
                  )
                : null,
          ),
          child: Padding(
            padding: EdgeInsets.only(top: topPad),
            child: Stack(
              children: [
                _buildItemList(),
                if (showClock && _isExpanded)
                  Positioned(
                    top: 8,
                    right: 12,
                    child: Text(
                      _currentTime,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemList() {
    final showShuffle = _prefs.get(UserPreferences.showShuffleButton);
    final showGenres = _prefs.get(UserPreferences.showGenresButton);
    final showFavorites = _prefs.get(UserPreferences.showFavoritesButton);
    final showLibraries = _prefs.get(UserPreferences.showLibrariesInToolbar);
    final showFolders = _prefs.get(UserPreferences.enableFolderView);
    final showSyncPlay = _prefs.get(UserPreferences.syncPlayEnabled);

    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            children: [
              _buildAvatar(),
              const SizedBox(height: 8),
              _SidebarIconItem(
                icon: Icons.home_rounded,
                label: 'Home',
                showLabel: _showLabels,
                isActive: _isActive(Destinations.home),
                onPressed: () => context.go(Destinations.home),
              ),
              _SidebarIconItem(
                icon: Icons.search_rounded,
                label: 'Search',
                showLabel: _showLabels,
                isActive: _isActive(Destinations.search),
                onPressed: () => context.push(Destinations.search),
              ),
              if (showShuffle)
                _SidebarIconItem(
                  icon: Icons.shuffle_rounded,
                  label: 'Shuffle',
                  showLabel: _showLabels,
                  onPressed: () {},
                ),
              if (showGenres)
                _SidebarIconItem(
                  icon: Icons.theater_comedy_rounded,
                  label: 'Genres',
                  showLabel: _showLabels,
                  isActive: _isActive(Destinations.allGenres),
                  onPressed: () => context.push(Destinations.allGenres),
                ),
              if (showFavorites)
                _SidebarIconItem(
                  icon: Icons.favorite_rounded,
                  label: 'Favorites',
                  showLabel: _showLabels,
                  isActive: _isActive(Destinations.allFavorites),
                  onPressed: () => context.push(Destinations.allFavorites),
                ),
              if (showFolders)
                _SidebarIconItem(
                  icon: Icons.folder_rounded,
                  label: 'Folders',
                  showLabel: _showLabels,
                  isActive: _isActive(Destinations.folderView),
                  onPressed: () => context.push(Destinations.folderView),
                ),
              if (showSyncPlay)
                _SidebarIconItem(
                  icon: Icons.groups_rounded,
                  label: 'SyncPlay',
                  showLabel: _showLabels,
                  onPressed: () {},
                ),
              if (showLibraries && _libraries.isNotEmpty) ...[
                _SidebarIconItem(
                  icon: _librariesExpanded
                      ? Icons.expand_less_rounded
                      : Icons.video_library_rounded,
                  label: 'Libraries',
                  showLabel: _showLabels,
                  isActive: _librariesExpanded,
                  onPressed: () => setState(() => _librariesExpanded = !_librariesExpanded),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: _librariesExpanded
                      ? Column(
                          children: _libraries
                              .map((lib) => _SidebarTextItem(
                                    label: lib.name,
                                    icon: _libraryIcon(lib.collectionType),
                                    showLabel: _showLabels,
                                    onPressed: () {
                                      if (lib.collectionType == 'music') {
                                        context.push('/music/${lib.id}');
                                      } else {
                                        context.push('/library/${lib.id}');
                                      }
                                    },
                                  ))
                              .toList(),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _SidebarIconItem(
            icon: Icons.settings_rounded,
            label: 'Settings',
            showLabel: _showLabels,
            isActive: _isActive(Destinations.settings),
            onPressed: () => context.push(Destinations.settings),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAvatar() {
    final user = _userRepo.currentUser;
    final initial = (user?.name.isNotEmpty == true) ? user!.name[0].toUpperCase() : '?';
    final fallback = Container(
      color: _kAccent.withValues(alpha: 0.3),
      alignment: Alignment.center,
      child: Text(initial,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GestureDetector(
        onTap: () => context.push(Destinations.settings),
        child: Row(
          children: [
            SizedBox(
              width: _kIconBoxSize + 8,
              child: Center(
                child: Container(
                  width: _kAvatarSize,
                  height: _kAvatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: ClipOval(
                    child: _userImageUrl != null
                        ? Image.network(
                            _userImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => fallback,
                          )
                        : fallback,
                  ),
                ),
              ),
            ),
            if (_showLabels) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  user?.name ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _libraryIcon(String collectionType) {
    return switch (collectionType) {
      'movies' => Icons.movie_rounded,
      'tvshows' => Icons.tv_rounded,
      'music' => Icons.music_note_rounded,
      'books' => Icons.book_rounded,
      'photos' => Icons.photo_library_rounded,
      'homevideos' => Icons.videocam_rounded,
      'livetv' => Icons.live_tv_rounded,
      _ => Icons.video_library_rounded,
    };
  }
}

class _SidebarIconItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool showLabel;
  final bool isActive;
  final VoidCallback onPressed;

  const _SidebarIconItem({
    required this.icon,
    required this.label,
    required this.showLabel,
    this.isActive = false,
    required this.onPressed,
  });

  @override
  State<_SidebarIconItem> createState() => _SidebarIconItemState();
}

class _SidebarIconItemState extends State<_SidebarIconItem> {
  final _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() => _isFocused = _focusNode.hasFocus));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fgColor = widget.isActive
        ? _kAccent
        : _isFocused
            ? Colors.white
            : Colors.white.withValues(alpha: 0.7);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.enter)) {
            widget.onPressed();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: _kItemHeight,
            decoration: BoxDecoration(
              color: _isFocused
                  ? Colors.white.withValues(alpha: 0.12)
                  : widget.isActive
                      ? _kAccent.withValues(alpha: 0.15)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(_kItemBorderRadius),
              border: Border.all(
                color: _isFocused ? _kAccent : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: _kIconBoxSize + 8,
                  child: Center(
                    child: Icon(widget.icon, size: 22, color: fgColor),
                  ),
                ),
                if (widget.showLabel) ...[
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        color: fgColor,
                        fontSize: 14,
                        fontWeight: _isFocused || widget.isActive
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarTextItem extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool showLabel;
  final VoidCallback onPressed;

  const _SidebarTextItem({
    required this.label,
    required this.icon,
    required this.showLabel,
    required this.onPressed,
  });

  @override
  State<_SidebarTextItem> createState() => _SidebarTextItemState();
}

class _SidebarTextItemState extends State<_SidebarTextItem> {
  final _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() => _isFocused = _focusNode.hasFocus));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fgColor = _isFocused ? Colors.white : Colors.white.withValues(alpha: 0.6);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.enter)) {
            widget.onPressed();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 40,
            decoration: BoxDecoration(
              color: _isFocused ? _kAccent.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const SizedBox(width: 48),
                Icon(widget.icon, size: 18, color: fgColor),
                if (widget.showLabel) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        color: fgColor,
                        fontSize: 13,
                        fontWeight: _isFocused ? FontWeight.w600 : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
