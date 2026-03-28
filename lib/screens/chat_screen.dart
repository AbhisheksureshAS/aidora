import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_model.dart';
import '../theme/app_theme.dart';
import 'public_profile_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  
  ChatRoom? _selectedChatRoom;
  final Set<String> _markedReadMessageIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    
    return PopScope(
      canPop: _selectedChatRoom == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedChatRoom != null) {
          setState(() {
            _selectedChatRoom = null;
          });
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: _selectedChatRoom != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _selectedChatRoom = null;
                    });
                  },
                )
              : null,
          title: Text(_selectedChatRoom?.displayTitle ?? 'Messages', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            if (_selectedChatRoom != null)
              IconButton(
                icon: const Icon(Icons.info_outline, color: Colors.white),
                onPressed: _showChatInfo,
              ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.darkPurple,
                AppTheme.primaryBlack,
              ],
              stops: const [0.0, 0.4],
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 100),
              Expanded(
                child: user == null
                    ? const Center(child: Text('Please login to view messages', style: TextStyle(color: Colors.white70)))
                    : _selectedChatRoom == null
                        ? _buildChatRoomsList(user)
                        : _buildChatInterface(user),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatRoomsList(User user) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('chat_rooms')
          .where('participants', arrayContains: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          final errorText = snapshot.error.toString();
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  errorText.toLowerCase().contains('index')
                      ? 'Missing Firestore index for chat rooms query'
                      : 'Error loading chats: $errorText',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Retry loading chats
                    setState(() {});
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.hourglass_empty, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Loading conversations...',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final chatRooms = snapshot.data!.docs
            .map((doc) => ChatRoom.fromFirebase(doc.data() as Map<String, dynamic>, doc.id))
            .where((room) {
              if (room.completedAt == null) return true;
              final expirationDate = room.completedAt!.add(const Duration(days: 7));
              return DateTime.now().isBefore(expirationDate);
            })
            .toList();
            
        // Sort locally to bypass Firestore index requirement
        chatRooms.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));

        if (chatRooms.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'No conversations yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start a conversation by accepting a help request',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
               SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/requests');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('View Requests'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: chatRooms.length,
          itemBuilder: (context, index) {
            final chatRoom = chatRooms[index];
            return ChatRoomCard(
              chatRoom: chatRoom,
              currentUserId: user.uid,
              onTap: () => _openChatRoom(chatRoom),
            );
          },
        );
      },
    );
  }

  Widget _buildChatInterface(User user) {
    return Column(
      children: [
        _buildChatHeader(user),
        
        if (_selectedChatRoom?.completedAt != null)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            width: double.infinity,
            color: Colors.amber.withOpacity(0.15),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Task completed. Chat will be deleted after 7 days.',
                    style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

          // Messages List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chat_messages')
                  .where('chatRoomId', isEqualTo: _selectedChatRoom!.id)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryPurple),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading messages',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.red[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please try again',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.red[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.chat_bubble_outline,
                            size: 56,
                            color: AppTheme.primaryPurple,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Start a conversation',
                          style: TextStyle(
                            fontSize: 22,
                            color: AppTheme.primaryPurple,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Send your first message to begin helping',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.darkPurple.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data!.docs
                    .map((doc) {
                      return ChatMessage.fromFirebase(doc.data() as Map<String, dynamic>, doc.id);
                    })
                    .toList();

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _markMessagesAsRead(user.uid, messages);
                });

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == user.uid;
                    
                    return MessageBubble(
                      message: message,
                      isMe: isMe,
                    );
                  },
                );
              },
            ),
          ),

          // Message Input
          StreamBuilder<DocumentSnapshot>(
            stream: _selectedChatRoom!.helpRequestId != null 
                ? _firestore.collection('help_requests').doc(_selectedChatRoom!.helpRequestId).snapshots()
                : const Stream.empty(),
            builder: (context, snapshot) {
              bool isCompleted = false;
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                isCompleted = data['status'] == 'completed';
              }

              if (isCompleted) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryBlack,
                    border: Border(
                      top: BorderSide(color: AppTheme.primaryPurple.withValues(alpha: 0.2)),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline, color: AppTheme.textSecondary.withValues(alpha: 0.6), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Task is completed. Chat is closed.',
                          style: TextStyle(
                            color: AppTheme.textSecondary.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryBlack,
                  border: Border(
                    top: BorderSide(color: AppTheme.primaryPurple.withValues(alpha: 0.2)),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryBlack.withValues(alpha: 0.5),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.attach_file, color: AppTheme.primaryPurple),
                        onPressed: () {}, // TODO: Implement file attachment
                      ),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlack,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                            ),
                          ),
                          child: TextField(
                            controller: _messageController,
                            style: const TextStyle(color: AppTheme.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6)),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              fillColor: Colors.transparent,
                              filled: true,
                            ),
                            maxLines: null,
                            textCapitalization: TextCapitalization.sentences,
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryPurple,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white),
                          onPressed: _sendMessage,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      );
    }

  Widget _buildChatHeader(User currentUser) {
    final otherParticipantId = _selectedChatRoom!.participants
        .firstWhere((id) => id != currentUser.uid, orElse: () => '');

    if (otherParticipantId.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(otherParticipantId).snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
        final profileImageUrl = userData['profileImageUrl'] as String?;
        final rating = (userData['rating'] ?? 0.0).toDouble();
        final name = userData['name'] ?? 'User';
        
        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: otherParticipantId)),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.secondaryBlack,
              border: Border(
                bottom: BorderSide(color: AppTheme.primaryPurple.withValues(alpha: 0.2)),
              ),
            ),
            child: Column(
              children: [
                Hero(
                  tag: 'avatar_$otherParticipantId',
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.1),
                    backgroundImage: (profileImageUrl != null && profileImageUrl.isNotEmpty)
                        ? (profileImageUrl.startsWith('assets/') 
                            ? AssetImage(profileImageUrl) as ImageProvider
                            : NetworkImage(profileImageUrl))
                        : null,
                    child: (profileImageUrl == null || profileImageUrl.isEmpty)
                        ? const Icon(Icons.person, color: Colors.white24, size: 36)
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _headerBadge(Icons.star, Colors.amber, '${rating.toStringAsFixed(1)}'),
                    const SizedBox(width: 16),
                    _headerBadge(Icons.verified_user, AppTheme.accentPurple, 'Trusted'),
                    const SizedBox(width: 16),
                    InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: otherParticipantId)),
                        );
                      },
                      child: Text(
                        'Full Profile >',
                        style: TextStyle(color: AppTheme.accentPurple.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _headerBadge(IconData icon, Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _openChatRoom(ChatRoom chatRoom) async {
    // Check if this chat room is associated with a help request
    if (chatRoom.helpRequestId != null && chatRoom.helpRequestId!.isNotEmpty) {
      try {
        // Check the help request status
        final requestDoc = await _firestore
            .collection('help_requests')
            .doc(chatRoom.helpRequestId)
            .get();
        
        if (requestDoc.exists) {
          final requestData = requestDoc.data() as Map<String, dynamic>;
          final status = requestData['status'] as String?;
          
          // Only allow chat if request is accepted or completed
          if (status != 'accepted' && status != 'completed') {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Chat will be available after helper accepts request'),
                  backgroundColor: AppTheme.warningColor,
                  duration: Duration(seconds: 3),
                ),
              );
            }
            return; // Don't open the chat
          }
        }
      } catch (e) {
        // If we can't check the status, allow the chat (fallback behavior)
        print('Error checking request status: $e');
      }
    }
    
    // Open the chat room if security check passes
    setState(() {
      _selectedChatRoom = chatRoom;
    });
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _selectedChatRoom == null) return;

    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final message = ChatMessage(
        id: '',
        senderId: user.uid,
        senderName: user.displayName ?? user.email!.split('@')[0],
        receiverId: _selectedChatRoom!.participants.firstWhere((id) => id != user.uid),
        receiverName: _selectedChatRoom!.otherParticipantName,
        content: _messageController.text.trim(),
        timestamp: DateTime.now(),
        chatRoomId: _selectedChatRoom!.id,
      );

      // Send message
      await _firestore.collection('chat_messages').add(message.toFirebase());

      // Update chat room
      await _firestore.collection('chat_rooms').doc(_selectedChatRoom!.id).update({
        'lastMessageTime': DateTime.now().millisecondsSinceEpoch,
        'lastMessage': message.content,
        'lastMessageSenderId': message.senderId,
      });

      _messageController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending message: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _markMessagesAsRead(String userId, List<ChatMessage> messages) async {
    final unreadMessages = messages.where(
      (message) =>
          message.receiverId == userId &&
          !message.isRead &&
          !_markedReadMessageIds.contains(message.id),
    );

    final batch = _firestore.batch();
    int writeCount = 0;
    for (final message in unreadMessages) {
      _markedReadMessageIds.add(message.id);
      batch.update(_firestore.collection('chat_messages').doc(message.id), {'isRead': true});
      writeCount++;
    }

    if (writeCount > 0) {
      await batch.commit();
    }
  }

  void _showChatInfo() async {
    if (_selectedChatRoom == null) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Find the other participant (helper)
    final otherParticipantId = _selectedChatRoom!.participants
        .firstWhere((id) => id != currentUser.uid, orElse: () => '');

    if (otherParticipantId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not find helper information')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Helper Profile', style: TextStyle(color: AppTheme.textPrimary)),
        content: FutureBuilder<List<dynamic>>(
          future: Future.wait([
            _firestore.collection('users').doc(otherParticipantId).get(),
            _firestore.collection('help_requests')
                .where('helperId', isEqualTo: otherParticipantId)
                .get(),
            _firestore.collection('ratings')
                .where('toUserId', isEqualTo: otherParticipantId)
                .get(),
          ]),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.hasError) {
              return const Text('Helper information not found', style: TextStyle(color: AppTheme.textSecondary));
            }

            final userDoc = snapshot.data![0] as DocumentSnapshot;
            if (!userDoc.exists) {
              return const Text('Helper information not found', style: TextStyle(color: AppTheme.textSecondary));
            }

            final userData = userDoc.data() as Map<String, dynamic>;
            final requestsSnap = snapshot.data![1] as QuerySnapshot;
            final ratingsSnap = snapshot.data![2] as QuerySnapshot;

            final name = userData['name'] ?? 'Unknown';
            final rating = (userData['rating'] ?? 0.0).toDouble();
            final actualReviewCount = ratingsSnap.docs.length;
            
            // Strictly count tasks where this user was the Helper and status is completed or Completed
            final rawDocs = requestsSnap.docs.map((d) => d.data() as Map<String, dynamic>);
            final completedTasks = rawDocs.where((d) => 
                (d['helperId'] == otherParticipantId) &&
                (d['status']?.toString().toLowerCase() == 'completed')
            ).length;
            final skills = List<String>.from(userData['skills'] ?? []);

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Rating
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '($actualReviewCount reviews)',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Completed Tasks
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppTheme.successColor, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        '$completedTasks completed tasks',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Skills
                  if (skills.isNotEmpty) ...[
                    Text(
                      'Skills',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: skills.map((skill) => Chip(
                        label: Text(
                          skill,
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: AppTheme.primaryPurple.withOpacity(0.1),
                        side: BorderSide(color: AppTheme.primaryPurple.withOpacity(0.3)),
                      )).toList(),
                    ),
                  ],

                  // Help Request Info
                  if (_selectedChatRoom!.helpRequestTitle != null) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    Text(
                      'Help Request',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(_selectedChatRoom!.helpRequestTitle!),
                  ],
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class ChatRoomCard extends StatelessWidget {
  final ChatRoom chatRoom;
  final String currentUserId;
  final VoidCallback onTap;

  const ChatRoomCard({
    super.key,
    required this.chatRoom,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final otherParticipantId = chatRoom.participants.firstWhere((id) => id != currentUserId, orElse: () => '');
    
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(otherParticipantId).snapshots(),
      builder: (context, userSnapshot) {
        String? profileImageUrl;
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          final data = userSnapshot.data!.data() as Map<String, dynamic>;
          profileImageUrl = data['profileImageUrl'];
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('chat_messages')
              .where('chatRoomId', isEqualTo: chatRoom.id)
              .where('receiverId', isEqualTo: currentUserId)
              .where('isRead', isEqualTo: false)
              .snapshots(),
          builder: (context, snapshot) {
            final unreadCount = snapshot.hasData ? snapshot.data!.docs.length : 0;

            return InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.secondaryBlack,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: unreadCount > 0 
                        ? AppTheme.accentPurple 
                        : Colors.white.withValues(alpha: 0.1),
                    width: unreadCount > 0 ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppTheme.primaryBlack,
                          radius: 28,
                          backgroundImage: (profileImageUrl != null && profileImageUrl.isNotEmpty)
                              ? (profileImageUrl.startsWith('assets/') 
                                  ? AssetImage(profileImageUrl) as ImageProvider
                                  : NetworkImage(profileImageUrl))
                              : null,
                          child: (profileImageUrl == null || profileImageUrl.isEmpty)
                              ? Icon(Icons.person, color: Colors.white.withValues(alpha: 0.2), size: 28)
                              : null,
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryPurple,
                                border: Border.all(color: AppTheme.cardColor, width: 2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
        
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  chatRoom.displayTitle,
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (unreadCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.redAccent.withValues(alpha: 0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (chatRoom.lastMessage != null)
                            Text(
                              chatRoom.lastMessage!,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: unreadCount > 0 ? AppTheme.accentWhite : AppTheme.textSecondary,
                                fontWeight: unreadCount > 0 ? FontWeight.w500 : null,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            )
                          else
                            Text(
                              'No messages yet',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondary.withValues(alpha: 0.7),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatTime(chatRoom.lastMessageTime),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: unreadCount > 0 ? AppTheme.primaryPurple : AppTheme.textSecondary,
                            fontWeight: unreadCount > 0 ? FontWeight.w600 : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (unreadCount > 0)
                          const Icon(
                            Icons.mark_as_unread,
                            size: 16,
                            color: AppTheme.primaryPurple,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }
}

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            // Sender avatar
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(message.senderId).snapshots(),
              builder: (context, snapshot) {
                String? profileImageUrl;
                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  profileImageUrl = data['profileImageUrl'];
                }

                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: message.senderId)),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppTheme.secondaryBlack,
                      backgroundImage: (profileImageUrl != null && profileImageUrl.isNotEmpty)
                          ? (profileImageUrl.startsWith('assets/') 
                              ? AssetImage(profileImageUrl) as ImageProvider
                              : NetworkImage(profileImageUrl))
                          : null,
                      child: (profileImageUrl == null || profileImageUrl.isEmpty)
                          ? const Icon(Icons.person, color: Colors.white24, size: 16)
                          : null,
                    ),
                  ),
                );
              },
            ),
          ],
          
          // Message bubble
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: isMe 
                    ? AppTheme.primaryPurple  // App's primary purple
                    : AppTheme.secondaryBlack, // Deep theme variant
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
                  bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
                ),
                border: !isMe ? Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.2)) : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sender name for received messages
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(left: 16, top: 8, right: 16),
                      child: Text(
                        message.senderName,
                        style: const TextStyle(
                          color: AppTheme.accentPurple,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  
                  // Message content
                  Padding(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: isMe ? 10 : 6,
                      bottom: 6,
                    ),
                    child: Text(
                      message.content,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                      ),
                    ),
                  ),
                  
                  // Time and read status
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatMessageTime(message.timestamp),
                          style: TextStyle(
                            color: isMe 
                                ? AppTheme.accentWhite.withValues(alpha: 0.8)
                                : AppTheme.textSecondary.withValues(alpha: 0.6),
                            fontSize: 11,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            message.isRead ? Icons.done_all : Icons.done,
                            size: 14,
                            color: message.isRead 
                                ? AppTheme.accentPurple 
                                : AppTheme.accentWhite.withValues(alpha: 0.8),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
