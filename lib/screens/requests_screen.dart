import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/help_request_model.dart';
import '../models/notification_model.dart';
import 'rating_screen.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class RequestsTab extends StatefulWidget {
  const RequestsTab({super.key});

  @override
  State<RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<RequestsTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const Color _bgColor = AppTheme.primaryBlack;
  static const Color _surfaceColor = AppTheme.secondaryBlack;
  static const Color _surfaceSoftColor = AppTheme.cardDark;
  
  RequestCategory? _selectedCategory;
  RequestUrgency? _selectedUrgency;
  bool _showCompletedOnly = false;
  RequestListScope _selectedScope = RequestListScope.all;
  bool _isFilterExpanded = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Please login'));

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(user.uid).snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          return const Center(child: Text('User profile not found'));
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
        final isHelperEnabled = userData['isHelperEnabled'] ?? false;

        // Show tasks for all users. Accept action remains helper-gated.
        return StreamBuilder<QuerySnapshot>(
          stream: (_showCompletedOnly
                  ? _firestore
                      .collection('help_requests')
                      .where('status', isEqualTo: RequestStatus.completed.name)
                  : _firestore
                      .collection('help_requests')
                      .where('status', whereIn: [
                        RequestStatus.pending.name,
                        RequestStatus.accepted.name,
                      ]))
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            // Removed redundant loading spinner during filter transitions for a seamless feel.

            if (snapshot.hasError) {
              final errorText = snapshot.error.toString();
              final isIndexError = errorText.toLowerCase().contains('index') ||
                  errorText.toLowerCase().contains('failed-precondition');
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 56,
                        color: AppTheme.warningColor,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isIndexError
                            ? 'Missing Firestore index for this query.'
                            : 'Error loading requests.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        errorText,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              );
            }

            final docs = snapshot.data?.docs ?? [];
            final requests = docs
                .map((doc) => HelpRequestModel.fromFirebase(doc.data() as Map<String, dynamic>, doc.id))
                .where((request) {
                  final oneDayAgo = DateTime.now().subtract(const Duration(days: 1));
                  
                  // Global Look: Only tasks from the last 24 hours
                  if (request.createdAt.isBefore(oneDayAgo)) return false;

                  if (_showCompletedOnly) {
                    // Filter: Completed
                    if (request.status != RequestStatus.completed) return false;
                    // Completed tasks: only show those you were part of
                    return request.seekerId == user.uid || request.helperId == user.uid;
                  } else {
                    // Filter: Open (Pending or Accepted)
                    if (request.status == RequestStatus.completed) return false;
                    
                    if (request.status == RequestStatus.accepted) {
                      // Privacy: Accepted tasks ONLY for those involved
                      return request.seekerId == user.uid || request.helperId == user.uid;
                    }
                    
                    // Targeted Requests: If a seeker targeted a specific helper, hide it from the public
                    if (request.helperId != null && request.helperId!.isNotEmpty) {
                      return request.seekerId == user.uid || request.helperId == user.uid;
                    }

                    return true;
                  }
                })
                .where((request) => _selectedCategory == null || request.category == _selectedCategory)
                .where((request) => _selectedUrgency == null || request.urgency == _selectedUrgency)
                .where((request) {
                  switch (_selectedScope) {
                    case RequestListScope.all:
                      return true;
                    case RequestListScope.myRequests:
                      return request.seekerId == user.uid;
                    case RequestListScope.acceptedByMe:
                      return request.helperId == user.uid;
                  }
                })
                .toList();

        return Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Work Dashboard', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            backgroundColor: Colors.transparent,
            elevation: 0,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(value: false, label: Text('Open')),
                    ButtonSegment<bool>(value: true, label: Text('Completed')),
                  ],
                  selected: {_showCompletedOnly},
                  onSelectionChanged: (selection) {
                    setState(() => _showCompletedOnly = selection.first);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SegmentedButton<RequestListScope>(
                  segments: const [
                    ButtonSegment<RequestListScope>(
                      value: RequestListScope.all,
                      label: Text('All'),
                    ),
                    ButtonSegment<RequestListScope>(
                      value: RequestListScope.myRequests,
                      label: Text('My Requests'),
                    ),
                    ButtonSegment<RequestListScope>(
                      value: RequestListScope.acceptedByMe,
                      label: Text('Accepted by Me'),
                    ),
                  ],
                  selected: {_selectedScope},
                  onSelectionChanged: (selection) {
                    setState(() => _selectedScope = selection.first);
                  },
                ),
              ),
              if (!isHelperEnabled && !_showCompletedOnly)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppTheme.primaryPurple),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Helper mode is off. You can view and manage your own requests, but cannot accept others.',
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pushNamed('/profile'),
                        child: const Text('Enable'),
                      ),
                    ],
                  ),
                ),
              // Filter chips
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => setState(() => _isFilterExpanded = !_isFilterExpanded),
                        borderRadius: BorderRadius.circular(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.tune, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Filter Requests',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            Icon(
                              _isFilterExpanded ? Icons.expand_less : Icons.expand_more,
                              color: Colors.white70,
                            ),
                          ],
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isFilterExpanded) ...[
                              const SizedBox(height: 16),
                              const Text(
                                'Category',
                                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  FilterChip(
                                    label: const Text('All', style: TextStyle(color: Colors.white)),
                                    selected: _selectedCategory == null,
                                    selectedColor: AppTheme.accentPurple.withValues(alpha: 0.4),
                                    checkmarkColor: Colors.white,
                                    backgroundColor: AppTheme.cardDark,
                                    onSelected: (selected) => setState(() => _selectedCategory = selected ? null : _selectedCategory),
                                  ),
                                  ...RequestCategory.values.map((category) {
                                    return FilterChip(
                                      label: Text(category.displayName, style: const TextStyle(color: Colors.white)),
                                      selected: _selectedCategory == category,
                                      selectedColor: AppTheme.accentPurple.withValues(alpha: 0.4),
                                      checkmarkColor: Colors.white,
                                      backgroundColor: AppTheme.cardDark,
                                      onSelected: (selected) => setState(() => _selectedCategory = selected ? category : null),
                                    );
                                  }),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Urgency Level',
                                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  FilterChip(
                                    label: const Text('All', style: TextStyle(color: Colors.white)),
                                    selected: _selectedUrgency == null,
                                    selectedColor: AppTheme.accentPurple.withValues(alpha: 0.4),
                                    checkmarkColor: Colors.white,
                                    backgroundColor: AppTheme.cardDark,
                                    onSelected: (selected) => setState(() => _selectedUrgency = selected ? null : _selectedUrgency),
                                  ),
                                  ...RequestUrgency.values.map((urgency) {
                                    return FilterChip(
                                      label: Text(urgency.displayName, style: const TextStyle(color: Colors.white)),
                                      selected: _selectedUrgency == urgency,
                                      selectedColor: AppTheme.accentPurple.withValues(alpha: 0.4),
                                      checkmarkColor: Colors.white,
                                      backgroundColor: AppTheme.cardDark,
                                      onSelected: (selected) => setState(() => _selectedUrgency = selected ? urgency : null),
                                    );
                                  }),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: requests.isEmpty
                      ? Center(
                          key: const ValueKey('empty'),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              const Text(
                                'No requests found for this filter',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          key: ValueKey('list_${_selectedCategory?.name}_${_selectedUrgency?.name}_${_showCompletedOnly}_${_selectedScope.name}'),
                          onRefresh: () async {
                            await _firestore.collection('help_requests').limit(1).get();
                          },
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: requests.length,
                            itemBuilder: (context, index) {
                              final request = requests[index];
                              final isOwnRequest = request.seekerId == user.uid;

                              return _buildRequestCard(
                                request: request,
                                isOwnRequest: isOwnRequest,
                                isHelperEnabled: isHelperEnabled,
                                currentUserId: user.uid,
                              );
                            },
                          ),
                        ),
                ),
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

  void _showRequestDetails(HelpRequestModel request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Title
              Text(
                request.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              
              // Description
              Text(
                'Description',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                request.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              
              // Category and Urgency
              Row(
                children: [
                  Expanded(
                    child: _buildInfoTile(
                      'Category',
                      request.category.displayName,
                      Icons.category,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildInfoTile(
                      'Urgency',
                      request.urgency.displayName,
                      Icons.priority_high,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Location
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Location',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (request.latitude != null && request.longitude != null && request.category == RequestCategory.emergency)
                    TextButton.icon(
                      onPressed: () async {
                        final lat = request.latitude;
                        final lng = request.longitude;
                        final googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
                        final appleMapsUrl = 'https://maps.apple.com/?q=$lat,$lng';
                        final uri = Uri.parse(googleMapsUrl);
                        final appleUri = Uri.parse(appleMapsUrl);
                        
                        try {
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
                          } else if (await canLaunchUrl(appleUri)) {
                            await launchUrl(appleUri, mode: LaunchMode.externalNonBrowserApplication);
                          } else {
                            await launchUrl(uri, mode: LaunchMode.platformDefault);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Could not open maps')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.map_outlined, size: 16),
                      label: const Text('Open Map', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (request.category == RequestCategory.emergency)
                Text(
                  request.locationName ?? 'Location not specified',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                )
              else
                const Text(
                  'Address hidden for privacy',
                  style: TextStyle(color: Colors.white38, fontSize: 13, fontStyle: FontStyle.italic),
                ),
              if (request.latitude != null && request.longitude != null && request.category == RequestCategory.emergency) ...[
                const SizedBox(height: 4),
                Text(
                  '${request.latitude!.toStringAsFixed(6)}, ${request.longitude!.toStringAsFixed(6)}',
                  style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace'),
                ),
              ],
              const SizedBox(height: 16),
              
              // Offered Amount
              if (request.offeredAmount != null) ...[
                Text(
                  'Offered Amount',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${request.offeredAmount!.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryPurple,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Required Skills
              if (request.requiredSkills.isNotEmpty) ...[
                Text(
                  'Required Skills',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: request.requiredSkills.map((skill) {
                    return Chip(
                      label: Text(skill),
                      backgroundColor: AppTheme.veryLightPurple,
                      labelStyle: const TextStyle(color: AppTheme.darkPurple),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
              if (request.seekerId == FirebaseAuth.instance.currentUser?.uid &&
                  request.status == RequestStatus.accepted)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _completeAndRateRequest(request);
                    },
                    icon: const Icon(Icons.verified),
                    label: const Text('Mark Completed & Rate Helper'),
                  ),
                ),
              const SizedBox(height: 8),
              if (_canCancelRequest(request, FirebaseAuth.instance.currentUser?.uid))
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _cancelRequest(request);
                    },
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancel Task'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                ),
              if (request.helperId == FirebaseAuth.instance.currentUser?.uid &&
                  request.status == RequestStatus.accepted)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _cancelHelp(request);
                    },
                    icon: const Icon(Icons.person_off_outlined),
                    label: const Text('Cancel My Help'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orangeAccent,
                      side: const BorderSide(color: Colors.orangeAccent),
                    ),
                  ),
                ),
              if (_canReviewHelper(request, FirebaseAuth.instance.currentUser?.uid))
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => RatingScreen(helpRequest: request)),
                      );
                    },
                    icon: const Icon(Icons.reviews),
                    label: const Text('Review Helper'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceSoftColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryPurple),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptRequest(HelpRequestModel request) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final helperDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!helperDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please complete your profile first')),
          );
        }
        return;
      }

      final helperData = helperDoc.data() as Map<String, dynamic>;
      
      if (request.seekerId == user.uid) {
        throw Exception('You cannot accept your own request.');
      }

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final requestRef = _firestore.collection('help_requests').doc(request.id);
      final chatRoomRef = _firestore.collection('chat_rooms').doc(request.id);
      final firstMessageRef = _firestore.collection('chat_messages').doc();

      // Calculate points
      int basePoints = 5; // Low
      if (request.urgency == RequestUrgency.high) basePoints = 20;
      else if (request.urgency == RequestUrgency.medium) basePoints = 10;

      final creationTime = request.createdAt;
      final acceptTime = DateTime.fromMillisecondsSinceEpoch(nowMs);
      final diffMinutes = acceptTime.difference(creationTime).inMinutes;

      int speedBonus = 0;
      String speedReason = "";
      if (diffMinutes <= 10) {
        speedBonus = 4; // Decreased 25% from 5
        speedReason = " (Rapid Response Bonus!)";
      } else if (diffMinutes <= 30) {
        speedBonus = 2; // Decreased >25% from 3 (using 2 for clean integer)
        speedReason = " (Fast Response Bonus)";
      } else if (diffMinutes <= 60) {
        speedBonus = 1; // Decreased 50% from 2 (minimum integer bonus)
        speedReason = " (Early Bird Bonus)";
      }

      await _firestore.runTransaction((tx) async {
        final reqSnap = await tx.get(requestRef);

        if (!reqSnap.exists) {
          throw Exception('Request not found.');
        }
        final data = reqSnap.data() as Map<String, dynamic>;
        final currentStatus = data['status'];
        if (currentStatus != RequestStatus.pending.name) {
          throw Exception('This request is no longer available.');
        }

        // Calculate base points based on urgency
        int baseTaskPoints = 5; // Default Low
        if (request.urgency == RequestUrgency.high) baseTaskPoints = 20;
        else if (request.urgency == RequestUrgency.medium) baseTaskPoints = 10;

        // Update Request - Store points to be awarded ON COMPLETION
        tx.update(requestRef, {
          'status': RequestStatus.accepted.name,
          'helperId': user.uid,
          'helperName': helperData['name'] ?? user.email!.split('@')[0],
          'helperEmail': user.email,
          'acceptedAt': nowMs,
          'updatedAt': nowMs,
          'pendingSpeedBonus': speedBonus,
          'speedBonusReason': speedReason,
          'basePointsAwarded': baseTaskPoints, // Track points to be given on completion
        });

        tx.set(chatRoomRef, {
          'participants': [request.seekerId, user.uid],
          'participantIds': [request.seekerId, user.uid],
          'seekerId': request.seekerId,
          'helperId': user.uid,
          'participantNames': [
            request.seekerName,
            helperData['name'] ?? user.email!.split('@')[0]
          ],
          'helpRequestId': request.id,
          'helpRequestTitle': request.title,
          'createdAt': nowMs,
          'lastMessageTime': nowMs,
          'lastMessage': 'Request accepted. You can now chat.',
          'lastMessageSenderId': user.uid,
          'unreadCount': 0,
          'updatedAt': nowMs,
        }, SetOptions(merge: true));

        // 1. First System Message
        final firstMessageRef = _firestore.collection('chat_messages').doc();
        tx.set(firstMessageRef, {
          'senderId': user.uid,
          'senderName': helperData['name'] ?? user.email!.split('@')[0],
          'receiverId': request.seekerId,
          'receiverName': request.seekerName,
          'content': 'Request accepted. You can now chat.',
          'type': 'system',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'isRead': false,
          'chatRoomId': request.id,
          'helpRequestId': request.id,
          'createdAt': nowMs,
        });

        // 2. Emergency Location Message (if applicable)
        if (request.category == RequestCategory.emergency && 
            request.latitude != null && request.longitude != null) {
          final locationMessageRef = _firestore.collection('chat_messages').doc();
          final googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=${request.latitude},${request.longitude}';
          
          tx.set(locationMessageRef, {
            'senderId': request.seekerId,
            'senderName': request.seekerName,
            'receiverId': user.uid,
            'receiverName': helperData['name'] ?? user.email!.split('@')[0],
            'content': '📍 EMERGENCY LOCATION:\n${request.locationName ?? 'Coordinates: ${request.latitude},${request.longitude}'}\n\n$googleMapsUrl',
            'type': 'location',
            'timestamp': DateTime.now().millisecondsSinceEpoch + 100, // Ensure it appears after
            'isRead': false,
            'chatRoomId': request.id,
            'helpRequestId': request.id,
            'createdAt': nowMs,
          });
          
          // Update chat room last message
          tx.update(chatRoomRef, {
            'lastMessage': '📍 Emergency Location Shared',
            'lastMessageTime': DateTime.now().millisecondsSinceEpoch + 100,
          });
        }
      });

      await NotificationService.createNotification(
        userId: request.seekerId,
        title: 'Request Accepted',
        body:
            '${helperData['name'] ?? user.email!.split('@')[0]} accepted "${request.title}".',
        type: NotificationType.requestAccepted,
        data: {'requestId': request.id, 'helperId': user.uid},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request accepted! Chat now with the seeker. \u{1F3C6}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accepting request: $e')),
        );
      }
    }
  }

  Future<void> _completeAndRateRequest(HelpRequestModel request) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    if (request.seekerId != currentUser.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only the seeker can mark this task completed.')),
      );
      return;
    }

    final requestRef = _firestore.collection('help_requests').doc(request.id);
    final chatRoomRef = _firestore.collection('chat_rooms').doc(request.id);
    final systemMessageRef = _firestore.collection('chat_messages').doc();
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    try {
      await _firestore.runTransaction((tx) async {
        final reqSnap = await tx.get(requestRef);
        if (!reqSnap.exists) {
          throw Exception('Request not found.');
        }
        final data = reqSnap.data() as Map<String, dynamic>;
        
        // Fetch all needed snapshots FIRST (READS)
        DocumentSnapshot? helperSnap;
        if (data['helperId'] != null) {
          final helperRef = _firestore.collection('users').doc(data['helperId']);
          helperSnap = await tx.get(helperRef);
        }

        // VALIDATION
        final currentStatus = data['status'];
        if (currentStatus == RequestStatus.completed.name) {
          throw Exception('Task is already completed.');
        }
        if (currentStatus != RequestStatus.accepted.name) {
          throw Exception('Only accepted tasks can be completed.');
        }

        // WRITES
        tx.update(requestRef, {
          'status': RequestStatus.completed.name,
          'completedAt': nowMs,
          'completedBy': currentUser.uid,
          'updatedAt': nowMs,
        });

        final int speedBonus = data['pendingSpeedBonus'] ?? 0;
        final String speedReason = data['speedBonusReason'] ?? "";
        final int basePoints = data['basePointsAwarded'] ?? 0;
        final int completionBonus = 5;
        final int totalAwarded = basePoints + speedBonus + completionBonus;

        if (helperSnap != null && helperSnap.exists) {
          final helperRef = _firestore.collection('users').doc(data['helperId']);
          
          if (totalAwarded > 0) {
            tx.update(helperRef, {
              'completedTasks': FieldValue.increment(1),
              'helperPoints': FieldValue.increment(totalAwarded),
              'updatedAt': nowMs,
            });

            // Record Transaction
            final transRef = _firestore.collection('pointTransactions').doc();
            String reason = "Task Completed Reward: ${data['title'] ?? 'Task'} (+5 PTS completion bonus";
            if (basePoints > 0) reason += ", $basePoints PTS urgency reward";
            if (speedBonus > 0) {
              reason += ", $speedBonus PTS speed bonus$speedReason";
            }
            reason += ")";
            
            tx.set(transRef, {
              'uid': data['helperId'],
              'points': totalAwarded,
              'reason': reason,
              'timestamp': FieldValue.serverTimestamp(),
            });
          }

          // Notify helper of points earned
          if (totalAwarded > 0) {
            NotificationService.createNotification(
              userId: data['helperId'],
              title: 'Points Earned!',
              body: 'You earned $totalAwarded PTS for completing "${data['title'] ?? 'Task'}"',
              type: NotificationType.system,
              data: {'requestId': request.id, 'points': totalAwarded},
            );
          }
        }

        tx.set(chatRoomRef, {
          'lastMessageTime': nowMs,
          'lastMessage': 'Task marked as completed',
          'lastMessageSenderId': currentUser.uid,
          'updatedAt': nowMs,
          'completedAt': nowMs,
        }, SetOptions(merge: true));

        tx.set(systemMessageRef, {
          'senderId': currentUser.uid,
          'senderName': data['seekerName'] ?? 'Seeker',
          'receiverId': data['helperId'] ?? '',
          'receiverName': data['helperName'] ?? 'Helper',
          'content': 'Task marked as completed. Helper earned $totalAwarded PTS! (+5 bonus included)',
          'type': 'system',
          'timestamp': nowMs,
          'isRead': false,
          'chatRoomId': request.id,
          'helpRequestId': request.id,
          'createdAt': nowMs,
        });
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request marked as completed.')),
      );

      final updatedRequest = request.copyWith(status: RequestStatus.completed);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => RatingScreen(helpRequest: updatedRequest),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildRequestCard({
    required HelpRequestModel request,
    required bool isOwnRequest,
    required bool isHelperEnabled,
    required String currentUserId,
  }) {
    return InkWell(
      onTap: () => _showRequestDetails(request),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.secondaryBlack,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: request.category == RequestCategory.emergency 
                ? AppTheme.emergencyRed.withOpacity(0.5) 
                : Colors.white.withValues(alpha: 0.1),
            width: request.category == RequestCategory.emergency ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: request.category == RequestCategory.emergency 
                  ? AppTheme.emergencyRed.withValues(alpha: 0.1) 
                  : Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    request.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (request.helperId != null && request.helperId!.isNotEmpty && request.status == RequestStatus.pending && request.helperId == currentUserId)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withOpacity(0.5)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'Direct Match',
                          style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                _buildStatusChip(request.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              request.description,
              style: const TextStyle(color: Colors.white70),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.category_outlined, size: 16, color: Colors.white54),
                const SizedBox(width: 6),
                Text(
                  request.category.displayName,
                  style: const TextStyle(color: Colors.white54),
                ),
                const Spacer(),
                Icon(Icons.schedule, size: 16, color: Colors.white54),
                const SizedBox(width: 6),
                Text(
                  request.timeAgo,
                  style: const TextStyle(color: Colors.white54),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!isOwnRequest && isHelperEnabled && request.status == RequestStatus.pending)
                  ElevatedButton(
                    onPressed: () => _acceptRequest(request),
                    child: const Text('Accept'),
                  ),
                if (_canCancelRequest(request, currentUserId))
                  OutlinedButton(
                    onPressed: () => _cancelRequest(request),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                    child: const Text('Cancel'),
                  ),
                if (isOwnRequest && request.status == RequestStatus.accepted)
                  ElevatedButton.icon(
                    onPressed: () => _completeAndRateRequest(request),
                    icon: const Icon(Icons.verified, size: 18),
                    label: const Text('Mark Completed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (request.helperId == currentUserId && request.status == RequestStatus.accepted)
                  OutlinedButton(
                    onPressed: () => _cancelHelp(request),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orangeAccent,
                      side: const BorderSide(color: Colors.orangeAccent),
                    ),
                    child: const Text('Cancel Help'),
                  ),
                if (_canReviewHelper(request, currentUserId))
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => RatingScreen(helpRequest: request)),
                    ),
                    child: const Text('Review Helper'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(RequestStatus status) {
    Color color;
    switch (status) {
      case RequestStatus.pending:
        color = Colors.orange;
        break;
      case RequestStatus.accepted:
      case RequestStatus.inProgress:
        color = AppTheme.primaryPurple;
        break;
      case RequestStatus.completed:
        color = Colors.green;
        break;
      case RequestStatus.cancelled:
        color = Colors.redAccent;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }

  bool _canCancelRequest(HelpRequestModel request, String? userId) {
    if (userId == null) return false;
    if (request.seekerId != userId) return false;
    return request.status == RequestStatus.pending || request.status == RequestStatus.accepted;
  }

  bool _canReviewHelper(HelpRequestModel request, String? userId) {
    if (userId == null) return false;
    return request.seekerId == userId &&
        request.status == RequestStatus.completed &&
        (request.helperId?.isNotEmpty ?? false);
  }

  Future<void> _cancelRequest(HelpRequestModel request) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (request.seekerId != user.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only request creator can cancel this task.')),
      );
      return;
    }

    final requestRef = _firestore.collection('help_requests').doc(request.id);
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    try {
      await _firestore.runTransaction((tx) async {
        final reqSnap = await tx.get(requestRef);
        if (!reqSnap.exists) {
          throw Exception('Request not found.');
        }
        final data = reqSnap.data() as Map<String, dynamic>;
        final currentStatus = data['status'] as String?;
        if (currentStatus == RequestStatus.completed.name ||
            currentStatus == RequestStatus.cancelled.name) {
          throw Exception('This task cannot be cancelled now.');
        }
        if (data['seekerId'] != user.uid) {
          throw Exception('Only request creator can cancel.');
        }

        tx.update(requestRef, {
          'status': RequestStatus.cancelled.name,
          'cancelledAt': nowMs,
          'updatedAt': nowMs,
        });
      });

      if ((request.helperId ?? '').isNotEmpty) {
        await NotificationService.createNotification(
          userId: request.helperId!,
          title: 'Task Cancelled',
          body: 'The request "${request.title}" was cancelled by the seeker.',
          type: NotificationType.system,
          data: {'requestId': request.id},
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task cancelled successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to cancel task: $e')),
      );
    }
  }

  Future<void> _cancelHelp(HelpRequestModel request) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (request.helperId != user.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only the assigned helper can cancel their help.')),
      );
      return;
    }

    final requestRef = _firestore.collection('help_requests').doc(request.id);
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    try {
      await _firestore.runTransaction((tx) async {
        final reqSnap = await tx.get(requestRef);
        if (!reqSnap.exists) {
          throw Exception('Request not found.');
        }
        final data = reqSnap.data() as Map<String, dynamic>;
        
        if (data['status'] != RequestStatus.accepted.name) {
          throw Exception('This task is no longer in accepted status.');
        }
        
        if (data['helperId'] != user.uid) {
          throw Exception('You are not the helper for this task anymore.');
        }

        // Reset to pending
        tx.update(requestRef, {
          'status': RequestStatus.pending.name,
          'helperId': FieldValue.delete(),
          'helperName': FieldValue.delete(),
          'helperEmail': FieldValue.delete(),
          'acceptedAt': FieldValue.delete(),
          'updatedAt': nowMs,
        });
      });

      await NotificationService.createNotification(
        userId: request.seekerId,
        title: 'Helper Withdrawn',
        body: 'The helper for "${request.title}" has withdrawn. Your request is back in the list.',
        type: NotificationType.system,
        data: {'requestId': request.id},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Help cancelled. The task is back in the public list.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cancelling help: $e')),
        );
      }
    }
  }

  Color getUrgencyColor(RequestUrgency urgency) {
    switch (urgency) {
      case RequestUrgency.high:
        return AppTheme.errorColor;
      case RequestUrgency.medium:
        return AppTheme.warningColor;
      case RequestUrgency.low:
        return AppTheme.successColor;
    }
  }
}

enum RequestListScope {
  all,
  myRequests,
  acceptedByMe,
}
