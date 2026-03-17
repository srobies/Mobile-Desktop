class VirtualFolderInfo {
  final String name;
  final String? collectionType;
  final String itemId;
  final List<String> locations;
  final Map<String, dynamic>? libraryOptions;

  const VirtualFolderInfo({
    required this.name,
    this.collectionType,
    this.itemId = '',
    this.locations = const [],
    this.libraryOptions,
  });

  factory VirtualFolderInfo.fromJson(Map<String, dynamic> json) =>
      VirtualFolderInfo(
        name: json['Name'] as String? ?? '',
        collectionType: json['CollectionType'] as String?,
        itemId: json['ItemId'] as String? ?? '',
        locations: _stringList(json['Locations']),
        libraryOptions: json['LibraryOptions'] as Map<String, dynamic>?,
      );

  static List<String> _stringList(dynamic value) {
    if (value is List) return value.cast<String>();
    return const [];
  }
}

class ActivityLogEntry {
  final String id;
  final String name;
  final String? overview;
  final String? shortOverview;
  final String type;
  final DateTime date;
  final String? userId;
  final String severity;

  const ActivityLogEntry({
    required this.id,
    required this.name,
    this.overview,
    this.shortOverview,
    required this.type,
    required this.date,
    this.userId,
    this.severity = 'Information',
  });

  factory ActivityLogEntry.fromJson(Map<String, dynamic> json) =>
      ActivityLogEntry(
        id: (json['Id'] ?? '').toString(),
        name: json['Name'] as String? ?? '',
        overview: json['Overview'] as String?,
        shortOverview: json['ShortOverview'] as String?,
        type: json['Type'] as String? ?? '',
        date: DateTime.parse(json['Date'] as String),
        userId: json['UserId'] as String?,
        severity: json['Severity'] as String? ?? 'Information',
      );
}

class ActivityLogResult {
  final List<ActivityLogEntry> items;
  final int totalRecordCount;

  const ActivityLogResult({
    this.items = const [],
    this.totalRecordCount = 0,
  });

  factory ActivityLogResult.fromJson(Map<String, dynamic> json) =>
      ActivityLogResult(
        items: (json['Items'] as List<dynamic>?)
                ?.map(
                    (e) => ActivityLogEntry.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        totalRecordCount: json['TotalRecordCount'] as int? ?? 0,
      );
}

class LogFileInfo {
  final String name;
  final int size;
  final DateTime dateCreated;
  final DateTime dateModified;

  const LogFileInfo({
    required this.name,
    this.size = 0,
    required this.dateCreated,
    required this.dateModified,
  });

  factory LogFileInfo.fromJson(Map<String, dynamic> json) => LogFileInfo(
        name: json['Name'] as String? ?? '',
        size: json['Size'] as int? ?? 0,
        dateCreated: DateTime.parse(json['DateCreated'] as String),
        dateModified: DateTime.parse(json['DateModified'] as String),
      );
}

class StorageInfo {
  final String programDataPath;
  final String itemsByNamePath;
  final String cachePath;
  final String logPath;
  final String internalMetadataPath;
  final String transcodingTempPath;

  const StorageInfo({
    this.programDataPath = '',
    this.itemsByNamePath = '',
    this.cachePath = '',
    this.logPath = '',
    this.internalMetadataPath = '',
    this.transcodingTempPath = '',
  });

  factory StorageInfo.fromJson(Map<String, dynamic> json) => StorageInfo(
        programDataPath: json['ProgramDataPath'] as String? ?? '',
        itemsByNamePath: json['ItemsByNamePath'] as String? ?? '',
        cachePath: json['CachePath'] as String? ?? '',
        logPath: json['LogPath'] as String? ?? '',
        internalMetadataPath: json['InternalMetadataPath'] as String? ?? '',
        transcodingTempPath: json['TranscodingTempPath'] as String? ?? '',
      );
}
