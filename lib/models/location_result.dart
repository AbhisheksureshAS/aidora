class LocationResult {
  final bool success;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? error;

  LocationResult._({
    required this.success,
    this.latitude,
    this.longitude,
    this.address,
    this.error,
  });

  factory LocationResult.success({
    required double latitude,
    required double longitude,
    required String address,
  }) {
    return LocationResult._(
      success: true,
      latitude: latitude,
      longitude: longitude,
      address: address,
    );
  }

  factory LocationResult.error(String error) {
    return LocationResult._(
      success: false,
      error: error,
    );
  }

  bool get isSuccess => success;
  bool get isError => !success;
  String? get errorMessage => error;
  double? get lat => latitude;
  double? get lng => longitude;
  String? get locationAddress => address;
}
