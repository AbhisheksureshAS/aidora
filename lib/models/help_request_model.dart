enum RequestCategory {
  academic('Academic', 'school'),
  dailyTask('Daily Task', 'shopping_bag'),
  emergency('Emergency', 'emergency'),
  skillLearning('Skill Learning', 'computer');

  const RequestCategory(this.displayName, this.iconName);
  final String displayName;
  final String iconName;
}

enum RequestUrgency {
  low('Low', 1),
  medium('Medium', 2),
  high('High', 3);

  const RequestUrgency(this.displayName, this.level);
  final String displayName;
  final int level;
}

enum RequestStatus {
  pending('Pending'),
  accepted('Accepted'),
  inProgress('In Progress'),
  completed('Completed'),
  cancelled('Cancelled');

  const RequestStatus(this.displayName);
  final String displayName;
}

class HelpRequestModel {
  final String id;
  final String seekerId;
  final String seekerName;
  final String seekerEmail;
  final String title;
  final String description;
  final RequestCategory category;
  final RequestUrgency urgency;
  final RequestStatus status;
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final String? helperId;
  final String? helperName;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final double? offeredAmount;
  final List<String> requiredSkills;

  HelpRequestModel({
    required this.id,
    required this.seekerId,
    required this.seekerName,
    required this.seekerEmail,
    required this.title,
    required this.description,
    required this.category,
    required this.urgency,
    this.status = RequestStatus.pending,
    this.latitude,
    this.longitude,
    this.locationName,
    this.helperId,
    this.helperName,
    required this.createdAt,
    this.acceptedAt,
    this.completedAt,
    this.offeredAmount,
    this.requiredSkills = const [],
  });

  factory HelpRequestModel.fromFirebase(Map<String, dynamic> data, String id) {
    return HelpRequestModel(
      id: id,
      seekerId: data['seekerId'] ?? '',
      seekerName: data['seekerName'] ?? '',
      seekerEmail: data['seekerEmail'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: RequestCategory.values.firstWhere(
        (cat) => cat.name == data['category'],
        orElse: () => RequestCategory.dailyTask,
      ),
      urgency: RequestUrgency.values.firstWhere(
        (urg) => urg.name == data['urgency'],
        orElse: () => RequestUrgency.medium,
      ),
      status: RequestStatus.values.firstWhere(
        (stat) => stat.name == data['status'],
        orElse: () => RequestStatus.pending,
      ),
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      locationName: data['locationName'],
      helperId: data['helperId'],
      helperName: data['helperName'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(data['createdAt'] ?? 0),
      acceptedAt: data['acceptedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['acceptedAt'])
          : null,
      completedAt: data['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['completedAt'])
          : null,
      offeredAmount: data['offeredAmount']?.toDouble(),
      requiredSkills: List<String>.from(data['requiredSkills'] ?? []),
    );
  }

  Map<String, dynamic> toFirebase() {
    return {
      'seekerId': seekerId,
      'seekerName': seekerName,
      'seekerEmail': seekerEmail,
      'title': title,
      'description': description,
      'category': category.name,
      'urgency': urgency.name,
      'status': status.name,
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
      'helperId': helperId,
      'helperName': helperName,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'acceptedAt': acceptedAt?.millisecondsSinceEpoch,
      'completedAt': completedAt?.millisecondsSinceEpoch,
      'offeredAmount': offeredAmount,
      'requiredSkills': requiredSkills,
    };
  }

  HelpRequestModel copyWith({
    String? id,
    String? seekerId,
    String? seekerName,
    String? seekerEmail,
    String? title,
    String? description,
    RequestCategory? category,
    RequestUrgency? urgency,
    RequestStatus? status,
    double? latitude,
    double? longitude,
    String? locationName,
    String? helperId,
    String? helperName,
    DateTime? createdAt,
    DateTime? acceptedAt,
    DateTime? completedAt,
    double? offeredAmount,
    List<String>? requiredSkills,
  }) {
    return HelpRequestModel(
      id: id ?? this.id,
      seekerId: seekerId ?? this.seekerId,
      seekerName: seekerName ?? this.seekerName,
      seekerEmail: seekerEmail ?? this.seekerEmail,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      urgency: urgency ?? this.urgency,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
      helperId: helperId ?? this.helperId,
      helperName: helperName ?? this.helperName,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      completedAt: completedAt ?? this.completedAt,
      offeredAmount: offeredAmount ?? this.offeredAmount,
      requiredSkills: requiredSkills ?? this.requiredSkills,
    );
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }

  bool get isActive {
    return status == RequestStatus.pending || status == RequestStatus.accepted;
  }
}
