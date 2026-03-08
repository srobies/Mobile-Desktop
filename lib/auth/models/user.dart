sealed class User {
  String get id;
  String get name;
  String get serverId;
  String? get imageTag;

  const User();
}

class PrivateUser extends User {
  @override
  final String id;
  @override
  final String name;
  @override
  final String serverId;
  final String accessToken;
  final DateTime lastUsed;
  @override
  final String? imageTag;

  const PrivateUser({
    required this.id,
    required this.name,
    required this.serverId,
    required this.accessToken,
    required this.lastUsed,
    this.imageTag,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'accessToken': accessToken,
        'lastUsed': lastUsed.toIso8601String(),
        'imageTag': imageTag,
      };

  factory PrivateUser.fromJson(
    String id,
    String serverId,
    Map<String, dynamic> json,
  ) {
    return PrivateUser(
      id: id,
      name: json['name'] as String? ?? '',
      serverId: serverId,
      accessToken: json['accessToken'] as String? ?? '',
      lastUsed: DateTime.tryParse(json['lastUsed'] as String? ?? '') ??
          DateTime.now(),
      imageTag: json['imageTag'] as String?,
    );
  }
}

class PublicUser extends User {
  @override
  final String id;
  @override
  final String name;
  @override
  final String serverId;
  final bool hasPassword;
  @override
  final String? imageTag;

  const PublicUser({
    required this.id,
    required this.name,
    required this.serverId,
    required this.hasPassword,
    this.imageTag,
  });
}
