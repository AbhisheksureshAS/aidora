import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import '../models/rating_model.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _imagePicker = ImagePicker();
  
  UserModel? _currentUser;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isHelperEnabled = false;
  
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final List<String> _selectedSkills = [];
  String? _profileImageUrl;

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: Text('Are you sure you want to logout, ${_currentUser?.name ?? _currentUser?.email}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              try {
                await _auth.signOut();
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Logged out successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error logging out'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  final List<String> _availableSkills = [
    'Programming',
    'Web Development',
    'Mobile Development',
    'Data Science',
    'Machine Learning',
    'Mathematics',
    'Physics',
    'Chemistry',
    'Biology',
    'English',
    'Writing',
    'Design',
    'Photography',
    'Video Editing',
    'Music',
    'Languages',
    'Tutoring',
    'Consulting',
    'Repair',
    'Delivery',
    'Cleaning',
    'Pet Care',
    'Gardening',
    'Cooking',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final userData = doc.data()!;
          setState(() {
            _currentUser = UserModel.fromFirebase(userData, user.uid);
            _nameController.text = _currentUser!.name;
            _bioController.text = _currentUser!.bio;
            _selectedSkills.addAll(_currentUser!.skills);
            _profileImageUrl = _currentUser!.profileImageUrl;
            _isHelperEnabled = userData['isHelperEnabled'] ?? false;
            _isLoading = false;
          });
        } else {
          // Create initial profile
          await _createInitialProfile(user);
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    }
  }

  Future<void> _createInitialProfile(User user) async {
    final newUser = UserModel(
      uid: user.uid,
      email: user.email!,
      name: user.email!.split('@')[0],
      createdAt: DateTime.now(),
      lastActive: DateTime.now(),
    );
    
    await _firestore.collection('users').doc(user.uid).set(newUser.toFirebase());
    setState(() {
      _currentUser = newUser;
      _nameController.text = newUser.name;
      _isLoading = false;
    });
  }

  Future<void> _updateProfile() async {
    if (_currentUser == null) return;
    
    try {
      setState(() => _isLoading = true);
      
      final updatedUser = _currentUser!.copyWith(
        name: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        skills: _selectedSkills,
        profileImageUrl: _profileImageUrl,
        lastActive: DateTime.now(),
      );
      
      await _firestore.collection('users').doc(_currentUser!.uid).update(updatedUser.toFirebase());
      
      setState(() {
        _currentUser = updatedUser;
        _isEditing = false;
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
      );
      
      if (image != null) {
        // TODO: Upload to Firebase Storage
        setState(() {
          _profileImageUrl = image.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _updateLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are permanently denied')),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty && _currentUser != null) {
        final placemark = placemarks.first;
        final locationName = '${placemark.locality}, ${placemark.administrativeArea}';
        
        final updatedUser = _currentUser!.copyWith(
          latitude: position.latitude,
          longitude: position.longitude,
          locationName: locationName,
          lastActive: DateTime.now(),
        );
        
        await _firestore.collection('users').doc(_currentUser!.uid).update(updatedUser.toFirebase());
        
        setState(() {
          _currentUser = updatedUser;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location updated successfully!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating location: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please login')));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: Text('Profile not found')),
          );
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        
        // Sync local controllers if not editing
        if (!_isEditing) {
          _currentUser = UserModel.fromFirebase(userData, user.uid);
          _nameController.text = _currentUser!.name;
          _bioController.text = _currentUser!.bio;
          _selectedSkills.clear();
          _selectedSkills.addAll(_currentUser!.skills);
          _profileImageUrl = _currentUser!.profileImageUrl;
          _isHelperEnabled = userData['isHelperEnabled'] ?? false;
        }

        return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Profile' : 'Profile', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: () => setState(() => _isEditing = true),
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.save, color: Colors.white),
              onPressed: _updateProfile,
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.white),
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _nameController.text = _currentUser!.name;
                  _bioController.text = _currentUser!.bio;
                  _selectedSkills.clear();
                  _selectedSkills.addAll(_currentUser!.skills);
                });
              },
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 100, left: 16, right: 16, bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _isEditing ? _pickImage : null,
                      child: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [AppTheme.accentPurple, AppTheme.primaryPurple],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.accentPurple.withValues(alpha: 0.3),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 65,
                              backgroundColor: AppTheme.secondaryBlack,
                              backgroundImage: _profileImageUrl != null
                                  ? (_profileImageUrl!.startsWith('http') 
                                      ? NetworkImage(_profileImageUrl!) 
                                      : null) // Local file path logic if needed
                                  : null,
                              child: _profileImageUrl == null
                                  ? const Icon(
                                      Icons.person,
                                      size: 70,
                                      color: Colors.white24,
                                    )
                                  : null,
                            ),
                          ),
                          if (_isEditing)
                            Positioned(
                              bottom: 5,
                              right: 5,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentPurple,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppTheme.primaryBlack, width: 2),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!_isEditing)
                      Text(
                        _currentUser!.name,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    if (!_isEditing)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _currentUser!.email,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),

              // Email Verification Banner (if not verified)
              if (_auth.currentUser != null && !_auth.currentUser!.emailVerified && !_auth.currentUser!.providerData.any((p) => p.providerId == 'google.com'))
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.red.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Email Not Verified',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Please verify your email to unlock all features.',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          try {
                            await _auth.currentUser?.sendEmailVerification();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Verification link sent! Please check your inbox and spam folder.'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                        style: TextButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.2)),
                        child: const Text('Verify', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),

              // Name Field
              if (_isEditing)
                _buildEditableField(_nameController, 'Name', Icons.person)
              else
                _buildInfoCard('Personal Info', [
                  _buildInfoRowItem('Name', _currentUser!.name, Icons.person),
                  _buildInfoRowItem('Bio', _currentUser!.bio, Icons.description),
                ]),
              
              const SizedBox(height: 24),

              // Helper Status Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isHelperEnabled 
                      ? [const Color(0xFF6A11CB), const Color(0xFF2575FC)] // Vibrant Blue-Purple
                      : [AppTheme.secondaryBlack, const Color(0xFF1E1E2C)], // Slick Dark Slate
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: (_isHelperEnabled ? const Color(0xFF6A11CB) : Colors.black).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  if (_isHelperEnabled)
                                    BoxShadow(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      blurRadius: 8,
                                    ),
                                ],
                              ),
                              child: Icon(
                                _isHelperEnabled ? Icons.flash_on : Icons.flash_off,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Helper Status',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  _isHelperEnabled ? 'ACTIVE & READY' : 'CURRENTLY OFFLINE',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white.withValues(alpha: 0.7),
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Transform.scale(
                          scale: 1.2,
                          child: Switch.adaptive(
                            value: _isHelperEnabled,
                            activeColor: Colors.white,
                            activeTrackColor: Colors.white.withValues(alpha: 0.3),
                            onChanged: (value) {
                              setState(() {
                                _isHelperEnabled = value;
                              });
                              _updateHelperStatus(value);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _isHelperEnabled 
                            ? 'You are now visible to everyone! People in your area can call you for help.'
                            : 'Toggle this switch to become a Helper and start making a difference in your community.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.6,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),

              // Skills & Expertise Section
              const Text(
                'Skills & Expertise',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5),
              ),
              const SizedBox(height: 16),
              
              if (_isEditing)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _availableSkills.map((skill) {
                    final isSelected = _selectedSkills.contains(skill);
                    return FilterChip(
                      label: Text(skill),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedSkills.add(skill);
                          } else {
                            _selectedSkills.remove(skill);
                          }
                        });
                      },
                      backgroundColor: AppTheme.secondaryBlack,
                      selectedColor: const Color(0xFF6A11CB).withValues(alpha: 0.4),
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.white60,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: isSelected ? Colors.white24 : Colors.transparent),
                      ),
                    );
                  }).toList(),
                )
              else if (_currentUser!.skills.isEmpty)
                 _buildEmptyCard('No skills added yet', Icons.lightbulb_outline)
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _currentUser!.skills.map((skill) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2C3E50), Color(0xFF4CA1AF)], // Deep Sea Gradient
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 6, offset: const Offset(0, 3)),
                        ],
                      ),
                      child: Text(
                        skill,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    );
                  }).toList(),
                ),
              
              const SizedBox(height: 32),

              // Location Card
              const Text(
                'Work Area',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00B4DB), Color(0xFF0083B0)], // Sky Blue Gradient
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF00B4DB).withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 6)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.location_on, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Current Coverage',
                            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                          ),
                          Text(
                            _currentUser!.locationName ?? 'Not Configured',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    if (_isEditing)
                      CircleAvatar(
                        backgroundColor: Colors.white,
                        child: IconButton(
                          icon: const Icon(Icons.my_location, color: Color(0xFF0083B0)),
                          onPressed: _updateLocation,
                        ),
                      ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),

              // Rating & Statistics
              if (!_isEditing)
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Rating',
                        _currentUser!.rating.toStringAsFixed(1),
                        Icons.star,
                        Colors.amber,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'Help Points',
                        (_currentUser!.totalRatings * 10).toString(), // Simple gamification
                        Icons.local_fire_department,
                        Colors.orange,
                      ),
                    ),
                  ],
                ),
              
              const SizedBox(height: 32),
              if (!_isEditing) ...[
                const Text(
                  'Community Feedback',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 16),
                _buildRecentReviewsSection(),
              ],
              
              const SizedBox(height: 40),

              // Logout Button
              if (!_isEditing)
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: TextButton.icon(
                    onPressed: () => _showLogoutDialog(context),
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text(
                      'Logout Session',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
        ),
      );
    },
  );
}

  Widget _buildEditableField(TextEditingController controller, String label, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white60),
          prefixIcon: Icon(icon, color: AppTheme.accentPurple),
          filled: true,
          fillColor: AppTheme.secondaryBlack,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 1.2),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.secondaryBlack,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoRowItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.accentPurple.withValues(alpha: 0.7)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
              Text(
                value.isEmpty ? 'Not set' : value,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.secondaryBlack,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }



  Future<void> _updateHelperStatus(bool isEnabled) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('users').doc(user.uid).update({
        'isHelperEnabled': isEnabled,
        'lastActive': DateTime.now().millisecondsSinceEpoch,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEnabled ? 'Helper status enabled!' : 'Helper status disabled'),
            backgroundColor: isEnabled ? AppTheme.successColor : AppTheme.warningColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating helper status: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        // Revert the state on error
        setState(() {
          _isHelperEnabled = !_isHelperEnabled;
        });
      }
    }
  }

  Widget _buildRecentReviewsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('ratings')
          .where('toUserId', isEqualTo: _currentUser!.uid)
          .where('isPublic', isEqualTo: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Container(
            decoration: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.darkCardDecoration
                : AppTheme.lightCardDecoration,
            padding: const EdgeInsets.all(16),
            child: const Text('Could not load reviews right now.'),
          );
        }

        final reviews = (snapshot.data?.docs ?? [])
            .map((doc) => RatingModel.fromFirebase(doc.data() as Map<String, dynamic>, doc.id))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (reviews.isEmpty) {
          return Container(
            decoration: AppTheme.cardDecoration,
            padding: const EdgeInsets.all(16),
            child: const Text('No reviews yet. Complete a few tasks to build trust.'),
          );
        }

        return Column(
          children: reviews.take(5).map((review) {
            final date =
                '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}';
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: AppTheme.cardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        review.rating.toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Text(date, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'From: ${review.fromUserName}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if ((review.feedback ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      review.feedback!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildEmptyCard(String text, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.secondaryBlack,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white24, size: 28),
          const SizedBox(width: 16),
          Text(text, style: const TextStyle(color: Colors.white24, fontStyle: FontStyle.italic, fontSize: 16)),
        ],
      ),
    );
  }
}
