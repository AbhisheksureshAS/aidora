import 'dart:async';
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
import '../services/location_service.dart';
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
    if (_currentIndex == 1) {
      _updateLastViewedRequests();
    }
  }

  Future<void> _updateLastViewedRequests() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
            'lastViewedRequests': DateTime.now().millisecondsSinceEpoch,
          }, SetOptions(merge: true));
    }
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, userSnap) {
        final lastViewed = (userSnap.data?.data() as Map<String, dynamic>?)?['lastViewedRequests'] ?? 0;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('help_requests')
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, requestSnap) {
            // Filter locally for requests
            final newRequests = requestSnap.hasData 
                ? requestSnap.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final createdAt = data['createdAt'] as int? ?? 0;
                    final seekerId = data['seekerId'] as String? ?? '';
                    return seekerId != user.uid && createdAt > lastViewed;
                  }).toList()
                : [];
            
            final hasNewRequests = newRequests.isNotEmpty;

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chat_messages')
                  .where('receiverId', isEqualTo: user.uid)
                  .where('isRead', isEqualTo: false)
                  .snapshots(),
              builder: (context, chatSnap) {
                final hasUnreadChat = chatSnap.hasData && chatSnap.data!.docs.isNotEmpty;

                return Container(
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFF1A1A1A), width: 0.5)),
                  ),
                  child: BottomNavigationBar(
                    currentIndex: _currentIndex,
                    onTap: (index) {
                      if (index == 1) {
                        _updateLastViewedRequests();
                      }
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    type: BottomNavigationBarType.fixed,
                    backgroundColor: const Color(0xFF0A0A0A),
                    selectedItemColor: const Color(0xFFFFFFFF),
                    unselectedItemColor: const Color(0xFFAAAAAA),
                    items: [
                      const BottomNavigationBarItem(
                        icon: Icon(Icons.home_outlined),
                        activeIcon: Icon(Icons.home),
                        label: 'Home',
                      ),
                      BottomNavigationBarItem(
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.list_outlined),
                            if (hasNewRequests)
                              Positioned(
                                right: -3,
                                top: -1,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 8,
                                    minHeight: 8,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        activeIcon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.list),
                            if (hasNewRequests)
                              Positioned(
                                right: -3,
                                top: -1,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 8,
                                    minHeight: 8,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        label: 'Requests',
                      ),
                      BottomNavigationBarItem(
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.chat_outlined),
                            if (hasUnreadChat)
                              Positioned(
                                right: -3,
                                top: -1,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 8,
                                    minHeight: 8,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        activeIcon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.chat),
                            if (hasUnreadChat)
                              Positioned(
                                right: -3,
                                top: -1,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 8,
                                    minHeight: 8,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        label: 'Chat',
                      ),
                      const BottomNavigationBarItem(
                        icon: Icon(Icons.person_outlined),
                        activeIcon: Icon(Icons.person),
                        label: 'Profile',
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
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
  final GlobalKey _nameKey = GlobalKey();
  final List<Widget> _activeAnimations = [];
  int _animationCounter = 0;

  void _triggerFallingAvatar(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return;

    final RenderBox? renderBox = _nameKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final startX = offset.dx + size.width / 2;
    final startY = offset.dy + size.height / 2;

    final animationId = _animationCounter++;
    
    setState(() {
      _activeAnimations.add(
        _FallingAvatarAnimation(
          key: ValueKey('falling_avatar_$animationId'),
          imageUrl: imageUrl,
          startX: startX,
          startY: startY,
          onComplete: () {
            setState(() {
              _activeAnimations.removeWhere((w) => w.key == ValueKey('falling_avatar_$animationId'));
            });
          },
        ),
      );
    });
  }

  @override
  void initState() {
    super.initState();
  }

  Stream<_UserInsights> _getInsightsStream(String userId) {
    final s1 = _firestore.collection('help_requests').where('seekerId', isEqualTo: userId).snapshots();
    final s2 = _firestore.collection('help_requests').where('helperId', isEqualTo: userId).snapshots();

    final controller = StreamController<_UserInsights>();
    QuerySnapshot? snap1;
    QuerySnapshot? snap2;

    void update() {
      if (snap1 != null && snap2 != null) {
        final seekerDocs = snap1!.docs;
        final helperDocs = snap2!.docs;

        final completedAsHelper = helperDocs.where((d) => 
          (d.data() as Map<String, dynamic>)['status'] == RequestStatus.completed.name).length;
        
        final uniqueHelpers = seekerDocs
            .map((d) => (d.data() as Map<String, dynamic>)['helperId'] as String?)
            .where((id) => id != null && id.isNotEmpty)
            .toSet()
            .length;

        if (!controller.isClosed) {
          controller.add(_UserInsights(
            totalHelpRequestsGiven: seekerDocs.length,
            totalHelpRequestsTaken: completedAsHelper,
            uniqueHelpersConnected: uniqueHelpers,
          ));
        }
      }
    }

    final sub1 = s1.listen((s) { snap1 = s; update(); });
    final sub2 = s2.listen((s) { snap2 = s; update(); });

    controller.onCancel = () {
      sub1.cancel();
      sub2.cancel();
      controller.close();
    };

    return controller.stream;
  }

  void _showEmergencyDialog(BuildContext context) {
    final reasonController = TextEditingController();
    final descController = TextEditingController();
    bool isSubmitting = false;

    Future<void> submitEmergency(String reason, String description, setModalState) async {
      setModalState(() => isSubmitting = true);
      final parentMessenger = ScaffoldMessenger.of(this.context);
      final user = _auth.currentUser;
      if (user == null) {
        setModalState(() => isSubmitting = false);
        return;
      }

      try {
        final locationResult = await LocationService.getCurrentLocation();
        
        final emergencyRequest = HelpRequestModel(
          id: '',
          seekerId: user.uid,
          seekerName: user.displayName ?? user.email?.split('@').first ?? 'Anonymous',
          seekerEmail: user.email ?? '',
          title: '🚨 EMERGENCY: ${reason.isEmpty ? 'QUICK SOS' : reason}',
          description: description.isEmpty ? 'Quick emergency request sent. Immediate help needed.' : description,
          category: RequestCategory.emergency,
          urgency: RequestUrgency.high,
          status: RequestStatus.pending,
          createdAt: DateTime.now(),
          latitude: locationResult.lat,
          longitude: locationResult.lng,
          locationName: locationResult.address,
          requiredSkills: [],
        );

        final docRef = await _firestore
            .collection('help_requests')
            .add(emergencyRequest.toFirebase());

        final updatedRequest = emergencyRequest.copyWith(id: docRef.id);
        await docRef.update({'id': docRef.id});

        await NotificationService.notifyNewRequest(updatedRequest);
        await NotificationService.notifyUrgentRequest(updatedRequest);

        await _firestore.collection('emergency_notifications').add({
          'requestId': docRef.id,
          'requestTitle': updatedRequest.title,
          'seekerId': user.uid,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'isActive': true,
          'latitude': locationResult.lat,
          'longitude': locationResult.lng,
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
        setModalState(() => isSubmitting = false);
        if (!mounted) return;
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(content: Text('Failed to post emergency: $e')),
        );
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Emergency Help',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white60),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // NEW: Quick Emergency Button
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.emergencyRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.emergencyRed.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'QUICK SOS',
                          style: TextStyle(color: AppTheme.emergencyRed, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Immediate help without typing',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isSubmitting ? null : () => submitEmergency('', '', setModalState),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.emergencyRed,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: isSubmitting 
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('SEND SOS NOW', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  const Text(
                    'Or describe your emergency:',
                    style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(
                      labelText: 'Reason',
                      hintText: 'Medical / safety / urgent...',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Details so helpers can respond quickly...',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: isSubmitting ? null : () {
                        if (reasonController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a reason')),
                          );
                          return;
                        }
                        submitEmergency(reasonController.text.trim(), descController.text.trim(), setModalState);
                      },
                      icon: const Icon(Icons.warning_amber_rounded),
                      label: Text(isSubmitting ? 'Posting...' : 'Post Detailed Emergency'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.emergencyRed,
                        side: const BorderSide(color: AppTheme.emergencyRed),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
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
          final profileImageUrl = (userData?['profileImageUrl'] as String?) ?? '';

          return Stack(
            children: [
              Container(
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
                              GestureDetector(
                                onTap: () => _triggerFallingAvatar(profileImageUrl),
                                child: Container(
                                  key: _nameKey,
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
                          StreamBuilder<_UserInsights>(
                            stream: _getInsightsStream(currentUser.uid),
                            builder: (context, insightsSnap) {
                              final insights = insightsSnap.data ?? const _UserInsights();
                              
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
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
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  ..._activeAnimations,
                ],
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

class _FallingAvatarAnimation extends StatefulWidget {
  final String imageUrl;
  final double startX;
  final double startY;
  final VoidCallback onComplete;

  const _FallingAvatarAnimation({
    super.key,
    required this.imageUrl,
    required this.startX,
    required this.startY,
    required this.onComplete,
  });

  @override
  State<_FallingAvatarAnimation> createState() => _FallingAvatarAnimationState();
}

class _FallingAvatarAnimationState extends State<_FallingAvatarAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _yAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _yAnimation = Tween<double>(
      begin: widget.startY,
      end: 1000.0, // Fall below screen
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInBack,
    ));

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.5, // Slight rotation while falling
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    ));

    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: widget.startX - 20,
          top: _yAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.rotate(
              angle: _rotationAnimation.value,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 20,
                  backgroundImage: widget.imageUrl.startsWith('http')
                      ? NetworkImage(widget.imageUrl) as ImageProvider
                      : AssetImage(widget.imageUrl),
                  backgroundColor: AppTheme.secondaryBlack,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
