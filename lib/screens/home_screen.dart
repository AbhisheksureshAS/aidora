import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'create_request_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'nearby_helpers_screen.dart';
import 'requests_screen.dart';
import '../models/help_request_model.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;

  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _currentIndex;
  static const Duration _navAnimationDuration = Duration(milliseconds: 260);

  final List<Widget> _screens = [
    const HomeTab(),
    const RequestsTab(),
    const ChatTab(),
    const ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await FirebaseAuth.instance.signOut();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Logout failed: $e')),
                  );
                }
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF1A1A1A), width: 0.5)),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF0A0A0A),
        selectedItemColor: const Color(0xFFFFFFFF),
        unselectedItemColor: const Color(0xFFAAAAAA),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_outlined),
            activeIcon: Icon(Icons.list),
            label: 'Requests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_outlined),
            activeIcon: Icon(Icons.chat),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outlined),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Future<_UserInsights>? _insightsFuture;
  String? _lastUserId;

  @override
  void initState() {
    super.initState();
    _initInsights();
  }

  void _initInsights() {
    final user = _auth.currentUser;
    if (user != null && _lastUserId != user.uid) {
      _lastUserId = user.uid;
      _insightsFuture = _loadInsights(user.uid);
    }
  }

  Future<_UserInsights> _loadInsights(String userId) async {
    final completedAsSeeker = await _firestore
        .collection('help_requests')
        .where('seekerId', isEqualTo: userId)
        .where('status', isEqualTo: RequestStatus.completed.name)
        .get();

    final connectedHelpers = await _firestore
        .collection('help_requests')
        .where('seekerId', isEqualTo: userId)
        .where('status', isEqualTo: RequestStatus.completed.name)
        .get();

    final uniqueHelpers = connectedHelpers.docs
        .map((d) => (d.data()['helperId'] as String?) ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .length;

    final completedAsHelper = await _firestore
        .collection('help_requests')
        .where('helperId', isEqualTo: userId)
        .where('status', isEqualTo: RequestStatus.completed.name)
        .get();

    final totalGiven = await _firestore
        .collection('help_requests')
        .where('seekerId', isEqualTo: userId)
        .get();

    final totalTaken = await _firestore
        .collection('help_requests')
        .where('helperId', isEqualTo: userId)
        .get();

    return _UserInsights(
      totalHelpRequestsGiven: totalGiven.docs.length,
      totalHelpRequestsTaken: totalTaken.docs.length,
      uniqueHelpersConnected: uniqueHelpers,
    );
  }

  void _showEmergencyDialog(BuildContext context) {
    final reasonController = TextEditingController();
    final descController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Emergency Help',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Describe your emergency. We will post a high-priority request.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  hintText: 'Medical / safety / urgent need',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Give clear details so nearby helpers can respond fast.',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final parentMessenger = ScaffoldMessenger.of(this.context);
                    final user = _auth.currentUser;
                    if (user == null) return;

                    try {
                      final emergencyRequest = HelpRequestModel(
                        id: '', // Will be set by Firestore
                        seekerId: user.uid,
                        seekerName: user.displayName ?? user.email?.split('@').first ?? 'Anonymous',
                        seekerEmail: user.email ?? '',
                        title: '🚨 EMERGENCY: ${reasonController.text.trim()}',
                        description: descController.text.trim(),
                        category: RequestCategory.emergency,
                        urgency: RequestUrgency.high,
                        status: RequestStatus.pending,
                        createdAt: DateTime.now(),
                        latitude: null, // Will be set by notification service
                        longitude: null,
                        requiredSkills: [],
                      );

                      final docRef = await _firestore
                          .collection('help_requests')
                          .add(emergencyRequest.toFirebase());

                      // Update the request with the generated ID
                      await docRef.update({'id': docRef.id});

                      // Create emergency notification
                      await _firestore.collection('emergency_notifications').add({
                        'requestId': docRef.id,
                        'requestTitle': emergencyRequest.title,
                        'seekerId': user.uid,
                        'createdAt': DateTime.now().millisecondsSinceEpoch,
                        'isActive': true,
                      });

                      if (mounted) {
                        Navigator.of(context).pop();
                        parentMessenger.showSnackBar(
                          const SnackBar(
                            content: Text('Emergency request posted! Nearby helpers will be notified.'),
                            backgroundColor: AppTheme.emergencyRed,
                          ),
                        );
                      }
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(content: Text('Failed to post emergency request: $e')),
                      );
                    }
                  },
                  icon: const Icon(Icons.warning_amber_rounded),
                  label: const Text('Submit Emergency Request'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.emergencyRed,
                    foregroundColor: AppTheme.accentWhite,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Center(child: Text('Please sign in.'));
    }

    return SafeArea(
      child: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('users').doc(currentUser.uid).snapshots(),
        builder: (context, snapshot) {
          final userData = snapshot.data?.data() as Map<String, dynamic>?;
          final userName = (userData?['name'] as String?) ??
              currentUser.displayName ??
              currentUser.email?.split('@').first ??
              'there';
          final rating = ((userData?['rating'] as num?) ?? 0).toDouble();
          final totalRatings = (userData?['totalRatings'] as num?)?.toInt() ?? 0;

          _initInsights();

          return FutureBuilder<_UserInsights>(
            future: _insightsFuture,
            builder: (context, insightsSnap) {
              final insights = insightsSnap.data ?? const _UserInsights();

              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black,
                      AppTheme.darkPurple.withValues(alpha: 0.6),
                      AppTheme.primaryBlack,
                    ],
                    stops: const [0.0, 0.3, 0.5],
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    // Clean Premium Branded Header
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome to',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondary.withValues(alpha: 0.7),
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 4),
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.textPrimary,
                                  letterSpacing: -0.5,
                                  fontFamily: 'Outfit',
                                ),
                                children: [
                                  const TextSpan(text: 'A'),
                                  TextSpan(
                                    text: 'i',
                                    style: TextStyle(color: AppTheme.primaryPurple),
                                  ),
                                  const TextSpan(text: 'dora'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.waving_hand_rounded, size: 14, color: AppTheme.accentPurple),
                              const SizedBox(width: 8),
                              Text(
                                userName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),

                    // Categories Grid
                    Text(
                      'Categories',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCategoriesGrid(context),

                    const SizedBox(height: 32),

                    Text(
                      'Quick Actions',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Main Action Cards
                    ModernActionCard(
                      title: 'Find Helpers',
                      subtitle: 'Discover nearby helpers',
                      icon: Icons.search_rounded,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const NearbyHelpersScreen()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ModernActionCard(
                      title: 'Create Request',
                      subtitle: 'Post a generic help request',
                      icon: Icons.add_circle_rounded,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CreateRequestScreen()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ModernActionCard(
                      title: 'Emergency',
                      subtitle: 'Get immediate help',
                      icon: Icons.emergency_share_rounded,
                      isEmergency: true,
                      onTap: () => _showEmergencyDialog(context),
                    ),

                    const SizedBox(height: 40),

                    // User Stats Section
                    if (insights.totalHelpRequestsGiven > 0 || 
                        insights.totalHelpRequestsTaken > 0) ...[
                      Text(
                        'Your Activity',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Tasks Posted',
                              insights.totalHelpRequestsGiven.toString(),
                              Icons.post_add,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              'Tasks Completed',
                              insights.totalHelpRequestsTaken.toString(),
                              Icons.task_alt,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Helpers Connected',
                              insights.uniqueHelpersConnected.toString(),
                              Icons.people,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildRatingCard(rating, totalRatings),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),);
            },
          );
        },
      ),
    );
  }

  Widget _buildCategoriesGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _buildCategoryCard(
          context,
          RequestCategory.academic,
          Icons.school_rounded,
        ),
        _buildCategoryCard(
          context,
          RequestCategory.skillLearning,
          Icons.computer_rounded,
        ),
        _buildCategoryCard(
          context,
          RequestCategory.dailyTask,
          Icons.shopping_bag_rounded,
        ),
        _buildCategoryCard(
          context,
          RequestCategory.emergency,
          Icons.health_and_safety_rounded,
          isDanger: true,
        ),
      ],
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    RequestCategory category,
    IconData icon, {
    bool isDanger = false,
  }) {
    return InkWell(
      onTap: () {
        if (category == RequestCategory.emergency) {
          _showEmergencyDialog(context);
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CreateRequestScreen(initialCategory: category),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: isDanger ? AppTheme.emergencyCardDecoration.copyWith(
          borderRadius: BorderRadius.circular(16)
        ) : AppTheme.categoryCardDecoration,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDanger 
                    ? Colors.white.withValues(alpha: 0.2)
                    : AppTheme.primaryPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isDanger ? Colors.white : AppTheme.accentPurple,
                size: 24,
              ),
            ),
            const Spacer(),
            Text(
              category.displayName,
              style: TextStyle(
                color: isDanger ? Colors.white : AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // Replaced with ModernActionCard standalone widget

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.darkCardDecoration,
      child: Column(
        children: [
          Icon(
            icon,
            color: AppTheme.textSecondary,
            size: 24,
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRatingCard(double rating, int totalRatings) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.darkCardDecoration,
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.star,
                color: Colors.amber,
                size: 20,
              ),
              const SizedBox(width: 4),
              Text(
                rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$totalRatings reviews',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}


class ModernActionCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isEmergency;

  const ModernActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.isEmergency = false,
  });

  @override
  State<ModernActionCard> createState() => _ModernActionCardState();
}

class _ModernActionCardState extends State<ModernActionCard> with SingleTickerProviderStateMixin {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: widget.isEmergency
              ? AppTheme.emergencyCardDecoration
              : AppTheme.mainActionCardDecoration,
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.isEmergency
                      ? Colors.white.withValues(alpha: 0.2)
                      : AppTheme.primaryPurple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  widget.icon,
                  size: 28,
                  color: widget.isEmergency ? Colors.white : AppTheme.accentPurple,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: widget.isEmergency ? FontWeight.w700 : FontWeight.w600,
                        color: widget.isEmergency ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: widget.isEmergency 
                            ? Colors.white.withValues(alpha: 0.8)
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: widget.isEmergency ? Colors.white : AppTheme.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserInsights {
  final int totalHelpRequestsGiven;
  final int totalHelpRequestsTaken;
  final int uniqueHelpersConnected;

  const _UserInsights({
    this.totalHelpRequestsGiven = 0,
    this.totalHelpRequestsTaken = 0,
    this.uniqueHelpersConnected = 0,
  });
}

// Fixed import bug: natively imported from requests_screen.dart

class ChatTab extends StatelessWidget {
  const ChatTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const ChatScreen();
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProfileScreen();
  }
}
