class RatingModel {
  final String id;
  final String fromUserId;
  final String fromUserName;
  final String toUserId;
  final String toUserName;
  final String helpRequestId;
  final String helpRequestTitle;
  final double rating; // 1.0 to 5.0
  final String? feedback;
  final List<RatingCriteria> criteria;
  final DateTime createdAt;
  final bool isPublic;

  RatingModel({
    required this.id,
    required this.fromUserId,
    required this.fromUserName,
    required this.toUserId,
    required this.toUserName,
    required this.helpRequestId,
    required this.helpRequestTitle,
    required this.rating,
    this.feedback,
    this.criteria = const [],
    required this.createdAt,
    this.isPublic = true,
  });

  factory RatingModel.fromFirebase(Map<String, dynamic> data, String id) {
    return RatingModel(
      id: id,
      fromUserId: data['fromUserId'] ?? '',
      fromUserName: data['fromUserName'] ?? '',
      toUserId: data['toUserId'] ?? '',
      toUserName: data['toUserName'] ?? '',
      helpRequestId: data['helpRequestId'] ?? '',
      helpRequestTitle: data['helpRequestTitle'] ?? '',
      rating: (data['rating'] ?? 0).toDouble(),
      feedback: data['feedback'],
      criteria: (data['criteria'] as List<dynamic>?)
          ?.map((c) => RatingCriteria.fromFirebase(c as Map<String, dynamic>))
          .toList() ?? [],
      createdAt: DateTime.fromMillisecondsSinceEpoch(data['createdAt'] ?? 0),
      isPublic: data['isPublic'] ?? true,
    );
  }

  Map<String, dynamic> toFirebase() {
    return {
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'toUserId': toUserId,
      'toUserName': toUserName,
      'helpRequestId': helpRequestId,
      'helpRequestTitle': helpRequestTitle,
      'rating': rating,
      'feedback': feedback,
      'criteria': criteria.map((c) => c.toFirebase()).toList(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'isPublic': isPublic,
    };
  }

  RatingModel copyWith({
    String? id,
    String? fromUserId,
    String? fromUserName,
    String? toUserId,
    String? toUserName,
    String? helpRequestId,
    String? helpRequestTitle,
    double? rating,
    String? feedback,
    List<RatingCriteria>? criteria,
    DateTime? createdAt,
    bool? isPublic,
  }) {
    return RatingModel(
      id: id ?? this.id,
      fromUserId: fromUserId ?? this.fromUserId,
      fromUserName: fromUserName ?? this.fromUserName,
      toUserId: toUserId ?? this.toUserId,
      toUserName: toUserName ?? this.toUserName,
      helpRequestId: helpRequestId ?? this.helpRequestId,
      helpRequestTitle: helpRequestTitle ?? this.helpRequestTitle,
      rating: rating ?? this.rating,
      feedback: feedback ?? this.feedback,
      criteria: criteria ?? this.criteria,
      createdAt: createdAt ?? this.createdAt,
      isPublic: isPublic ?? this.isPublic,
    );
  }
}

class RatingCriteria {
  final String name;
  final double score; // 1.0 to 5.0
  final String? comment;

  RatingCriteria({
    required this.name,
    required this.score,
    this.comment,
  });

  factory RatingCriteria.fromFirebase(Map<String, dynamic> data) {
    return RatingCriteria(
      name: data['name'] ?? '',
      score: (data['score'] ?? 0).toDouble(),
      comment: data['comment'],
    );
  }

  Map<String, dynamic> toFirebase() {
    return {
      'name': name,
      'score': score,
      'comment': comment,
    };
  }
}

enum EthicalScore {
  excellent(5.0, 'Excellent'),
  good(4.0, 'Good'),
  average(3.0, 'Average'),
  poor(2.0, 'Poor'),
  veryPoor(1.0, 'Very Poor');

  const EthicalScore(this.value, this.displayName);
  final double value;
  final String displayName;

  static EthicalScore fromValue(double value) {
    if (value >= 4.5) return EthicalScore.excellent;
    if (value >= 3.5) return EthicalScore.good;
    if (value >= 2.5) return EthicalScore.average;
    if (value >= 1.5) return EthicalScore.poor;
    return EthicalScore.veryPoor;
  }
}

class UserReputation {
  final String userId;
  final double overallRating;
  final int totalRatings;
  final double ethicalScore;
  final int completedTasks;
  final int cancelledTasks;
  final double responseRate;
  final double averageResponseTime; // in hours
  final Map<String, double> skillRatings;
  final List<String> badges;
  final DateTime lastUpdated;

  UserReputation({
    required this.userId,
    this.overallRating = 0.0,
    this.totalRatings = 0,
    this.ethicalScore = 0.0,
    this.completedTasks = 0,
    this.cancelledTasks = 0,
    this.responseRate = 0.0,
    this.averageResponseTime = 0.0,
    this.skillRatings = const {},
    this.badges = const [],
    required this.lastUpdated,
  });

  factory UserReputation.fromFirebase(Map<String, dynamic> data, String userId) {
    return UserReputation(
      userId: userId,
      overallRating: (data['overallRating'] ?? 0).toDouble(),
      totalRatings: data['totalRatings'] ?? 0,
      ethicalScore: (data['ethicalScore'] ?? 0).toDouble(),
      completedTasks: data['completedTasks'] ?? 0,
      cancelledTasks: data['cancelledTasks'] ?? 0,
      responseRate: (data['responseRate'] ?? 0).toDouble(),
      averageResponseTime: (data['averageResponseTime'] ?? 0).toDouble(),
      skillRatings: Map<String, double>.from(data['skillRatings'] ?? {}),
      badges: List<String>.from(data['badges'] ?? []),
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(data['lastUpdated'] ?? 0),
    );
  }

  Map<String, dynamic> toFirebase() {
    return {
      'overallRating': overallRating,
      'totalRatings': totalRatings,
      'ethicalScore': ethicalScore,
      'completedTasks': completedTasks,
      'cancelledTasks': cancelledTasks,
      'responseRate': responseRate,
      'averageResponseTime': averageResponseTime,
      'skillRatings': skillRatings,
      'badges': badges,
      'lastUpdated': lastUpdated.millisecondsSinceEpoch,
    };
  }

  UserReputation copyWith({
    String? userId,
    double? overallRating,
    int? totalRatings,
    double? ethicalScore,
    int? completedTasks,
    int? cancelledTasks,
    double? responseRate,
    double? averageResponseTime,
    Map<String, double>? skillRatings,
    List<String>? badges,
    DateTime? lastUpdated,
  }) {
    return UserReputation(
      userId: userId ?? this.userId,
      overallRating: overallRating ?? this.overallRating,
      totalRatings: totalRatings ?? this.totalRatings,
      ethicalScore: ethicalScore ?? this.ethicalScore,
      completedTasks: completedTasks ?? this.completedTasks,
      cancelledTasks: cancelledTasks ?? this.cancelledTasks,
      responseRate: responseRate ?? this.responseRate,
      averageResponseTime: averageResponseTime ?? this.averageResponseTime,
      skillRatings: skillRatings ?? this.skillRatings,
      badges: badges ?? this.badges,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  EthicalScore get ethicalScoreLevel => EthicalScore.fromValue(ethicalScore);
  
  double get completionRate {
    final total = completedTasks + cancelledTasks;
    return total > 0 ? completedTasks / total : 0.0;
  }

  String get trustLevel {
    if (overallRating >= 4.5 && ethicalScore >= 4.5 && totalRatings >= 10) {
      return 'Trusted Helper';
    } else if (overallRating >= 4.0 && ethicalScore >= 4.0 && totalRatings >= 5) {
      return 'Reliable Helper';
    } else if (overallRating >= 3.5 && ethicalScore >= 3.5 && totalRatings >= 3) {
      return 'Verified Helper';
    } else if (totalRatings >= 1) {
      return 'New Helper';
    } else {
      return 'Unrated';
    }
  }

  List<String> get earnedBadges {
    List<String> badges = [];
    
    if (totalRatings >= 50) badges.add('Super Helper');
    if (totalRatings >= 25) badges.add('Expert Helper');
    if (totalRatings >= 10) badges.add('Experienced Helper');
    if (totalRatings >= 5) badges.add('Rising Star');
    
    if (overallRating >= 4.8 && totalRatings >= 10) badges.add('Perfect Score');
    if (overallRating >= 4.5 && totalRatings >= 5) badges.add('Top Rated');
    
    if (ethicalScore >= 4.8 && totalRatings >= 10) badges.add('Ethical Champion');
    if (ethicalScore >= 4.5 && totalRatings >= 5) badges.add('Trustworthy');
    
    if (completionRate >= 0.95 && completedTasks >= 20) badges.add('Reliable');
    if (completionRate >= 0.90 && completedTasks >= 10) badges.add('Consistent');
    
    if (responseRate >= 0.9) badges.add('Quick Responder');
    if (averageResponseTime <= 1.0 && completedTasks >= 5) badges.add('Lightning Fast');
    
    return badges;
  }
}

class Badge {
  final String id;
  final String name;
  final String description;
  final String icon;
  final BadgeCategory category;
  final Map<String, dynamic> criteria;

  Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    required this.criteria,
  });

  factory Badge.fromFirebase(Map<String, dynamic> data, String id) {
    return Badge(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      icon: data['icon'] ?? '',
      category: BadgeCategory.values.firstWhere(
        (cat) => cat.name == data['category'],
        orElse: () => BadgeCategory.general,
      ),
      criteria: Map<String, dynamic>.from(data['criteria'] ?? {}),
    );
  }

  Map<String, dynamic> toFirebase() {
    return {
      'name': name,
      'description': description,
      'icon': icon,
      'category': category.name,
      'criteria': criteria,
    };
  }
}

enum BadgeCategory {
  general,
  reliability,
  speed,
  quality,
  ethics,
  community,
}
