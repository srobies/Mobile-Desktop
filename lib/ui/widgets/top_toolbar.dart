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
import 'expandable_icon_button.dart';

const _kToolbarHeight = 95.0;
const _kOverscanH = 48.0;
const _kOverscanV = 27.0;
const _kAccent = Color(0xFF00A4DC);
const _kAvatarSize = 36.0;
const _kPillRadius = 24.0;
const _kButtonSpacing = 6.0;

class TopToolbar extends StatefulWidget {
  final String? activeRoute;

  const TopToolbar({super.key, this.activeRoute});

  @override
  State<TopToolbar> createState() => _TopToolbarState();
}

class _TopToolbarState extends State<TopToolbar> {
  final _userRepo = GetIt.instance<UserRepository>();
  final _prefs = GetIt.instance<UserPreferences>();

  final _avatarFocus = FocusNode();
  List<AggregatedLibrary> _libraries = [];
  bool _librariesExpanded = false;
  Timer? _clockTimer;
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
    _avatarFocus.dispose();
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

  bool _isActive(String route) => widget.activeRoute == route;

  @override
  Widget build(BuildContext context) {
    final isTV = PlatformDetection.useLeanbackUi;
    final hPad = isTV ? _kOverscanH : 24.0;
    final vPad = isTV ? _kOverscanV : 12.0;

    return SizedBox(
      height: _kToolbarHeight,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: Row(
            children: [
              Expanded(child: _buildStart()),
              Expanded(flex: 3, child: _buildCenter()),
              Expanded(child: _buildEnd()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStart() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FocusTraversalOrder(
          order: const NumericFocusOrder(0),
          child: _buildAvatar(),
        ),
      ],
    );
  }

  Widget _buildAvatar() {
    return Focus(
      focusNode: _avatarFocus,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          _showUserMenu();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: _showUserMenu,
        child: AnimatedScale(
          scale: _avatarFocus.hasFocus ? 1.15 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            width: _kAvatarSize,
            height: _kAvatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _avatarFocus.hasFocus ? _kAccent : Colors.white.withValues(alpha: 0.3),
                width: _avatarFocus.hasFocus ? 2 : 1,
              ),
            ),
            child: ClipOval(
              child: _userImageUrl != null
                  ? Image.network(
                      _userImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _avatarFallback(),
                    )
                  : _avatarFallback(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatarFallback() {
    final user = _userRepo.currentUser;
    final initial = (user?.name.isNotEmpty == true) ? user!.name[0].toUpperCase() : '?';
    return Container(
      color: _kAccent.withValues(alpha: 0.3),
      alignment: Alignment.center,
      child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  void _showUserMenu() {
    context.push(Destinations.settings);
  }

  Widget _buildCenter() {
    final showShuffle = _prefs.get(UserPreferences.showShuffleButton);
    final showGenres = _prefs.get(UserPreferences.showGenresButton);
    final showFavorites = _prefs.get(UserPreferences.showFavoritesButton);
    final showLibraries = _prefs.get(UserPreferences.showLibrariesInToolbar);
    final showFolders = _prefs.get(UserPreferences.enableFolderView);
    final showSyncPlay = _prefs.get(UserPreferences.syncPlayEnabled);

    int order = 1;

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(_kPillRadius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _orderButton(
                order: (order++).toDouble(),
                child: ExpandableIconButton(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  isActive: _isActive(Destinations.home),
                  onPressed: () => context.go(Destinations.home),
                ),
              ),
              _gap(),
              _orderButton(
                order: (order++).toDouble(),
                child: ExpandableIconButton(
                  icon: Icons.search_rounded,
                  label: 'Search',
                  isActive: _isActive(Destinations.search),
                  onPressed: () => context.push(Destinations.search),
                ),
              ),
              if (showShuffle) ...[
                _gap(),
                _orderButton(
                  order: (order++).toDouble(),
                  child: ExpandableIconButton(
                    icon: Icons.shuffle_rounded,
                    label: 'Shuffle',
                    onPressed: _onShuffle,
                  ),
                ),
              ],
              if (showGenres) ...[
                _gap(),
                _orderButton(
                  order: (order++).toDouble(),
                  child: ExpandableIconButton(
                    icon: Icons.theater_comedy_rounded,
                    label: 'Genres',
                    isActive: _isActive(Destinations.allGenres),
                    onPressed: () => context.push(Destinations.allGenres),
                  ),
                ),
              ],
              if (showFavorites) ...[
                _gap(),
                _orderButton(
                  order: (order++).toDouble(),
                  child: ExpandableIconButton(
                    icon: Icons.favorite_rounded,
                    label: 'Favorites',
                    isActive: _isActive(Destinations.allFavorites),
                    onPressed: () => context.push(Destinations.allFavorites),
                  ),
                ),
              ],
              if (showFolders) ...[
                _gap(),
                _orderButton(
                  order: (order++).toDouble(),
                  child: ExpandableIconButton(
                    icon: Icons.folder_rounded,
                    label: 'Folders',
                    isActive: _isActive(Destinations.folderView),
                    onPressed: () => context.push(Destinations.folderView),
                  ),
                ),
              ],
              if (showSyncPlay) ...[
                _gap(),
                _orderButton(
                  order: (order++).toDouble(),
                  child: ExpandableIconButton(
                    icon: Icons.groups_rounded,
                    label: 'SyncPlay',
                    onPressed: () {},
                  ),
                ),
              ],
              if (showLibraries && _libraries.isNotEmpty) ...[
                _gap(),
                _orderButton(
                  order: (order++).toDouble(),
                  child: _buildLibrariesButton(),
                ),
              ],
              _gap(),
              _orderButton(
                order: 99,
                child: ExpandableIconButton(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  isActive: _isActive(Destinations.settings),
                  onPressed: () => context.push(Destinations.settings),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLibrariesButton() {
    return _LibrariesExpandableButton(
      libraries: _libraries,
      isExpanded: _librariesExpanded,
      onToggle: () => setState(() => _librariesExpanded = !_librariesExpanded),
      onLibraryTap: (lib) {
        setState(() => _librariesExpanded = false);
        if (lib.collectionType == 'music') {
          context.push('/music/${lib.id}');
        } else {
          context.push('/library/${lib.id}');
        }
      },
    );
  }

  void _onShuffle() {}

  Widget _buildEnd() {
    final clockBehavior = _prefs.get(UserPreferences.clockBehavior);
    final showClock = clockBehavior == ClockBehavior.always ||
        clockBehavior == ClockBehavior.inMenus;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showClock)
          Text(
            _currentTime,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
      ],
    );
  }

  Widget _gap() => const SizedBox(width: _kButtonSpacing);

  Widget _orderButton({required double order, required Widget child}) {
    return FocusTraversalOrder(
      order: NumericFocusOrder(order),
      child: child,
    );
  }
}

class _LibrariesExpandableButton extends StatelessWidget {
  final List<AggregatedLibrary> libraries;
  final bool isExpanded;
  final VoidCallback onToggle;
  final ValueChanged<AggregatedLibrary> onLibraryTap;

  const _LibrariesExpandableButton({
    required this.libraries,
    required this.isExpanded,
    required this.onToggle,
    required this.onLibraryTap,
  });

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

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExpandableIconButton(
          icon: isExpanded ? Icons.expand_less_rounded : Icons.video_library_rounded,
          label: 'Libraries',
          isActive: isExpanded,
          onPressed: onToggle,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: isExpanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: libraries
                          .map((lib) => _LibraryChip(
                                library: lib,
                                icon: _libraryIcon(lib.collectionType),
                                onTap: () => onLibraryTap(lib),
                              ))
                          .toList(),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _LibraryChip extends StatefulWidget {
  final AggregatedLibrary library;
  final IconData icon;
  final VoidCallback onTap;

  const _LibraryChip({
    required this.library,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_LibraryChip> createState() => _LibraryChipState();
}

class _LibraryChipState extends State<_LibraryChip> {
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.enter)) {
            widget.onTap();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _isFocused
                  ? _kAccent.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isFocused ? _kAccent : Colors.transparent,
                width: _isFocused ? 1.5 : 0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  size: 16,
                  color: _isFocused ? _kAccent : Colors.white.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
                Text(
                  widget.library.name,
                  style: TextStyle(
                    fontSize: 12,
                    color: _isFocused ? Colors.white : Colors.white.withValues(alpha: 0.7),
                    fontWeight: _isFocused ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
