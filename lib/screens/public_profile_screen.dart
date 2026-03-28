import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../theme/app_theme.dart';
import '../models/rating_model.dart';

class PublicProfileScreen extends StatelessWidget {
  final String userId;

  const PublicProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBlack,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: CircleAvatar(
          backgroundColor: Colors.black.withValues(alpha: 0.3),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white70)));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('User profile not found', style: TextStyle(color: Colors.white70)));
          }

          final user = UserModel.fromFirebase(snapshot.data!.data() as Map<String, dynamic>, snapshot.data!.id);

          return SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(context, user),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStats(user),
                      const SizedBox(height: 24),
                      if (user.bio.isNotEmpty) ...[
                        const Text(
                          'About',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          user.bio,
                          style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (user.skills.isNotEmpty) ...[
                        const Text(
                          'Skills',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: user.skills.map((skill) => _buildSkillChip(skill)).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],
                      _buildRatingSection(user),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, UserModel user) {
    return Container(
      height: 380,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.primaryPurple.withValues(alpha: 0.3),
            AppTheme.primaryBlack,
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          Hero(
            tag: 'avatar_${user.uid}',
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.5), width: 3),
              ),
              child: CircleAvatar(
                radius: 70,
                backgroundColor: AppTheme.secondaryBlack,
                backgroundImage: _getImageProvider(user.profileImageUrl),
                child: (user.profileImageUrl == null || user.profileImageUrl!.isEmpty)
                    ? const Icon(Icons.person, color: Colors.white24, size: 70)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            user.name,
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          if (user.isHelperEnabled) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified, color: Colors.green, size: 14),
                  const SizedBox(width: 4),
                  const Text('Verified Helper', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStats(UserModel user) {
    return Row(
      children: [
        Expanded(child: _buildStatItem('Rating', user.rating.toStringAsFixed(1), Icons.star, Colors.amber)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatItem('Points', user.helperPoints.toString(), Icons.flash_on, Colors.orange)),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.secondaryBlack,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSkillChip(String skill) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryPurple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.2)),
      ),
      child: Text(skill, style: const TextStyle(color: AppTheme.primaryPurple, fontSize: 13, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildRatingSection(UserModel user) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ratings')
          .where('toUserId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();

        // Sort in-memory to bypass composite index requirement
        final docs = snapshot.data!.docs.toList();
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['createdAt'] ?? 0;
          final bTime = bData['createdAt'] ?? 0;
          return bTime.compareTo(aTime);
        });

        final displayedDocs = docs.take(3);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Reviews',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...displayedDocs.map((doc) {
              final rating = RatingModel.fromFirebase(doc.data() as Map<String, dynamic>, doc.id);
              final dateStr = "${rating.createdAt.day}/${rating.createdAt.month}/${rating.createdAt.year}";
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryBlack,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ...List.generate(5, (i) => Icon(Icons.star, size: 14, color: i < rating.rating ? Colors.amber : Colors.white24)),
                        const Spacer(),
                        Text(dateStr, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(rating.feedback ?? 'No comment provided', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  ImageProvider? _getImageProvider(String? url) {
    if (url == null || url.isEmpty) {
      return null;
    }
    if (url.startsWith('assets/')) {
      return AssetImage(url);
    }
    return NetworkImage(url);
  }
}
