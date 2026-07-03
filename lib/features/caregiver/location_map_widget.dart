// lib/features/caregiver/location_map_widget.dart
// Shows parent's live location on Google Maps
// Used inside caregiver_home.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:Vitanex/models/location_model.dart';
import 'package:Vitanex/core/services/location_service.dart';
import 'package:Vitanex/theme/app_design_system.dart';

class LocationMapWidget extends StatefulWidget {
  const LocationMapWidget({super.key});

  @override
  State<LocationMapWidget> createState() => _LocationMapWidgetState();
}

class _LocationMapWidgetState extends State<LocationMapWidget> {
  final _locationService = LocationService();
  GoogleMapController? _mapController;
  ParentLocation? _parentLocation;
  StreamSubscription? _locationSub;
  bool _isLoading = true;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _listenToLocation();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _listenToLocation() {
    _locationSub = _locationService.parentLocationStream().listen((location) {
      if (!mounted) return;

      setState(() {
        _parentLocation = location;
        _isLoading = false;
      });

      // Move camera to parent's location
      if (location != null && _mapReady && _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(location.latitude, location.longitude),
            15,
          ),
        );
      }
    });
  }

  String _formatUpdatedAt(DateTime updatedAt) {
    final diff = DateTime.now().difference(updatedAt);
    if (diff.inSeconds < 60) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return "${diff.inDays}d ago";
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── Section header ───────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Parent's Location", style: AppTextStyles.heading),
            if (_parentLocation != null)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.iconBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "Live",
                      style: AppTextStyles.small.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),

        const SizedBox(height: AppSpacing.md),

        // ── Map container ────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            height: 240,
            decoration: BoxDecoration(
              color: AppColors.iconBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: _buildMapContent(),
          ),
        ),

        // ── Location info bar ────────────────────────
        if (_parentLocation != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: [AppShadows.light],
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on,
                    color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "${_parentLocation!.latitude.toStringAsFixed(5)}, "
                    "${_parentLocation!.longitude.toStringAsFixed(5)}",
                    style: AppTextStyles.small,
                  ),
                ),
                Text(
                  _formatUpdatedAt(_parentLocation!.updatedAt),
                  style: AppTextStyles.small.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMapContent() {
    // ── Loading state ────────────────────────────────
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // ── No location / not sharing ────────────────────
    if (_parentLocation == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off,
                size: 40, color: AppColors.hint),
            const SizedBox(height: 12),
            Text(
              "Location not available",
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 4),
            Text(
              "Parent has not shared their location yet",
              style: AppTextStyles.small,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // ── Google Map ───────────────────────────────────
    final parentLatLng = LatLng(
      _parentLocation!.latitude,
      _parentLocation!.longitude,
    );

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: parentLatLng,
            zoom: 15,
          ),
          markers: {
            Marker(
              markerId: const MarkerId('parent'),
              position: parentLatLng,
              infoWindow: const InfoWindow(
                title: 'Parent',
                snippet: 'Current location',
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed,
              ),
            ),
          },
          circles: {
            // Accuracy circle
            Circle(
              circleId: const CircleId('accuracy'),
              center: parentLatLng,
              radius: _parentLocation!.accuracy,
              fillColor: Colors.red.withValues(alpha: 0.1),
              strokeColor: Colors.red.withValues(alpha: 0.3),
              strokeWidth: 1,
            ),
          },
          onMapCreated: (controller) {
            _mapController = controller;
            _mapReady = true;
          },
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
        ),

        // Recenter button
        Positioned(
          bottom: 12,
          right: 12,
          child: GestureDetector(
            onTap: () {
              _mapController?.animateCamera(
                CameraUpdate.newLatLngZoom(parentLatLng, 15),
              );
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [AppShadows.medium],
              ),
              child: const Icon(Icons.my_location,
                  color: AppColors.primary, size: 20),
            ),
          ),
        ),
      ],
    );
  }
}