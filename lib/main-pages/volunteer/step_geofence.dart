import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StepGeofence extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback onSuccess;
  const StepGeofence({super.key, required this.docId, required this.data, required this.onSuccess});

  @override
  State<StepGeofence> createState() => _StepGeofenceState();
}

class _StepGeofenceState extends State<StepGeofence> with AutomaticKeepAliveClientMixin {
  Position? _volunteerPosition;
  bool _isChecking = false;
  String? _errorMsg;
  double? _distanceInMeters;
  StreamSubscription<Position>? _positionSubscription;
  final MapController _mapController = MapController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _startLocationListening();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startLocationListening() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _errorMsg = "Location services are disabled.");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _errorMsg = "Location permission denied.");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _errorMsg = "Location permissions are permanently denied.");
        return;
      }

      // Initial position
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _updateLocation(position);

      // Listen for updates
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((Position position) {
        if (mounted) {
          _updateLocation(position);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _errorMsg = "Error setting up GPS tracking: $e");
      }
    }
  }

  void _updateLocation(Position position) {
    final reportLat = (widget.data['lat'] as num?)?.toDouble() ?? 0.0;
    final reportLng = (widget.data['lng'] as num?)?.toDouble() ?? 0.0;
    
    double dist = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      reportLat,
      reportLng,
    );

    setState(() {
      _volunteerPosition = position;
      _distanceInMeters = dist;
      _errorMsg = null;
    });

    // Fit map bounds
    _fitMapBounds();
  }

  void _fitMapBounds() {
    if (_volunteerPosition == null) return;
    final reportLat = (widget.data['lat'] as num?)?.toDouble() ?? 0.0;
    final reportLng = (widget.data['lng'] as num?)?.toDouble() ?? 0.0;

    final bounds = LatLngBounds(
      LatLng(_volunteerPosition!.latitude, _volunteerPosition!.longitude),
      LatLng(reportLat, reportLng),
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(50),
          ),
        );
      }
    });
  }

  Future<void> _verifyArrival() async {
    if (_distanceInMeters == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Awaiting GPS lock... Please wait a moment.")),
      );
      return;
    }

    setState(() => _isChecking = true);

    if (_distanceInMeters! <= 1000) {
      try {
        await FirebaseFirestore.instance.collection('reports').doc(widget.docId).update({
          'status': 'reached',
        });
        widget.onSuccess();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to update status: $e"), backgroundColor: Colors.red),
          );
        }
      }
    } else {
      _showWarningDialog();
    }
    
    if (mounted) {
      setState(() => _isChecking = false);
    }
  }

  void _showWarningDialog() {
    final distanceText = _distanceInMeters! >= 1000
        ? "${(_distanceInMeters! / 1000).toStringAsFixed(2)} km"
        : "${_distanceInMeters!.round()} meters";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.wrong_location, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text("Too Far Away", style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Text(
          "You are currently $distanceText away from the incident location.\n\nYou must be within a 1km radius to confirm arrival. Please travel closer to the location.",
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              _manualOverride();
            },
            child: Text(
              "Proceed Anyway",
              style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _manualOverride() async {
    try {
      await FirebaseFirestore.instance.collection('reports').doc(widget.docId).update({
        'status': 'reached',
      });
      widget.onSuccess();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Override failed: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by KeepAlive

    final reportLat = (widget.data['lat'] as num?)?.toDouble() ?? 0.0;
    final reportLng = (widget.data['lng'] as num?)?.toDouble() ?? 0.0;
    final reportLatLng = LatLng(reportLat, reportLng);

    final colorScheme = Theme.of(context).colorScheme;

    final List<Marker> markers = [
      Marker(
        point: reportLatLng,
        width: 40,
        height: 40,
        child: const Icon(Icons.location_on, color: Colors.red, size: 40),
      ),
    ];

    if (_volunteerPosition != null) {
      markers.add(
        Marker(
          point: LatLng(_volunteerPosition!.latitude, _volunteerPosition!.longitude),
          width: 40,
          height: 40,
          child: Container(
            decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
            child: const Icon(Icons.person, color: Colors.white, size: 24),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Map Container displaying Google Maps Roadmap tiles
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: reportLatLng,
                  initialZoom: 14.0,
                  maxZoom: 18,
                  minZoom: 3,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                    userAgentPackageName: 'com.reliefnet.app',
                    tileBuilder: (context, tileWidget, tile) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      if (isDark) {
                        return ColorFiltered(
                          colorFilter: const ColorFilter.matrix(<double>[
                            -1.0, 0.0, 0.0, 0.0, 255.0,
                            0.0, -1.0, 0.0, 0.0, 255.0,
                            0.0, 0.0, -1.0, 0.0, 255.0,
                            0.0, 0.0, 0.0, 1.0, 0.0,
                          ]),
                          child: tileWidget,
                        );
                      }
                      return tileWidget;
                    },
                  ),
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: reportLatLng,
                        radius: 1000,
                        useRadiusInMeter: true,
                        color: Colors.red.withValues(alpha: 0.12),
                        borderColor: Colors.red.withValues(alpha: 0.4),
                        borderStrokeWidth: 1.5,
                      ),
                    ],
                  ),
                  MarkerLayer(markers: markers),
                ],
              ),
              
              // Top Overlay displaying distance
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Colors.blue,
                        radius: 18,
                        child: Icon(Icons.navigation, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text("Verification Target", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(
                              _distanceInMeters != null
                                  ? "Distance: ${_distanceInMeters! >= 1000 ? '${(_distanceInMeters! / 1000).toStringAsFixed(2)} km' : '${_distanceInMeters!.round()} m'}"
                                  : (_errorMsg ?? "Acquiring your coordinates..."),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _distanceInMeters != null
                                    ? (_distanceInMeters! <= 1000 ? Colors.green : Colors.orange.shade800)
                                    : colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.gps_fixed),
                        onPressed: _startLocationListening,
                        tooltip: "Recalibrate GPS",
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Bottom Action Panel
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, -4)),
            ],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Step 2: Travel to Location",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                "You must arrive within the 1km radius of the report to verify arrival.",
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: _isChecking ? null : _verifyArrival,
                  icon: _isChecking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: const Text(
                    "Verify My Arrival",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
