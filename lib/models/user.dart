class AppUser {
  final String uid;
  String displayName;
  String email;
  String? photoUrl;
  DateTime createdAt;

  AppUser({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      uid: json['uid'] as String,
      displayName: json['displayName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      photoUrl: json['photoUrl'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  AppUser copyWith({
    String? displayName,
    String? email,
    String? photoUrl,
    bool clearPhoto = false,
  }) {
    return AppUser(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: clearPhoto ? null : (photoUrl ?? this.photoUrl),
      createdAt: createdAt,
    );
  }
}
