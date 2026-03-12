import 'package:flutter/foundation.dart';
import 'package:server_core/server_core.dart' hide ImageType;

import '../../preference/preference_constants.dart';
import '../../preference/user_preferences.dart';
import '../models/aggregated_item.dart';
import '../repositories/mdblist_repository.dart';

enum FavoritesState { loading, ready, error }

class FavoritesViewModel extends ChangeNotifier {
  final MediaServerClient _client;
  final UserPreferences _prefs;
  final MdbListRepository _mdbListRepository;

  static const _pageSize = 100;
  static const _prefKey = 'favorites';

  FavoritesState _state = FavoritesState.loading;
  FavoritesState get state => _state;

  List<AggregatedItem> _items = const [];
  List<AggregatedItem> get items => _items;

  int _totalCount = 0;
  int get totalCount => _totalCount;

  bool get hasMore => _items.length < _totalCount;

  bool _loadingMore = false;
  bool get loadingMore => _loadingMore;

  late LibrarySortBy _sortBy;
  LibrarySortBy get sortBy => _sortBy;

  late SortDirection _sortDirection;
  SortDirection get sortDirection => _sortDirection;

  late ImageType _imageType;
  ImageType get imageType => _imageType;

  late PosterSize _posterSize;
  PosterSize get posterSize => _posterSize;

  late FavoriteTypeFilter _typeFilter;
  FavoriteTypeFilter get typeFilter => _typeFilter;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  AggregatedItem? _focusedItem;
  AggregatedItem? get focusedItem => _focusedItem;

  Map<String, double> _focusedRatings = const {};
  Map<String, double> get focusedRatings => _focusedRatings;

  ImageApi get imageApi => _client.imageApi;

  FavoritesViewModel({
    required MediaServerClient client,
    required UserPreferences prefs,
    required MdbListRepository mdbListRepository,
  })  : _client = client,
        _prefs = prefs,
        _mdbListRepository = mdbListRepository {
    _sortBy = _prefs.get(UserPreferences.librarySortBy(_prefKey));
    _sortDirection = _prefs.get(UserPreferences.librarySortDirection(_prefKey));
    _imageType = _prefs.get(UserPreferences.libraryImageType(_prefKey));
    _posterSize = _prefs.get(UserPreferences.posterSize);
    _typeFilter = _prefs.get(UserPreferences.favoriteTypeFilter);
  }

  void setFocusedItem(AggregatedItem? item) {
    _focusedItem = item;
    _focusedRatings = const {};
    notifyListeners();
    if (item != null) _loadFocusedRatings(item);
  }

  Future<void> _loadFocusedRatings(AggregatedItem item) async {
    if (!_prefs.get(UserPreferences.enableAdditionalRatings)) return;
    final tmdbId = item.tmdbId;
    if (tmdbId == null) return;
    final mediaType = item.type;
    if (mediaType == null) return;
    final ratings = await _mdbListRepository.getRatings(
      tmdbId: tmdbId,
      mediaType: mediaType,
    );
    if (ratings != null && ratings.isNotEmpty && _focusedItem?.id == item.id) {
      _focusedRatings = ratings;
      notifyListeners();
    }
  }

  Future<void> load() async {
    _state = FavoritesState.loading;
    _items = const [];
    _totalCount = 0;
    notifyListeners();

    try {
      await _fetchPage(0);
      _state = FavoritesState.ready;
    } catch (e) {
      _errorMessage = e.toString();
      _state = FavoritesState.error;
    }
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (_loadingMore || !hasMore) return;
    _loadingMore = true;
    notifyListeners();

    try {
      await _fetchPage(_items.length);
    } catch (_) {}

    _loadingMore = false;
    notifyListeners();
  }

  Future<void> _fetchPage(int startIndex) async {
    final response = await _client.itemsApi.getItems(
      sortBy: _sortBy.apiValue,
      sortOrder: _sortDirection == SortDirection.ascending ? 'Ascending' : 'Descending',
      startIndex: startIndex,
      limit: _pageSize,
      recursive: true,
      isFavorite: true,
      includeItemTypes: _typeFilter.itemTypes,
      fields: 'PrimaryImageAspectRatio,BasicSyncInfo,Overview,Genres,CommunityRating,OfficialRating,RunTimeTicks,ProductionYear,Status,ImageTags,BackdropImageTags,ParentBackdropItemId,ParentBackdropImageTags,CriticRating,ProviderIds',
    );

    final rawItems = (response['Items'] as List?) ?? [];
    _totalCount = response['TotalRecordCount'] as int? ?? rawItems.length;

    final mapped = rawItems.cast<Map<String, dynamic>>().map((raw) => AggregatedItem(
      id: raw['Id'] as String,
      serverId: _client.baseUrl,
      rawData: raw,
    )).toList();

    if (startIndex == 0) {
      _items = mapped;
    } else {
      _items = [..._items, ...mapped];
    }
  }

  Future<void> setSortBy(LibrarySortBy value) async {
    if (_sortBy == value) return;
    _sortBy = value;
    await _prefs.set(UserPreferences.librarySortBy(_prefKey), value);
    await load();
  }

  Future<void> setSortDirection(SortDirection value) async {
    if (_sortDirection == value) return;
    _sortDirection = value;
    await _prefs.set(UserPreferences.librarySortDirection(_prefKey), value);
    await load();
  }

  Future<void> toggleSortDirection() => setSortDirection(
    _sortDirection == SortDirection.ascending
        ? SortDirection.descending
        : SortDirection.ascending,
  );

  Future<void> setImageType(ImageType value) async {
    if (_imageType == value) return;
    _imageType = value;
    await _prefs.set(UserPreferences.libraryImageType(_prefKey), value);
    notifyListeners();
  }

  Future<void> setPosterSize(PosterSize value) async {
    if (_posterSize == value) return;
    _posterSize = value;
    await _prefs.set(UserPreferences.posterSize, value);
    notifyListeners();
  }

  Future<void> setTypeFilter(FavoriteTypeFilter value) async {
    if (_typeFilter == value) return;
    _typeFilter = value;
    _focusedItem = null;
    await _prefs.set(UserPreferences.favoriteTypeFilter, value);
    await load();
  }

  String get statusText {
    final typeLabel = _typeFilter == FavoriteTypeFilter.all
        ? 'all favorites'
        : '${_typeFilter.displayName} favorites';
    return 'Showing $typeLabel sorted by ${_sortBy.displayName}';
  }

  String get counterText => '${_items.length} | $_totalCount';
}
