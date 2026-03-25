# Flutter Plugin Sync Defaults

This document lists every setting the Flutter client reads from Moonfin plugin sync, plus the default value Flutter uses when the preference is unset or there is no plugin installed.

Scope:

- Flutter sync consumer: `lib/data/services/plugin_sync_service.dart`
- Flutter defaults: `lib/preference/user_preferences.dart`
- Structured defaults: `lib/preference/home_section_config.dart`, `lib/preference/seerr_row_config.dart`
- Preference fallback behavior: `packages/preference/lib/src/store/preference_store.dart`
- Plugin repo compared against: `Moonfin-Client/Plugin` on GitHub, current `main`

## Resolution Rules

When a synced preference has never been written locally, Flutter falls back to the preference's `defaultValue`.

- Primitive preferences: `PreferenceStore.get()` returns stored value or `defaultValue`
- Enum preferences: `_getEnumDynamic()` returns stored enum value or `defaultValue`
- `homeRowOrder`: falls back to `HomeSectionConfig.defaults()` when `home_sections_config` is empty or invalid
- `jellyseerrRows.rowOrder`: falls back to `SeerrRowConfig.defaults()` when `rows_config` is empty or invalid

Important behavior:

- If the plugin is not installed, `syncOnLogin()` returns early and does not overwrite anything.
- That means defaults apply only for unset preferences. Previously synced local values remain until changed or cleared.

## Directly Synced Settings

| Server key | Flutter storage | Flutter default with no local value | In current plugin repo schema | Verified plugin/web built-in default | Notes |
| --- | --- | --- | --- | --- | --- |
| `navbarPosition` | `UserPreferences.navbarPosition` | `top` | Yes | `top` | Matches plugin web default. |
| `showClock` | `UserPreferences.showClock` | `true` | Yes | `true` | Matches plugin web default. |
| `use24HourClock` | `UserPreferences.use24HourClock` | `false` | Yes | `false` | Matches plugin web default. |
| `showShuffleButton` | `UserPreferences.showShuffleButton` | `true` | Yes | `true` | Matches plugin web default. |
| `showGenresButton` | `UserPreferences.showGenresButton` | `true` | Yes | `true` | Matches plugin web default. |
| `showFavoritesButton` | `UserPreferences.showFavoritesButton` | `true` | Yes | `true` | Matches plugin web default. |
| `showSyncPlayButton` | `UserPreferences.showSyncPlayButton` | `false` | Yes | `true` | Flutter default differs from plugin web default. |
| `showLibrariesInToolbar` | `UserPreferences.showLibrariesInToolbar` | `true` | Yes | `true` | Matches plugin web default. |
| `shuffleContentType` | `UserPreferences.shuffleContentType` | `both` | Yes | `both` | Matches plugin web default. |
| `mergeContinueWatchingNextUp` | `UserPreferences.mergeContinueWatchingNextUp` | `false` | Yes | Not surfaced in retrieved plugin defaults block | Present in plugin schema and README synced settings list. |
| `enableMultiServerLibraries` | `UserPreferences.enableMultiServerLibraries` | `false` | Yes | Not surfaced in retrieved plugin defaults block | Present in plugin schema and README synced settings list. |
| `enableFolderView` | `UserPreferences.enableFolderView` | `false` | Yes | Not surfaced in retrieved plugin defaults block | Present in plugin schema. |
| `confirmExit` | `UserPreferences.confirmExit` | `true` | Yes | `true` | Matches plugin web default. |
| `seasonalSurprise` | `UserPreferences.seasonalSurprise` | `none` | Yes | `none` | Matches plugin web default. |
| `mediaBarEnabled` | `UserPreferences.mediaBarEnabled` | `true` | Yes | `false` | Flutter default differs from plugin web default. |
| `mediaBarSourceType` | `UserPreferences.mediaBarContentType` | `both` | Yes | `library` | Flutter uses a broader local value space than plugin web. |
| `mediaBarItemCount` | `UserPreferences.mediaBarItemCount` | `10` | Yes | `10` | Stored as string in Flutter, int in sync payload. |
| `mediaBarOpacity` | `UserPreferences.navbarOpacity` | `50` | Yes | `50` | Shared with Flutter `navbarOpacity`. |
| `mediaBarOverlayColor` | `UserPreferences.navbarColor` | `gray` | Yes | `gray` | Shared with Flutter `navbarColor`. |
| `navbarOpacity` | `UserPreferences.navbarOpacity` | `50` | No | No evidence in current plugin repo | Flutter accepts it, but current plugin repo snippets only expose `mediaBarOpacity`. |
| `navbarColor` | `UserPreferences.navbarColor` | `gray` | No | No evidence in current plugin repo | Flutter accepts it, but current plugin repo snippets only expose `mediaBarOverlayColor`. |
| `mediaBarAutoAdvance` | `UserPreferences.mediaBarAutoAdvance` | `true` | Yes | `true` | Matches plugin web default. |
| `mediaBarIntervalMs` | `UserPreferences.mediaBarIntervalMs` | `7000` | Yes | `7000` | Matches plugin web default. |
| `mediaBarTrailerPreview` | `UserPreferences.mediaBarTrailerPreview` | `true` | Yes | `true` | Confirmed in current plugin repo. |
| `episodePreviewEnabled` | `UserPreferences.episodePreviewEnabled` | `true` | No | No evidence in current plugin repo | Flutter syncs this key, but it was not found in the current plugin schema or web defaults. |
| `previewAudioEnabled` | `UserPreferences.previewAudioEnabled` | `true` | No | No evidence in current plugin repo | Flutter syncs this key, but it was not found in the current plugin schema or web defaults. |
| `mediaBarLibraryIds` | `UserPreferences.mediaBarLibraryIds` | empty CSV / `[]` | Yes | `[]` | Stored as comma-separated string locally. |
| `mediaBarCollectionIds` | `UserPreferences.mediaBarCollectionIds` | empty CSV / `[]` | Yes | `[]` | Stored as comma-separated string locally. |
| `mediaBarExcludedGenres` | `UserPreferences.mediaBarExcludedGenres` | empty CSV / `[]` | Yes | `[]` | Stored as comma-separated string locally. |
| `themeMusicEnabled` | `UserPreferences.themeMusicEnabled` | `false` | Yes | Not surfaced in retrieved plugin defaults block | Present in plugin schema. |
| `themeMusicVolume` | `UserPreferences.themeMusicVolume` | `30` | Yes | Not surfaced in retrieved plugin defaults block | Present in plugin schema. |
| `themeMusicOnHomeRows` | `UserPreferences.themeMusicOnHomeRows` | `false` | Yes | Not surfaced in retrieved plugin defaults block | Present in plugin schema. |
| `homeRowsImageTypeOverride` | `UserPreferences.homeRowsUniversalOverride` | `false` | Yes | Not surfaced in retrieved plugin defaults block | Present in plugin schema and README synced settings list. |
| `homeRowsImageType` | `UserPreferences.homeRowsUniversalImageType` | `thumb` | Yes | Not surfaced in retrieved plugin defaults block | Flutter enum default is `ImageType.thumb`. |
| `backdropEnabled` | `UserPreferences.backdropEnabled` | `true` | Yes | `true` | Matches plugin web default. |
| `detailsScreenBlur` | `UserPreferences.detailsBackgroundBlurAmount` | `10` | Yes | Not surfaced in retrieved plugin defaults block | Synced as string, stored as int in Flutter. |
| `browsingBlur` | `UserPreferences.browsingBackgroundBlurAmount` | `10` | Yes | Not surfaced in retrieved plugin defaults block | Synced as string, stored as int in Flutter. |
| `mdblistEnabled` | `UserPreferences.enableAdditionalRatings` | `false` | Yes | `false` | Matches plugin web default. |
| `mdblistApiKey` | `UserPreferences.mdblistApiKey` | empty string | Yes | empty string | Plugin-supplied or synced from the server; Flutter does not expose manual API key entry. |
| `mdblistShowRatingNames` | `UserPreferences.showRatingLabels` | `true` | Yes | `true` | Matches plugin web default. |
| `tmdbEpisodeRatingsEnabled` | `UserPreferences.enableEpisodeRatings` | `false` | Yes | `false` | Matches plugin web default. |
| `tmdbApiKey` | `UserPreferences.tmdbApiKey` | empty string | Yes | empty string | Plugin-supplied or synced from the server; Flutter does not expose manual API key entry. |
| `jellyseerrEnabled` | `UserPreferences.seerrEnabled` | `false` | Yes | Not surfaced in retrieved plugin defaults block | Present in plugin schema. |

## Structured Synced Settings

### `mdblistRatingSources`

- Server key: `mdblistRatingSources`
- Flutter storage: `UserPreferences.enabledRatings`
- Flutter default: `tomatoes,stars`
- Current plugin repo default: `['imdb', 'tmdb', 'tomatoes', 'metacritic']`
- Status: confirmed mismatch between Flutter fallback and plugin web built-in default

### `blockedRatings`

- Server key: `blockedRatings`
- Flutter storage: `UserPreferences.blockedRatings`
- Flutter default: empty string, which behaves as an empty list
- Current plugin repo schema: present
- Current plugin repo built-in default: not surfaced in retrieved defaults block

### `homeRowOrder`

- Server key: `homeRowOrder`
- Flutter storage: `UserPreferences.homeSectionsJson`
- Flutter fallback source: `HomeSectionConfig.defaults()`
- Flutter default enabled order:
  - `resume`
  - `nextUp`
  - `liveTv`
  - `latestMedia`
- Flutter default disabled rows:
  - `recentlyReleased`
  - `libraryTilesSmall`
  - `libraryButtons`
  - `resumeAudio`
  - `resumeBook`
  - `activeRecordings`
  - `playlists`
- Current plugin repo built-in default: `['smalllibrarytiles', 'resume', 'resumeaudio', 'resumebook', 'livetv', 'nextup', 'latestmedia']`
- Status: confirmed mismatch between Flutter fallback and plugin web built-in default

### `jellyseerrRows.rowOrder`

- Server key: `jellyseerrRows.rowOrder`
- Flutter storage: `SeerrPreferences.rowsConfig`
- Flutter fallback source: `SeerrRowConfig.defaults()`
- Flutter default enabled order:
  - `recentRequests`
  - `trending`
  - `popularMovies`
  - `movieGenres`
  - `upcomingMovies`
  - `studios`
  - `popularSeries`
  - `seriesGenres`
  - `upcomingSeries`
  - `networks`
- Current plugin repo schema: present
- Current plugin repo built-in default: not found in retrieved snippets

## Additional Login-Synced Values

These are not part of `_applyServerSettings()`, but they are updated during `syncOnLogin()`.

| Value | Storage | Flutter default when unset | Source endpoint | Notes |
| --- | --- | --- | --- | --- |
| `variant` | `SeerrPreferences.moonfinVariant` | `seerr` after normalization | `/Moonfin/Jellyseerr/Config` | Getter normalizes null or unknown values to `seerr`, while plugin response type defaults to `jellyseerr`. |
| `displayName` | `SeerrPreferences.moonfinDisplayName` | empty string | `/Moonfin/Jellyseerr/Config` | Only written when non-empty. |

## Summary

Confirmed in the current Flutter client:

- All synced Flutter preferences have a local default.
- `mediaBarTrailerPreview` is a real plugin-side synced key.
- `episodePreviewEnabled` and `previewAudioEnabled` appear to be Flutter-side sync keys that are not present in the current `Moonfin-Client/Plugin` schema or web defaults.
- MDBList and TMDB API key values are expected to come from plugin sync or server-side plugin defaults, not from manual entry in Flutter.

Confirmed mismatches between Flutter fallback defaults and plugin web built-ins:

- `mediaBarEnabled`: Flutter `true`, plugin web `false`
- `mediaBarSourceType`: Flutter `both`, plugin web `library`
- `showSyncPlayButton`: Flutter `false`, plugin web `true`
- `mdblistRatingSources`: Flutter `tomatoes,stars`, plugin web `imdb,tmdb,tomatoes,metacritic`
- `homeRowOrder`: Flutter fallback ordering differs from plugin web default ordering
