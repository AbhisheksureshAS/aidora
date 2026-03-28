import 'package:cloud_firestore/cloud_firestore.dart';

DateTime _parseDateTime(dynamic value) {
  if (value == null) return DateTime.fromMillisecondsSinceEpoch(0);
  if (value is Timestamp) return value.toDate();
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return DateTime.now();
}

DateTime? _parseOptionalDateTime(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return null;
}

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String receiverId;
  final String receiverName;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final bool isRead;
  final String? chatRoomId;  // Chat room ID for organizing messages

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.receiverId,
    required this.receiverName,
    required this.content,
    this.type = MessageType.text,
    required this.timestamp,
    this.isRead = false,
    this.chatRoomId,
  });

  factory ChatMessage.fromFirebase(Map<String, dynamic> data, String id) {
    return ChatMessage(
      id: id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      receiverId: data['receiverId'] ?? '',
      receiverName: data['receiverName'] ?? '',
      content: data['content'] ?? '',
      type: MessageType.values.firstWhere(
        (type) => type.name == data['type'],
        orElse: () => MessageType.text,
      ),
      timestamp: _parseDateTime(data['timestamp']),
      isRead: data['isRead'] ?? false,
      chatRoomId: data['chatRoomId'], // Chat room ID from Firebase
    );
  }

  Map<String, dynamic> toFirebase() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'content': content,
      'type': type.name,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isRead': isRead,
      'chatRoomId': chatRoomId,
    };
  }

  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? receiverId,
    String? receiverName,
    String? content,
    MessageType? type,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }
}

enum MessageType {
  text,
  image,
  location,
  system,
}

class ChatRoom {
  final String id;
  final List<String> participants;
  final List<String> participantNames;
  final String? helpRequestId;
  final String? helpRequestTitle;
  final DateTime lastMessageTime;
  final String? lastMessage;
  final String? lastMessageSenderId;
  final int unreadCount;
  final DateTime createdAt;
  final DateTime? completedAt; // Added for 7-day expiration

  ChatRoom({
    required this.id,
    required this.participants,
    required this.participantNames,
    this.helpRequestId,
    this.helpRequestTitle,
    required this.lastMessageTime,
    this.lastMessage,
    this.lastMessageSenderId,
    this.unreadCount = 0,
    required this.createdAt,
    this.completedAt,
  });

  factory ChatRoom.fromFirebase(Map<String, dynamic> data, String id) {
    return ChatRoom(
      id: id,
      participants: List<String>.from(data['participants'] ?? []),
      participantNames: List<String>.from(data['participantNames'] ?? []),
      helpRequestId: data['helpRequestId'],
      helpRequestTitle: data['helpRequestTitle'],
      lastMessageTime: _parseDateTime(data['lastMessageTime']),
      lastMessage: data['lastMessage'],
      lastMessageSenderId: data['lastMessageSenderId'],
      unreadCount: data['unreadCount'] ?? 0,
      createdAt: _parseDateTime(data['createdAt']),
      completedAt: _parseOptionalDateTime(data['completedAt']),
    );
  }

  Map<String, dynamic> toFirebase() {
    return {
      'participants': participants,
      'participantNames': participantNames,
      'helpRequestId': helpRequestId,
      'helpRequestTitle': helpRequestTitle,
      'lastMessageTime': lastMessageTime.millisecondsSinceEpoch,
      'lastMessage': lastMessage,
      'lastMessageSenderId': lastMessageSenderId,
      'unreadCount': unreadCount,
      'createdAt': createdAt.millisecondsSinceEpoch,
      if (completedAt != null) 'completedAt': completedAt!.millisecondsSinceEpoch,
    };
  }

  ChatRoom copyWith({
    String? id,
    List<String>? participants,
    List<String>? participantNames,
    String? helpRequestId,
    String? helpRequestTitle,
    DateTime? lastMessageTime,
    String? lastMessage,
    String? lastMessageSenderId,
    int? unreadCount,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return ChatRoom(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      participantNames: participantNames ?? this.participantNames,
      helpRequestId: helpRequestId ?? this.helpRequestId,
      helpRequestTitle: helpRequestTitle ?? this.helpRequestTitle,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  String get otherParticipantName {
    if (participantNames.length >= 2) {
      return participantNames.firstWhere(
        (name) => name != participantNames.last,
        orElse: () => participantNames.first,
      );
    }
    return 'Unknown';
  }

  String get displayTitle {
    if (helpRequestTitle != null && helpRequestTitle!.isNotEmpty) {
      return helpRequestTitle!;
    }
    return otherParticipantName;
  }
}
