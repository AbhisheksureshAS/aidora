import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/help_request_model.dart';
import '../theme/app_theme.dart';

class RequestsTab extends StatefulWidget {
  const RequestsTab({super.key});

  @override
  State<RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<RequestsTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  RequestCategory? _selectedCategory;
  RequestUrgency? _selectedUrgency;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Please login'));

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('help_requests')
          .where('status', whereIn: ['pending', 'accepted'])
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final requests = snapshot.data!.docs
            .map((doc) => HelpRequestModel.fromFirebase(doc.data() as Map<String, dynamic>, doc.id))
            .where((request) => _selectedCategory == null || request.category == _selectedCategory)
            .where((request) => _selectedUrgency == null || request.urgency == _selectedUrgency)
            .toList();

        if (requests.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No help requests found'),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Filter chips
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filters',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  // Category filter
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: _selectedCategory == null,
                        onSelected: (selected) => setState(() => _selectedCategory = selected ? null : _selectedCategory),
                      ),
                      ...RequestCategory.values.map((category) {
                        return FilterChip(
                          label: Text(category.displayName),
                          selected: _selectedCategory == category,
                          onSelected: (selected) => setState(() => _selectedCategory = selected ? category : null),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Urgency filter
                  const Text(
                    'Urgency',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: _selectedUrgency == null,
                        onSelected: (selected) => setState(() => _selectedUrgency = selected ? null : _selectedUrgency),
                      ),
                      ...RequestUrgency.values.map((urgency) {
                        return FilterChip(
                          label: Text(urgency.displayName),
                          selected: _selectedUrgency == urgency,
                          onSelected: (selected) => setState(() => _selectedUrgency = selected ? urgency : null),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(),
            // Requests list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final request = requests[index];
                  final isOwnRequest = request.seekerId == user.uid;
                  
                  return RequestCard(
                    request: request,
                    isOwnRequest: isOwnRequest,
                    onTap: () => _showRequestDetails(request),
                    onAccept: !isOwnRequest && request.status == RequestStatus.pending 
                        ? () => _acceptRequest(request)
                        : null,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showRequestDetails(HelpRequestModel request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => RequestDetailsSheet(request: request),
    );
  }

  Future<void> _acceptRequest(HelpRequestModel request) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get helper information
      final helperDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!helperDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please complete your profile first')),
        );
        return;
      }

      final helperData = helperDoc.data() as Map<String, dynamic>;
      
      // Update request status
      await FirebaseFirestore.instance
          .collection('help_requests')
          .doc(request.id)
          .update({
        'status': 'accepted',
        'helperId': user.uid,
        'helperName': helperData['name'] ?? user.email!.split('@')[0],
        'helperEmail': user.email,
        'acceptedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Create notification for seeker
      await FirebaseFirestore.instance
          .collection('notifications')
          .add({
        'userId': request.seekerId,
        'title': 'Request Accepted!',
        'body': '${helperData['name'] ?? user.email!.split('@')[0]} has accepted your help request: "${request.title}"',
        'type': 'requestAccepted',
        'data': {
          'requestId': request.id,
          'helperId': user.uid,
        },
        'isRead': false,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Create chat room
      await FirebaseFirestore.instance
          .collection('chat_rooms')
          .add({
        'participants': [request.seekerId, user.uid],
        'participantNames': [
          request.seekerName,
          helperData['name'] ?? user.email!.split('@')[0]
        ],
        'helpRequestId': request.id,
        'helpRequestTitle': request.title,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'lastMessageTime': DateTime.now().millisecondsSinceEpoch,
        'lastMessage': 'Request accepted - you can now chat!',
        'lastMessageSenderId': user.uid,
        'unreadCount': 0,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request accepted! You can now chat with the seeker.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting request: $e')),
      );
    }
  }
}

class RequestCard extends StatelessWidget {
  final HelpRequestModel request;
  final bool isOwnRequest;
  final VoidCallback onTap;
  final VoidCallback? onAccept;

  const RequestCard({
    super.key,
    required this.request,
    required this.isOwnRequest,
    required this.onTap,
    this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: AppTheme.cardDecoration,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and Urgency
            Row(
              children: [
                Expanded(
                  child: Text(
                    request.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: getUrgencyColor(request.urgency).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: getUrgencyColor(request.urgency).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    request.urgency.displayName,
                    style: TextStyle(
                      color: getUrgencyColor(request.urgency),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              request.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // Meta info
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  request.timeAgo,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                if (request.offeredAmount != null) ...[
                  const Spacer(),
                  Text(
                    '\$${request.offeredAmount!.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AppTheme.primaryPurple,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),

            // Required Skills
            if (request.requiredSkills.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: request.requiredSkills.take(3).map((skill) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      skill,
                      style: const TextStyle(
                        color: AppTheme.primaryPurple,
                        fontSize: 11,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            // Own request indicator
            if (isOwnRequest) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Your Request',
                  style: TextStyle(
                    color: AppTheme.primaryPurple,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],

            // Accept button for non-own requests
            if (!isOwnRequest && request.status == RequestStatus.pending && onAccept != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onAccept,
                  icon: const Icon(Icons.check_circle, size: 16),
                  label: const Text('Accept Task'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],

            // Task completion options for accepted requests
            if (!isOwnRequest && request.status == RequestStatus.accepted && request.helperId == FirebaseAuth.instance.currentUser?.uid) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showCompletionOptions(context, request),
                  icon: const Icon(Icons.task_alt, size: 16),
                  label: const Text('Mark as Completed'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showCompletionOptions(BuildContext context, HelpRequestModel request) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
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
            const SizedBox(height: 8),
            
            // Title
            const Text(
              'Task Completion',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkPurple,
              ),
            ),
            const SizedBox(height: 16),
            
            // Options
            _buildCompletionOption(
              context,
              icon: Icons.check_circle,
              title: 'Mark as Completed',
              subtitle: 'Task has been successfully completed',
              color: AppTheme.successColor,
              onTap: () => _completeTask(context, 'completed', request),
            ),
            
            _buildCompletionOption(
              context,
              icon: Icons.cancel,
              title: 'Cancel Task',
              subtitle: 'Task could not be completed',
              color: AppTheme.errorColor,
              onTap: () => _completeTask(context, 'cancelled', request),
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _completeTask(BuildContext context, String status, HelpRequestModel request) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Show rating dialog if completing task
      if (status == 'completed') {
        _showRatingDialog(context, request);
        return;
      }

      // Update request status in database
      await FirebaseFirestore.instance
          .collection('help_requests')
          .doc(request.id)
          .update({
            'status': status,
            'completedAt': DateTime.now().millisecondsSinceEpoch,
          });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task marked as $status'),
          backgroundColor: status == 'completed' ? AppTheme.successColor : AppTheme.warningColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating task: $e')),
      );
    }
  }

  void _showRatingDialog(BuildContext context, HelpRequestModel request) {
    final TextEditingController commentController = TextEditingController();
    double selectedRating = 0.0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Rate Helper'),
          content: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'How would you rate the helper?',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                
                // Star rating
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return GestureDetector(
                      onTap: () => setState(() => selectedRating = (index + 1).toDouble()),
                      child: Icon(
                        Icons.star,
                        color: selectedRating > index ? Colors.amber : Colors.grey[300],
                        size: 32,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                Text(
                  selectedRating.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                
                // Comment field
                TextField(
                  controller: commentController,
                  decoration: const InputDecoration(
                    hintText: 'Add a comment (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _submitRating(context, selectedRating, commentController.text, request),
              child: const Text('Submit Rating'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRating(BuildContext context, double rating, String comment, HelpRequestModel request) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Update helper's rating in users collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'rating': rating,
            'totalRatings': FieldValue.increment(1),
            'lastActive': DateTime.now().millisecondsSinceEpoch,
          });

      // Add rating to ratings collection
      await FirebaseFirestore.instance
          .collection('ratings')
          .add({
            'helperId': user.uid,
            'seekerId': request.seekerId,
            'requestId': request.id,
            'rating': rating,
            'comment': comment.isNotEmpty ? comment : null,
            'createdAt': DateTime.now().millisecondsSinceEpoch,
          });

      // Create notification for helper
      await FirebaseFirestore.instance
          .collection('notifications')
          .add({
            'userId': user.uid,
            'title': 'New Rating Received!',
            'body': 'You received a ${rating.toStringAsFixed(1)} star rating',
            'type': 'rating_received',
            'data': {
              'rating': rating,
              'fromSeeker': request.seekerId,
            },
            'isRead': false,
            'createdAt': DateTime.now().millisecondsSinceEpoch,
          });

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rating submitted successfully!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting rating: $e')),
      );
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

class RequestDetailsSheet extends StatelessWidget {
  final HelpRequestModel request;

  const RequestDetailsSheet({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
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
              const SizedBox(height: 8),
              
              // Title
              Text(
                request.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
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
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              
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
              Text(
                'Location',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                request.locationName ?? 'Location not specified',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              
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
                  '\$${request.offeredAmount!.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.primaryPurple,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              
              // Required Skills
              if (request.requiredSkills.isNotEmpty) ...[
                const SizedBox(height: 24),
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
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.veryLightPurple,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        skill,
                        style: const TextStyle(
                          color: AppTheme.primaryPurple,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.veryLightPurple,
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
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkPurple,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
