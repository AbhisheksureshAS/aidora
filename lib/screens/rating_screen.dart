import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/rating_model.dart';
import '../models/help_request_model.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class RatingScreen extends StatefulWidget {
  final HelpRequestModel helpRequest;

  const RatingScreen({
    super.key,
    required this.helpRequest,
  });

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  double _overallRating = 3.0;
  final TextEditingController _feedbackController = TextEditingController();
  final Map<String, double> _criteriaRatings = {};
  final Map<String, TextEditingController> _criteriaComments = {};
  
  bool _isLoading = false;

  final List<RatingCriterion> _ratingCriteria = [
    RatingCriterion(
      name: 'Communication',
      description: 'How well did they communicate?',
      icon: Icons.chat,
    ),
    RatingCriterion(
      name: 'Quality',
      description: 'How was the quality of help?',
      icon: Icons.star,
    ),
    RatingCriterion(
      name: 'Timeliness',
      description: 'Did they complete the task on time?',
      icon: Icons.schedule,
    ),
    RatingCriterion(
      name: 'Professionalism',
      description: 'How professional were they?',
      icon: Icons.business,
    ),
    RatingCriterion(
      name: 'Helpfulness',
      description: 'How helpful were they?',
      icon: Icons.volunteer_activism,
    ),
  ];

  @override
  void initState() {
    super.initState();
    for (final criterion in _ratingCriteria) {
      _criteriaRatings[criterion.name] = 3.0;
      _criteriaComments[criterion.name] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    for (final controller in _criteriaComments.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submitRating() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // Check if current user is the task creator (seeker)
      if (widget.helpRequest.seekerId != user.uid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Only the person who created this task can give ratings'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if ((widget.helpRequest.helperId ?? '').isEmpty) {
        throw Exception('No helper assigned for this request.');
      }
      if (widget.helpRequest.helperId == user.uid) {
        throw Exception('You cannot rate yourself.');
      }

      // Create rating
      final ratingDocId = '${widget.helpRequest.id}_${user.uid}';
      final rating = RatingModel(
        id: ratingDocId,
        fromUserId: user.uid,
        fromUserName: user.displayName ?? user.email!.split('@')[0],
        toUserId: widget.helpRequest.helperId ?? '',
        toUserName: widget.helpRequest.helperName ?? '',
        helpRequestId: widget.helpRequest.id,
        helpRequestTitle: widget.helpRequest.title,
        rating: _overallRating,
        feedback: _feedbackController.text.trim().isEmpty ? null : _feedbackController.text.trim(),
        criteria: _criteriaRatings.entries.map((entry) {
          return RatingCriteria(
            name: entry.key,
            score: entry.value,
            comment: _criteriaComments[entry.key]?.text.trim().isEmpty == true 
                ? null 
                : _criteriaComments[entry.key]!.text.trim(),
          );
        }).toList(),
        createdAt: DateTime.now(),
        isPublic: true,
      );

      final ratingRef = _firestore.collection('ratings').doc(ratingDocId);
      final requestRef = _firestore.collection('help_requests').doc(widget.helpRequest.id);
      final helperRef = _firestore.collection('users').doc(widget.helpRequest.helperId);

      await _firestore.runTransaction((tx) async {
        final reqSnap = await tx.get(requestRef);
        if (!reqSnap.exists) {
          throw Exception('Request not found.');
        }
        final reqData = reqSnap.data() as Map<String, dynamic>;
        if (reqData['seekerId'] != user.uid) {
          throw Exception('Only seeker can rate helper.');
        }
        if (reqData['status'] != RequestStatus.completed.name) {
          throw Exception('Complete the task before rating.');
        }
        if ((reqData['helperId'] ?? '') == user.uid) {
          throw Exception('You cannot rate yourself.');
        }

        final existing = await tx.get(ratingRef);
        if (existing.exists) {
          throw Exception('You have already rated this request.');
        }

        tx.set(ratingRef, rating.toFirebase());
      });

      // Update user reputation
      if (widget.helpRequest.helperId != null) {
        await _updateUserReputation(widget.helpRequest.helperId!);
      }

      // Mirror aggregate fields on users for profile quick reads.
      final ratingsForHelper = await _firestore
          .collection('ratings')
          .where('toUserId', isEqualTo: widget.helpRequest.helperId)
          .get();
      final total = ratingsForHelper.docs.length;
      final sum = ratingsForHelper.docs
          .map((d) => (d.data()['rating'] as num?)?.toDouble() ?? 0)
          .fold<double>(0, (a, b) => a + b);
      await helperRef.set({
        'rating': total == 0 ? 0 : (sum / total),
        'totalRatings': total,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));

      await NotificationService.notifyRatingReceived(
        helperId: widget.helpRequest.helperId!,
        helperName: widget.helpRequest.helperName ?? 'Helper',
        rating: _overallRating,
        fromUserName: user.displayName ?? user.email!.split('@').first,
      );

      final chatFeedback = (_feedbackController.text.trim().isEmpty)
          ? 'Feedback: You received a ${_overallRating.toStringAsFixed(1)} star review.'
          : 'Feedback: ${_feedbackController.text.trim()}';

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await _firestore.collection('chat_messages').add({
        'senderId': user.uid,
        'senderName': user.displayName ?? user.email!.split('@').first,
        'receiverId': widget.helpRequest.helperId!,
        'receiverName': widget.helpRequest.helperName ?? 'Helper',
        'content': chatFeedback,
        'type': 'system',
        'timestamp': nowMs,
        'isRead': false,
        'chatRoomId': widget.helpRequest.id,
        'helpRequestId': widget.helpRequest.id,
        'createdAt': nowMs,
      });

      await _firestore.collection('chat_rooms').doc(widget.helpRequest.id).set({
        'lastMessageTime': nowMs,
        'lastMessage': 'Review shared privately in chat.',
        'lastMessageSenderId': user.uid,
        'updatedAt': nowMs,
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your rating!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting rating: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateUserReputation(String userId) async {
    try {
      // Get all ratings for this user
      final ratingsSnapshot = await _firestore
          .collection('ratings')
          .where('toUserId', isEqualTo: userId)
          .get();

      final ratings = ratingsSnapshot.docs
          .map((doc) => RatingModel.fromFirebase(doc.data(), doc.id))
          .toList();

      // Calculate new reputation
      double overallRating = 0.0;
      double ethicalScore = 0.0;
      final Map<String, double> skillRatings = {};

      for (final rating in ratings) {
        overallRating += rating.rating;
        ethicalScore += rating.rating; // Simplified ethical score
        
        for (final criteria in rating.criteria) {
          skillRatings[criteria.name] = (skillRatings[criteria.name] ?? 0) + criteria.score;
        }
      }

      if (ratings.isNotEmpty) {
        overallRating /= ratings.length;
        ethicalScore /= ratings.length;
        
        // Average skill ratings
        for (final skill in skillRatings.keys) {
          skillRatings[skill] = skillRatings[skill]! / ratings.length;
        }
      }

      // Get completed tasks count
      final completedTasksSnapshot = await _firestore
          .collection('help_requests')
          .where('helperId', isEqualTo: userId)
          .where('status', isEqualTo: RequestStatus.completed.name)
          .get();

      final reputation = UserReputation(
        userId: userId,
        overallRating: overallRating,
        totalRatings: ratings.length,
        ethicalScore: ethicalScore,
        completedTasks: completedTasksSnapshot.docs.length,
        lastUpdated: DateTime.now(),
      );

      await _firestore.collection('user_reputation').doc(userId).set(reputation.toFirebase());
    } catch (e) {
      debugPrint('Error updating reputation: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    
    // Check if current user is the task creator
    if (user != null && widget.helpRequest.seekerId != user.uid) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Rating Not Available'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.rate_review_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Rating Not Available',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Only the person who created this task can give ratings and mark it as completed.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Helper'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Request Info
            Container(
              decoration: AppTheme.cardDecoration,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Help Request',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.helpRequest.title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Helper: ${widget.helpRequest.helperName ?? "Unknown"}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Overall Rating
            Text(
              'Overall Rating',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Center(
              child: Column(
                children: [
                  Text(
                    _overallRating.toStringAsFixed(1),
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: AppTheme.primaryPurple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (index) {
                      return IconButton(
                        onPressed: () {
                          setState(() {
                            _overallRating = (index + 1).toDouble();
                          });
                        },
                        icon: Icon(
                          index < _overallRating ? Icons.star : Icons.star_border,
                          color: AppTheme.primaryPurple,
                          size: 32,
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Detailed Criteria
            Text(
              'Detailed Rating',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            ..._ratingCriteria.map((criterion) {
              return _buildCriterionRating(criterion);
            }),
            const SizedBox(height: 24),

            // Feedback
            Text(
              'Private Feedback (sent in chat)',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _feedbackController,
              decoration: const InputDecoration(
                hintText: 'Share your experience...',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              maxLength: 500,
            ),
            const SizedBox(height: 16),
            const Text(
              'Your rating is public. Feedback is private and sent to helper chat.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitRating,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Submit Rating'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCriterionRating(RatingCriterion criterion) {
    final rating = _criteriaRatings[criterion.name]!;
    final commentController = _criteriaComments[criterion.name]!;

    return Container(
      decoration: AppTheme.cardDecoration,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                criterion.icon,
                color: AppTheme.primaryPurple,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      criterion.name,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      criterion.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                rating.toStringAsFixed(1),
                style: const TextStyle(
                  color: AppTheme.primaryPurple,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Slider(
            value: rating,
            min: 1.0,
            max: 5.0,
            divisions: 40,
            label: rating.toStringAsFixed(1),
            onChanged: (value) {
              setState(() {
                _criteriaRatings[criterion.name] = value;
              });
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: commentController,
            decoration: InputDecoration(
              hintText: 'Add a comment about ${criterion.name.toLowerCase()}...',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            maxLines: 2,
            maxLength: 200,
          ),
        ],
      ),
    );
  }
}

class RatingCriterion {
  final String name;
  final String description;
  final IconData icon;

  RatingCriterion({
    required this.name,
    required this.description,
    required this.icon,
  });
}
