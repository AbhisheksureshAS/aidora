enum NotificationType {
  newRequest('New Request', 'notifications_active'),
  requestAccepted('Request Accepted', 'check_circle'),
  requestCompleted('Request Completed', 'task_alt'),
  newMessage('New Message', 'chat'),
  ratingReceived('Rating Received', 'star'),
  helperNearby('Helper Nearby', 'person_nearby'),
  urgentRequest('Urgent Request', 'emergency'),
  system('System', 'info');

  const NotificationType(this.displayName, this.iconName);
  final String displayName;
  final String iconName;
}

class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final NotificationType type;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? expiresAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.data,
    this.isRead = false,
    required this.createdAt,
    this.expiresAt,
  });

  factory AppNotification.fromFirebase(Map<String, dynamic> data, String id) {
    return AppNotification(
      id: id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      type: NotificationType.values.firstWhere(
        (type) => type.name == data['type'],
        orElse: () => NotificationType.system,
      ),
      data: data['data'],
      isRead: data['isRead'] ?? false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(data['createdAt'] ?? 0),
      expiresAt: data['expiresAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['expiresAt'])
          : null,
    );
  }

  Map<String, dynamic> toFirebase() {
    return {
      'userId': userId,
      'title': title,
      'body': body,
      'type': type.name,
      'data': data,
      'isRead': isRead,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'expiresAt': expiresAt?.millisecondsSinceEpoch,
    };
  }

  AppNotification copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    NotificationType? type,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
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
}

class PushNotificationSettings {
  final bool newRequests;
  final bool requestUpdates;
  final bool newMessages;
  final bool ratings;
  final bool nearbyHelpers;
  final bool urgentRequests;
  final bool systemNotifications;

  PushNotificationSettings({
    this.newRequests = true,
    this.requestUpdates = true,
    this.newMessages = true,
    this.ratings = true,
    this.nearbyHelpers = false,
    this.urgentRequests = true,
    this.systemNotifications = true,
  });

  factory PushNotificationSettings.fromFirebase(Map<String, dynamic> data) {
    return PushNotificationSettings(
      newRequests: data['newRequests'] ?? true,
      requestUpdates: data['requestUpdates'] ?? true,
      newMessages: data['newMessages'] ?? true,
      ratings: data['ratings'] ?? true,
      nearbyHelpers: data['nearbyHelpers'] ?? false,
      urgentRequests: data['urgentRequests'] ?? true,
      systemNotifications: data['systemNotifications'] ?? true,
    );
  }

  Map<String, dynamic> toFirebase() {
    return {
      'newRequests': newRequests,
      'requestUpdates': requestUpdates,
      'newMessages': newMessages,
      'ratings': ratings,
      'nearbyHelpers': nearbyHelpers,
      'urgentRequests': urgentRequests,
      'systemNotifications': systemNotifications,
    };
  }

  PushNotificationSettings copyWith({
    bool? newRequests,
    bool? requestUpdates,
    bool? newMessages,
    bool? ratings,
    bool? nearbyHelpers,
    bool? urgentRequests,
    bool? systemNotifications,
  }) {
    return PushNotificationSettings(
      newRequests: newRequests ?? this.newRequests,
      requestUpdates: requestUpdates ?? this.requestUpdates,
      newMessages: newMessages ?? this.newMessages,
      ratings: ratings ?? this.ratings,
      nearbyHelpers: nearbyHelpers ?? this.nearbyHelpers,
      urgentRequests: urgentRequests ?? this.urgentRequests,
      systemNotifications: systemNotifications ?? this.systemNotifications,
    );
  }
}
