class UserModel {
  final String uid;
  final String email;
  final String name;
  final String? profileImageUrl;
  final List<String> skills;
  final String bio;
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final double rating;
  final int totalRatings;
  final bool isHelperEnabled;
  final int helperPoints;
  final List<String> unlockedAvatars;
  final DateTime createdAt;
  final DateTime lastActive;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    this.profileImageUrl,
    this.skills = const [],
    this.bio = '',
    this.latitude,
    this.longitude,
    this.locationName,
    this.rating = 0.0,
    this.totalRatings = 0,
    this.isHelperEnabled = false,
    this.helperPoints = 0,
    this.unlockedAvatars = const [],
    required this.createdAt,
    required this.lastActive,
  });

  factory UserModel.fromFirebase(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      profileImageUrl: data['profileImageUrl'],
      skills: List<String>.from(data['skills'] ?? []),
      bio: data['bio'] ?? '',
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      locationName: data['locationName'],
      rating: (data['rating'] ?? 0).toDouble(),
      totalRatings: data['totalRatings'] ?? 0,
      isHelperEnabled: data['isHelperEnabled'] ?? false,
      helperPoints: data['helperPoints'] ?? 0,
      unlockedAvatars: List<String>.from(data['unlockedAvatars'] ?? []),
      createdAt: DateTime.fromMillisecondsSinceEpoch(data['createdAt'] ?? 0),
      lastActive: DateTime.fromMillisecondsSinceEpoch(data['lastActive'] ?? 0),
    );
  }

  Map<String, dynamic> toFirebase() {
    return {
      'email': email,
      'name': name,
      'profileImageUrl': profileImageUrl,
      'skills': skills,
      'bio': bio,
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
      'rating': rating,
      'totalRatings': totalRatings,
      'isHelperEnabled': isHelperEnabled,
      'helperPoints': helperPoints,
      'unlockedAvatars': unlockedAvatars,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastActive': lastActive.millisecondsSinceEpoch,
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? profileImageUrl,
    List<String>? skills,
    String? bio,
    double? latitude,
    double? longitude,
    String? locationName,
    double? rating,
    int? totalRatings,
    bool? isHelperEnabled,
    int? helperPoints,
    List<String>? unlockedAvatars,
    DateTime? createdAt,
    DateTime? lastActive,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      skills: skills ?? this.skills,
      bio: bio ?? this.bio,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
      rating: rating ?? this.rating,
      totalRatings: totalRatings ?? this.totalRatings,
      isHelperEnabled: isHelperEnabled ?? this.isHelperEnabled,
      helperPoints: helperPoints ?? this.helperPoints,
      unlockedAvatars: unlockedAvatars ?? this.unlockedAvatars,
      createdAt: createdAt ?? this.createdAt,
      lastActive: lastActive ?? this.lastActive,
    );
  }
}
