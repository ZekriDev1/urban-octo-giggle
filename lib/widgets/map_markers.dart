import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants/app_colors.dart';

/// Custom marker widget for current user location
/// This displays a blue circle with a white center dot to indicate the user's position
class CurrentLocationMarker extends StatelessWidget {
  final String? label;
  
  const CurrentLocationMarker({
    super.key,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Outer blue circle
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.3),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.blue,
              width: 2,
            ),
          ),
          child: const Center(
            // Inner white dot
            child: Icon(
              Icons.location_on,
              color: Colors.blue,
              size: 16,
            ),
          ),
        ),
        // Label if provided
        if (label != null) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label!,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.black,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Custom marker widget for destination location
/// This displays a green pin icon to indicate the destination
class DestinationMarker extends StatelessWidget {
  final String? label;
  
  const DestinationMarker({
    super.key,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Green pin icon
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.success,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.white,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.place,
            color: AppColors.white,
            size: 20,
          ),
        ),
        // Label if provided
        if (label != null) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label!,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.black,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Helper function to create a marker point for flutter_map
/// Converts LatLng to a point that can be used with MarkerLayer
LatLng createMarkerPoint(double latitude, double longitude) {
  return LatLng(latitude, longitude);
}

