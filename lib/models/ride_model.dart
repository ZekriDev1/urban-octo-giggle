/// Ride model representing a ride booking
class RideModel {
  final String id;
  final String userId;
  final double pickupLatitude;
  final double pickupLongitude;
  final String pickupAddress;
  final double destinationLatitude;
  final double destinationLongitude;
  final String destinationAddress;
  final double? fare;
  final String status; // 'pending', 'accepted', 'in_progress', 'completed', 'cancelled'
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? driverId;
  final int? estimatedDuration; // in minutes
  final double? distance; // in kilometers

  RideModel({
    required this.id,
    required this.userId,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.pickupAddress,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.destinationAddress,
    this.fare,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.driverId,
    this.estimatedDuration,
    this.distance,
  });

  /// Create RideModel from JSON
  factory RideModel.fromJson(Map<String, dynamic> json) {
    return RideModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      pickupLatitude: (json['pickup_latitude'] as num).toDouble(),
      pickupLongitude: (json['pickup_longitude'] as num).toDouble(),
      pickupAddress: json['pickup_address'] as String,
      destinationLatitude: (json['destination_latitude'] as num).toDouble(),
      destinationLongitude: (json['destination_longitude'] as num).toDouble(),
      destinationAddress: json['destination_address'] as String,
      fare: json['fare'] != null ? (json['fare'] as num).toDouble() : null,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      driverId: json['driver_id'] as String?,
      estimatedDuration: json['estimated_duration'] as int?,
      distance: json['distance'] != null ? (json['distance'] as num).toDouble() : null,
    );
  }

  /// Convert RideModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'pickup_latitude': pickupLatitude,
      'pickup_longitude': pickupLongitude,
      'pickup_address': pickupAddress,
      'destination_latitude': destinationLatitude,
      'destination_longitude': destinationLongitude,
      'destination_address': destinationAddress,
      'fare': fare,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'driver_id': driverId,
      'estimated_duration': estimatedDuration,
      'distance': distance,
    };
  }
}

