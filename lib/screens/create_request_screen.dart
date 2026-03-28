import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../models/help_request_model.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class CreateRequestScreen extends StatefulWidget {
  final RequestCategory? initialCategory;
  final String? preSelectedHelperId;
  final String? preSelectedHelperName;

  const CreateRequestScreen({
    super.key,
    this.initialCategory,
    this.preSelectedHelperId,
    this.preSelectedHelperName,
  });

  @override
  State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  
  late RequestCategory _selectedCategory;
  RequestUrgency _selectedUrgency = RequestUrgency.medium;
  final List<String> _selectedSkills = [];
  
  double? _latitude;
  double? _longitude;
  String? _locationName;
  bool _isLoading = false;
  bool _isGettingLocation = false;

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
    _selectedCategory = widget.initialCategory ?? RequestCategory.dailyTask;
    
    if (widget.preSelectedHelperName != null) {
      _descriptionController.text = 'I am requesting your help directly!';
    }
    
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled')),
        );
        setState(() => _isGettingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
          setState(() => _isGettingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Location permissions are permanently denied. Open app settings.'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: Geolocator.openAppSettings,
            ),
          ),
        );
        setState(() => _isGettingLocation = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final locationName = '${placemark.locality}, ${placemark.administrativeArea}';
        
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _locationName = locationName;
          _isGettingLocation = false;
        });
      }
    } catch (e) {
      setState(() => _isGettingLocation = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    }
  }

  Future<void> _createRequest() async {
    if (_titleController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // Get user info
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      
      final newRequestRef = _firestore.collection('help_requests').doc();
      final now = DateTime.now();
      final helpRequest = HelpRequestModel(
        id: newRequestRef.id,
        seekerId: user.uid,
        seekerName: userData?['name'] ?? user.email!.split('@')[0],
        seekerEmail: user.email!,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        urgency: _selectedUrgency,
        latitude: _latitude,
        longitude: _longitude,
        locationName: _locationName,
        createdAt: now,
        helperId: widget.preSelectedHelperId,
        helperName: widget.preSelectedHelperName,
        offeredAmount: _amountController.text.trim().isNotEmpty
            ? double.tryParse(_amountController.text.trim())
            : null,
        requiredSkills: _selectedSkills,
      );

      await newRequestRef.set({
        ...helpRequest.toFirebase(),
        'updatedAt': now.millisecondsSinceEpoch,
      });

      await NotificationService.notifyNewRequest(helpRequest);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Help request created successfully!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating request: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Help Request'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createRequest,
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Post'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.preSelectedHelperName != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: AppTheme.primaryPurple),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Directly requesting: ${widget.preSelectedHelperName}',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Title
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title *',
                hintText: 'Brief description of what you need help with',
              ),
              maxLength: 100,
            ),
            const SizedBox(height: 16),

            // Description
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description *',
                hintText: 'Provide more details about your request',
              ),
              maxLines: 5,
              maxLength: 500,
            ),
            const SizedBox(height: 16),

            // Category
            Text(
              'Category',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: RequestCategory.values.map((category) {
                  final isSelected = _selectedCategory == category;
                  return FilterChip(
                    label: Text(
                      category.displayName,
                      style: TextStyle(
                        color: isSelected ? AppTheme.accentWhite : AppTheme.textSecondary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _selectedCategory = selected ? category : RequestCategory.dailyTask);
                    },
                    backgroundColor: isSelected ? AppTheme.primaryPurple : AppTheme.secondaryBlack,
                    side: BorderSide(
                      color: isSelected ? AppTheme.primaryPurple : AppTheme.textSecondary.withValues(alpha: 0.2),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // Urgency
            Text(
              'Urgency Level',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: RequestUrgency.values.map((urgency) {
                  final isSelected = _selectedUrgency == urgency;
                  return FilterChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getUrgencyIcon(urgency),
                          size: 16,
                          color: isSelected ? Colors.white : _getUrgencyColor(urgency),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          urgency.displayName,
                          style: TextStyle(
                            color: isSelected ? AppTheme.accentWhite : AppTheme.textSecondary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _selectedUrgency = selected ? urgency : RequestUrgency.medium);
                    },
                    backgroundColor: isSelected ? _getUrgencyColor(urgency) : AppTheme.secondaryBlack,
                    side: BorderSide(
                      color: isSelected ? _getUrgencyColor(urgency) : AppTheme.textSecondary.withValues(alpha: 0.2),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // Required Skills
            Text(
              'Required Skills (Optional)',
              style: Theme.of(context).textTheme.headlineSmall,
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
                    setState(() {
                      if (selected) {
                        _selectedSkills.add(skill);
                      } else {
                        _selectedSkills.remove(skill);
                      }
                    });
                  },
                  backgroundColor: AppTheme.secondaryBlack,
                  selectedColor: AppTheme.primaryPurple.withValues(alpha: 0.3),
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.accentPurple : AppTheme.textSecondary,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Offered Amount
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Offered Amount (Optional)',
                hintText: 'Enter amount you\'re willing to pay',
                prefixText: '\$ ',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),

            // Location
            Text(
              'Location',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Container(
              decoration: AppTheme.cardDecoration,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on,
                    color: AppTheme.primaryPurple,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _isGettingLocation
                        ? const Text('Getting location...')
                        : Text(
                            _locationName ?? 'Location not available',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                  ),
                  if (!_isGettingLocation)
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _getCurrentLocation,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createRequest,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Post Help Request'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getUrgencyColor(RequestUrgency urgency) {
    switch (urgency) {
      case RequestUrgency.high:
        return AppTheme.errorColor;
      case RequestUrgency.medium:
        return AppTheme.warningColor;
      case RequestUrgency.low:
        return AppTheme.successColor;
    }
  }

  IconData _getUrgencyIcon(RequestUrgency urgency) {
    switch (urgency) {
      case RequestUrgency.low:
        return Icons.arrow_downward;
      case RequestUrgency.medium:
        return Icons.remove;
      case RequestUrgency.high:
        return Icons.priority_high;
    }
  }
}
