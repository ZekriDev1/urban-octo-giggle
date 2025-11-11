/// Location model for addresses and coordinates
class LocationModel {
  final String? id;
  final String address;
  final double latitude;
  final double longitude;
  final String? name; // For favorite locations
  final bool isFavorite;
  final DateTime? lastUsed;

  LocationModel({
    this.id,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.name,
    this.isFavorite = false,
    this.lastUsed,
  });

  /// Create LocationModel from JSON
  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      id: json['id'] as String?,
      address: json['address'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      name: json['name'] as String?,
      isFavorite: json['is_favorite'] as bool? ?? false,
      lastUsed: json['last_used'] != null ? DateTime.parse(json['last_used']) : null,
    );
  }

  /// Convert LocationModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'name': name,
      'is_favorite': isFavorite,
      'last_used': lastUsed?.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  LocationModel copyWith({
    String? id,
    String? address,
    double? latitude,
    double? longitude,
    String? name,
    bool? isFavorite,
    DateTime? lastUsed,
  }) {
    return LocationModel(
      id: id ?? this.id,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      name: name ?? this.name,
      isFavorite: isFavorite ?? this.isFavorite,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }
}

