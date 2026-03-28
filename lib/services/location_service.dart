import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import '../models/user_model.dart';
import '../models/help_request_model.dart';
import '../models/location_result.dart';

class LocationService {
  static const double defaultSearchRadius = 10.0; // 10 km
  
  static Future<LocationResult> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult.error('Location services are disabled. Please enable location services in your device settings.');
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationResult.error('Location permissions are denied. Please grant permission to access location.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult.error('Location permissions are permanently denied. Please enable location permissions in app settings.');
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // Get address from coordinates
      String address = 'Unknown Location';
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          address = _formatAddress(place);
        }
      } catch (e) {
        // Address lookup failed, but we still have coordinates
        print('Address lookup failed: $e');
      }

      return LocationResult.success(
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
      );

    } catch (e) {
      String errorMessage = 'Failed to get location';
      if (e.toString().contains('timeout')) {
        errorMessage = 'Location request timed out. Please try again.';
      } else if (e.toString().contains('permission')) {
        errorMessage = 'Location permission denied. Please enable location access.';
      } else {
        errorMessage = 'Unable to get location: ${e.toString()}';
      }
      
      return LocationResult.error(errorMessage);
    }
  }

  static String _formatAddress(Placemark place) {
    final parts = <String>[];
    
    if (place.street?.isNotEmpty == true) parts.add(place.street!);
    if (place.subLocality?.isNotEmpty == true) parts.add(place.subLocality!);
    if (place.locality?.isNotEmpty == true) parts.add(place.locality!);
    if (place.administrativeArea?.isNotEmpty == true) parts.add(place.administrativeArea!);
    if (place.country?.isNotEmpty == true) parts.add(place.country!);
    
    return parts.isNotEmpty ? parts.join(', ') : 'Unknown Location';
  }

  // Legacy method for backward compatibility
  static Future<Position?> getCurrentPosition() async {
    final result = await getCurrentLocation();
    if (result.isSuccess && result.lat != null && result.lng != null) {
      return Position(
        latitude: result.lat!,
        longitude: result.lng!,
        timestamp: DateTime.now(),
        accuracy: 0.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
    }
    return null;
  }

  static Future<String?> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final parts = [
          if (placemark.locality != null && placemark.locality!.isNotEmpty) placemark.locality,
          if (placemark.administrativeArea != null && placemark.administrativeArea!.isNotEmpty) placemark.administrativeArea,
        ];
        return parts.join(', ');
      }
      return null;
    } catch (e) {
      throw Exception('Error getting address: $e');
    }
  }

  static double _toRadians(double degrees) {
    return degrees * (3.14159265359 / 180);
  }

  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    
    final double a = 
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final double c = 2 * math.asin(math.sqrt(a));
    
    return earthRadius * c;
  }

  static Future<List<UserModel>> findNearbyHelpers(
    double userLatitude,
    double userLongitude, {
    double radiusKm = defaultSearchRadius,
    List<String> requiredSkills = const [],
  }) async {
    try {
      // Simplified query - only filter by helper status with limit for performance
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('isHelperEnabled', isEqualTo: true)
          .limit(100) // Limit to prevent excessive data transfer
          .get();

      List<UserModel> nearbyHelpers = [];

      for (final doc in snapshot.docs) {
        final userData = doc.data() as Map<String, dynamic>;
        final user = UserModel.fromFirebase(userData, doc.id);
        
        // Filter by distance in client-side code
        if (user.latitude != null && user.longitude != null) {
          final distance = calculateDistance(
            userLatitude,
            userLongitude,
            user.latitude!,
            user.longitude!,
          );

          if (distance <= radiusKm) {
            // Check if user has required skills
            if (requiredSkills.isEmpty || 
                requiredSkills.any((skill) => user.skills.contains(skill))) {
              nearbyHelpers.add(user);
            }
          }
        }
      }

      // Sort by distance
      nearbyHelpers.sort((a, b) {
        if (a.latitude != null && a.longitude != null &&
            b.latitude != null && b.longitude != null) {
          final distanceA = calculateDistance(
            userLatitude, userLongitude, a.latitude!, a.longitude!);
          final distanceB = calculateDistance(
            userLatitude, userLongitude, b.latitude!, b.longitude!);
          return distanceA.compareTo(distanceB);
        }
        return 0;
      });

      return nearbyHelpers;
    } catch (e) {
      throw Exception('Error finding nearby helpers: $e');
    }
  }

  static Future<List<HelpRequestModel>> findNearbyRequests(
    double userLatitude,
    double userLongitude, {
    double radiusKm = defaultSearchRadius,
    RequestCategory? category,
    RequestUrgency? urgency,
  }) async {
    try {
      // Simplified query - only filter by status with limit for performance
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('help_requests')
          .where('status', whereIn: ['pending', 'accepted'])
          .limit(100) // Limit to prevent excessive data transfer
          .get();

      List<HelpRequestModel> nearbyRequests = [];

      for (final doc in snapshot.docs) {
        final requestData = doc.data() as Map<String, dynamic>;
        final request = HelpRequestModel.fromFirebase(requestData, doc.id);
        
        // Filter by distance in client-side code
        if (request.latitude != null && request.longitude != null) {
          final distance = calculateDistance(
            userLatitude,
            userLongitude,
            request.latitude!,
            request.longitude!,
          );

          if (distance <= radiusKm) {
            // Apply additional filters
            bool matchesFilters = true;
            
            if (category != null && request.category != category) {
              matchesFilters = false;
            }
            
            if (urgency != null && request.urgency != urgency) {
              matchesFilters = false;
            }
            
            if (matchesFilters) {
              nearbyRequests.add(request);
            }
          }
        }
      }

      // Sort by distance and then by urgency
      nearbyRequests.sort((a, b) {
        if (a.latitude != null && a.longitude != null &&
            b.latitude != null && b.longitude != null) {
          final distanceA = calculateDistance(
            userLatitude, userLongitude, a.latitude!, a.longitude!);
          final distanceB = calculateDistance(
            userLatitude, userLongitude, b.latitude!, b.longitude!);
          
          // First sort by urgency (high to low)
          final urgencyComparison = b.urgency.level.compareTo(a.urgency.level);
          if (urgencyComparison != 0) return urgencyComparison;
          
          // Then sort by distance
          return distanceA.compareTo(distanceB);
        }
        return 0;
      });

      return nearbyRequests;
    } catch (e) {
      throw Exception('Error finding nearby requests: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getLocationBasedStats(
    double userLatitude,
    double userLongitude, {
    double radiusKm = defaultSearchRadius,
  }) async {
    try {
      final results = await Future.wait([
        findNearbyRequests(userLatitude, userLongitude, radiusKm: radiusKm),
        findNearbyHelpers(userLatitude, userLongitude, radiusKm: radiusKm),
      ]);

      final nearbyRequests = results[0] as List<HelpRequestModel>;
      final nearbyHelpers = results[1] as List<UserModel>;

      // Count requests by category
      final Map<RequestCategory, int> requestsByCategory = {};
      for (final request in nearbyRequests) {
        requestsByCategory[request.category] = (requestsByCategory[request.category] ?? 0) + 1;
      }

      // Count helpers by skills
      final Map<String, int> helpersBySkills = {};
      for (final helper in nearbyHelpers) {
        for (final skill in helper.skills) {
          helpersBySkills[skill] = (helpersBySkills[skill] ?? 0) + 1;
        }
      }

      return [
        {
          'totalRequests': nearbyRequests.length,
          'totalHelpers': nearbyHelpers.length,
          'requestsByCategory': requestsByCategory,
          'helpersBySkills': helpersBySkills,
          'averageDistance': _calculateAverageDistance(
            userLatitude, userLongitude, nearbyRequests),
        },
      ];
    } catch (e) {
      throw Exception('Error getting location stats: $e');
    }
  }

  static double _calculateAverageDistance(
    double userLatitude,
    double userLongitude,
    List<HelpRequestModel> requests,
  ) {
    if (requests.isEmpty) return 0.0;
    
    double totalDistance = 0.0;
    int validRequests = 0;
    
    for (final request in requests) {
      if (request.latitude != null && request.longitude != null) {
        totalDistance += calculateDistance(
          userLatitude, userLongitude, request.latitude!, request.longitude!);
        validRequests++;
      }
    }
    
    return validRequests > 0 ? totalDistance / validRequests : 0.0;
  }
}
