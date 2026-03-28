import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/location_service.dart';
import '../models/user_model.dart';
import '../theme/app_theme.dart';
import 'create_request_screen.dart';

class NearbyHelpersScreen extends StatefulWidget {
  const NearbyHelpersScreen({super.key});

  @override
  State<NearbyHelpersScreen> createState() => _NearbyHelpersScreenState();
}

class _NearbyHelpersScreenState extends State<NearbyHelpersScreen> {
  
  List<UserModel> _nearbyHelpers = [];
  final List<String> _selectedSkills = [];
  double _searchRadius = 10.0;
  bool _isLoading = false;
  String? _userLocation;
  double? _userLatitude;
  double? _userLongitude;

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
    _loadNearbyHelpers();
  }

  Future<void> _loadNearbyHelpers() async {
    setState(() => _isLoading = true);
    
    try {
      final locationResult = await LocationService.getCurrentLocation();
      
      if (locationResult.isSuccess) {
        final address = await LocationService.getAddressFromCoordinates(
          locationResult.lat!,
          locationResult.lng!,
        );
        
        final helpers = await LocationService.findNearbyHelpers(
          locationResult.lat!,
          locationResult.lng!,
          radiusKm: _searchRadius,
          requiredSkills: _selectedSkills,
        );
        
        final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
        
        setState(() {
          _userLatitude = locationResult.lat;
          _userLongitude = locationResult.lng;
          _userLocation = address;
          _nearbyHelpers = helpers.where((h) => h.uid != currentUserUid).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _nearbyHelpers = [];
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(locationResult.errorMessage ?? 'Failed to get location'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _nearbyHelpers = [];
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Filter Helpers'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Radius
                  Text(
                    'Search Radius',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: _searchRadius,
                    min: 1.0,
                    max: 50.0,
                    divisions: 49,
                    label: '${_searchRadius.round()} km',
                    onChanged: (value) {
                      setDialogState(() => _searchRadius = value);
                    },
                  ),
                  Text(
                    '${_searchRadius.round()} km',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),

                  // Skills Filter
                  Text(
                    'Required Skills',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableSkills.map((skill) {
                      final isSelected = _selectedSkills.contains(skill);
                      return FilterChip(
                        label: Text(skill),
                        selected: isSelected,
                        onSelected: (selected) {
                          setDialogState(() {
                            if (selected) {
                              _selectedSkills.add(skill);
                            } else {
                              _selectedSkills.remove(skill);
                            }
                          });
                        },
                        backgroundColor: AppTheme.veryLightPurple.withValues(alpha: 0.3),
                        selectedColor: AppTheme.primaryPurple.withValues(alpha: 0.3),
                        labelStyle: TextStyle(
                          color: isSelected ? AppTheme.primaryPurple : AppTheme.darkPurple,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {});
                  Navigator.of(context).pop();
                  _loadNearbyHelpers();
                },
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Helpers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNearbyHelpers,
          ),
        ],
      ),
      body: Column(
        children: [
          // Location Info
          if (_userLocation != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration,
              child: Row(
                children: [
                  Icon(
                    Icons.location_on,
                    color: AppTheme.primaryPurple,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Location',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          _userLocation!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${_searchRadius.round()} km',
                    style: TextStyle(
                      color: AppTheme.primaryPurple,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          // Selected Skills
          if (_selectedSkills.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: AppTheme.cardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Skills',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedSkills.map((skill) {
                      return Chip(
                        label: Text(skill),
                        backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.1),
                        labelStyle: const TextStyle(color: AppTheme.primaryPurple),
                        onDeleted: () {
                          setState(() {
                            _selectedSkills.remove(skill);
                          });
                          _loadNearbyHelpers();
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

          // Helpers List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _nearbyHelpers.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No helpers found nearby'),
                            Text('Try expanding your search radius'),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _nearbyHelpers.length,
                        itemBuilder: (context, index) {
                          final helper = _nearbyHelpers[index];
                          return HelperCard(
                            helper: helper,
                            userLatitude: _userLatitude!,
                            userLongitude: _userLongitude!,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class HelperCard extends StatelessWidget {
  final UserModel helper;
  final double userLatitude;
  final double userLongitude;

  const HelperCard({
    super.key,
    required this.helper,
    required this.userLatitude,
    required this.userLongitude,
  });

  double get distance {
    if (helper.latitude != null && helper.longitude != null) {
      return LocationService.calculateDistance(
        userLatitude,
        userLongitude,
        helper.latitude!,
        helper.longitude!,
      );
    }
    return 0.0;
  }

  String get distanceText {
    if (distance < 1.0) {
      return '${(distance * 1000).round()} m';
    } else {
      return '${distance.toStringAsFixed(1)} km';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with name and rating
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.veryLightPurple,
                backgroundImage: helper.profileImageUrl != null
                    ? NetworkImage(helper.profileImageUrl!)
                    : null,
                child: helper.profileImageUrl == null
                    ? Text(
                        helper.name.isNotEmpty ? helper.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: AppTheme.primaryPurple,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      helper.name,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          size: 16,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          helper.rating > 0 
                              ? '${helper.rating.toStringAsFixed(1)} (${helper.totalRatings})'
                              : 'No ratings',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  distanceText,
                  style: const TextStyle(
                    color: AppTheme.primaryPurple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Bio
          if (helper.bio.isNotEmpty) ...[
            Text(
              helper.bio,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
          ],

          // Skills
          if (helper.skills.isNotEmpty) ...[
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: helper.skills.take(4).map((skill) {
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
            if (helper.skills.length > 4) ...[
              const SizedBox(width: 4),
              Text(
                '+${helper.skills.length - 4} more',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 11,
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],

          // Location
          if (helper.locationName != null) ...[
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  helper.locationName!,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CreateRequestScreen(
                      preSelectedHelperId: helper.uid,
                      preSelectedHelperName: helper.name,
                    ),
                  ),
                );
              },
              child: const Text('Request Help'),
            ),
          ),
        ],
      ),
    );
  }
}
