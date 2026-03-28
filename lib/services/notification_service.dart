import 'package:flutter/foundation.dart' show debugPrint;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import '../models/notification_model.dart';
import '../models/help_request_model.dart';
import '../models/chat_model.dart';

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
    required NotificationType type,
    Map<String, dynamic>? data,
    DateTime? expiresAt,
  }) async {
    try {
      final notification = AppNotification(
        id: '',
        userId: userId,
        title: title,
        body: body,
        type: type,
        data: data,
        createdAt: DateTime.now(),
        expiresAt: expiresAt,
      );

      await _firestore.collection('notifications').add(notification.toFirebase());
    } catch (e) {
      debugPrint('Error creating notification: $e');
    }
  }

  static Future<void> notifyNewRequest(HelpRequestModel request) async {
    // Find nearby helpers
    if (request.latitude != null && request.longitude != null) {
      final nearbyHelpers = await _findNearbyHelpers(
        request.latitude!,
        request.longitude!,
        request.requiredSkills,
      );

      for (final helperId in nearbyHelpers) {
        await createNotification(
          userId: helperId,
          title: 'New ${request.category.displayName} Request Nearby',
          body: request.title,
          type: NotificationType.newRequest,
          data: {
            'requestId': request.id,
            'category': request.category.name,
            'urgency': request.urgency.name,
          },
          expiresAt: DateTime.now().add(const Duration(hours: 24)),
        );
      }
    }
  }

  static Future<void> notifyRequestAccepted(HelpRequestModel request) async {
    if (request.helperId == null) return;

    await createNotification(
      userId: request.seekerId,
      title: 'Request Accepted!',
      body: '${request.helperName} has accepted your request',
      type: NotificationType.requestAccepted,
      data: {
        'requestId': request.id,
        'helperId': request.helperId,
        'helperName': request.helperName,
      },
    );
  }

  static Future<void> notifyRequestCompleted(HelpRequestModel request) async {
    if (request.helperId == null) return;

    await createNotification(
      userId: request.seekerId,
      title: 'Request Completed',
      body: 'Your request "${request.title}" has been completed',
      type: NotificationType.requestCompleted,
      data: {
        'requestId': request.id,
        'helperId': request.helperId,
      },
    );

    // Prompt for rating
    await createNotification(
      userId: request.seekerId,
      title: 'Rate Your Helper',
      body: 'Please rate ${request.helperName} for their help',
      type: NotificationType.ratingReceived,
      data: {
        'requestId': request.id,
        'helperId': request.helperId,
        'helperName': request.helperName,
        'action': 'rate',
      },
      expiresAt: DateTime.now().add(const Duration(days: 7)),
    );
  }

  static Future<void> notifyNewMessage(ChatMessage message) async {
    await createNotification(
      userId: message.receiverId,
      title: 'New Message from ${message.senderName}',
      body: message.content,
      type: NotificationType.newMessage,
      data: {
        'messageId': message.id,
        'senderId': message.senderId,
        'senderName': message.senderName,
        'chatRoomId': message.chatRoomId, // Chat room ID from message
      },
    );
  }

  static Future<void> notifyRatingReceived({
    required String helperId,
    required String helperName,
    required double rating,
    required String fromUserName,
  }) async {
    await createNotification(
      userId: helperId,
      title: 'New Rating Received!',
      body: '$fromUserName rated you ${rating.toStringAsFixed(1)} stars',
      type: NotificationType.ratingReceived,
      data: {
        'rating': rating,
        'fromUserName': fromUserName,
      },
    );
  }

  static Future<void> notifyUrgentRequest(HelpRequestModel request) async {
    if (request.urgency.name != 'high') return;

    if (request.latitude != null && request.longitude != null) {
      final nearbyHelpers = await _findNearbyHelpers(
        request.latitude!,
        request.longitude!,
        request.requiredSkills,
        radiusKm: 20.0, // Larger radius for urgent requests
      );

      for (final helperId in nearbyHelpers) {
        await createNotification(
          userId: helperId,
          title: '🚨 Urgent Request Nearby',
          body: request.title,
          type: NotificationType.urgentRequest,
          data: {
            'requestId': request.id,
            'category': request.category.name,
            'urgency': request.urgency.name,
          },
          expiresAt: DateTime.now().add(const Duration(hours: 2)), // Shorter expiry for urgent
        );
      }
    }
  }

  static Future<void> notifyHelperNearby({
    required String userId,
    required String userName,
    required double latitude,
    required double longitude,
    required List<String> skills,
  }) async {
    // Find users with pending requests that match this helper's skills
    final matchingRequests = await _findMatchingRequests(latitude, longitude, skills);

    for (final request in matchingRequests) {
      await createNotification(
        userId: request.seekerId,
        title: 'Helper Nearby',
        body: '$userName is nearby and can help with your request',
        type: NotificationType.helperNearby,
        data: {
          'helperId': userId,
          'helperName': userName,
          'requestId': request.id,
        },
        expiresAt: DateTime.now().add(const Duration(hours: 6)),
      );
    }
  }

  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  static Future<void> markAllNotificationsAsRead(String userId) async {
    try {
      final unreadNotifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in unreadNotifications.docs) {
        await doc.reference.update({'isRead': true});
      }
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  static Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  static Future<void> cleanupExpiredNotifications() async {
    try {
      final now = DateTime.now();
      final expiredNotifications = await _firestore
          .collection('notifications')
          .where('expiresAt', isLessThan: now.millisecondsSinceEpoch)
          .get();

      for (final doc in expiredNotifications.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('Error cleaning up expired notifications: $e');
    }
  }

  static Future<List<String>> _findNearbyHelpers(
    double latitude,
    double longitude,
    List<String> requiredSkills, {
    double radiusKm = 10.0,
  }) async {
    try {
      // Simplified query - only filter by helper status with limit for performance
      final snapshot = await _firestore
          .collection('users')
          .where('isHelperEnabled', isEqualTo: true)
          .limit(50) // Limit for notifications to prevent excessive data transfer
          .get();

      List<String> nearbyHelperIds = [];

      for (final doc in snapshot.docs) {
        final userData = doc.data();
        final helperId = doc.id;
        final helperLatitude = userData['latitude'] as double?;
        final helperLongitude = userData['longitude'] as double?;
        final helperSkills = List<String>.from(userData['skills'] ?? []);

        // Filter by distance in client-side code
        if (helperLatitude != null && helperLongitude != null) {
          final distance = _calculateDistance(
            latitude, longitude, helperLatitude, helperLongitude);

          if (distance <= radiusKm) {
            // Check if helper has required skills
            if (requiredSkills.isEmpty || 
                requiredSkills.any((skill) => helperSkills.contains(skill))) {
              nearbyHelperIds.add(helperId);
            }
          }
        }
      }

      return nearbyHelperIds;
    } catch (e) {
      debugPrint('Error finding nearby helpers: $e');
      return [];
    }
  }

  static Future<List<HelpRequestModel>> _findMatchingRequests(
    double latitude,
    double longitude,
    List<String> helperSkills, {
    double radiusKm = 10.0,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('help_requests')
          .where('status', whereIn: ['pending', 'accepted'])
          .where('latitude', isGreaterThan: latitude - (radiusKm / 111))
          .where('latitude', isLessThan: latitude + (radiusKm / 111))
          .get();

      List<HelpRequestModel> matchingRequests = [];

      for (final doc in snapshot.docs) {
        final requestData = doc.data();
        final request = HelpRequestModel.fromFirebase(requestData, doc.id);

        if (request.latitude != null && request.longitude != null) {
          final distance = _calculateDistance(
            latitude, longitude, request.latitude!, request.longitude!);

          if (distance <= radiusKm) {
            // Check if helper's skills match request requirements
            if (request.requiredSkills.isEmpty || 
                request.requiredSkills.any((skill) => helperSkills.contains(skill))) {
              matchingRequests.add(request);
            }
          }
        }
      }

      return matchingRequests;
    } catch (e) {
      debugPrint('Error finding matching requests: $e');
      return [];
    }
  }

  static double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    
    final double a = 
        (dLat / 2).sin() * (dLat / 2).sin() +
        lat1.cos() * lat2.cos() *
        (dLon / 2).sin() * (dLon / 2).sin();
    
    final double c = 2 * a.sqrt().asin();
    
    return earthRadius * c;
  }

  static double _toRadians(double degrees) {
    return degrees * (3.14159265359 / 180);
  }
}

extension on double {
  double sin() => math.sin(this);
  double cos() => math.cos(this);
  double asin() => math.asin(this);
  double sqrt() => math.sqrt(this);
}
