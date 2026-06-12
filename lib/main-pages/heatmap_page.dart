import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:geolocator/geolocator.dart';

import 'package:reliefnet/l10n/app_localizations.dart';

class HeatMapPage extends StatefulWidget {
  final Function(String docId)? onReportSelected;
  const HeatMapPage({super.key, this.onReportSelected});

  @override
  State<HeatMapPage> createState() => _HeatMapPageState();
}

class _HeatMapPageState extends State<HeatMapPage> {
  // India center as a fallback
  static const LatLng _indiaCenter = LatLng(20.5937, 78.9629);
  bool _hasMovedToInitialLocation = false;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    await _moveToCurrentLocation();
    if (mounted && !_hasMovedToInitialLocation) {
      setState(() {
        _hasMovedToInitialLocation = true;
      });
    }
  }

  Future<void> _moveToCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        _mapController.move(LatLng(position.latitude, position.longitude), 11.0);
        _hasMovedToInitialLocation = true;
      }
    } catch (e) {
      debugPrint("Location error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('reports').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error loading data: ${snapshot.error}'));
        }

        final reports = snapshot.data?.docs ?? [];
        final List<WeightedLatLng> heatData = [];
        final List<Marker> markers = [];

        for (var doc in reports) {
          final reportData = doc.data() as Map<String, dynamic>;
          final lat = (reportData['lat'] as num?)?.toDouble() ?? 0.0;
          final lng = (reportData['lng'] as num?)?.toDouble() ?? 0.0;
          
          if (lat != 0.0 && lng != 0.0) {
            final point = LatLng(lat, lng);
            final urgency = reportData['urgency']?.toString().toLowerCase();
            
            double intensity = 0.3;
            Color mColor = Colors.green;
            if (urgency == 'high') {
              intensity = 1.0;
              mColor = Colors.red;
            } else if (urgency == 'medium') {
              intensity = 0.6;
              mColor = Colors.orange;
            }

            heatData.add(WeightedLatLng(point, intensity));
            markers.add(
              Marker(
                point: point,
                width: 32,
                height: 32,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (widget.onReportSelected != null) {
                      widget.onReportSelected!(doc.id);
                    }
                  },
                  child: Center(
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: mColor.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
        }

        return Stack(
          children: [
            // Map Layer
            FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: _indiaCenter,
                initialZoom: 5.0,
                maxZoom: 18,
                minZoom: 3,
                interactionOptions: InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                  userAgentPackageName: 'com.reliefnet.app',
                  tileBuilder: (context, tileWidget, tile) {
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
                if (heatData.isNotEmpty)
                  HeatMapLayer(
                    heatMapDataSource: InMemoryHeatMapDataSource(data: heatData),
                    heatMapOptions: HeatMapOptions(
                      radius: 40,
                      gradient: {
                        0.2: Colors.blue,
                        0.4: Colors.cyan,
                        0.6: Colors.green,
                        0.8: Colors.orange,
                        1.0: Colors.red,
                      },
                    ),
                  ),
                if (markers.isNotEmpty)
                  MarkerLayer(markers: markers),
              ],
            ),

            // Top Status Bar Overlay
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.cardColor.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.analytics_outlined, color: Colors.blue, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(l10n.report_concentration, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(l10n.locations_mapped(heatData.length), style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    _buildLegendChip(l10n.high, Colors.red),
                    const SizedBox(width: 6),
                    _buildLegendChip(l10n.medium, Colors.orange),
                    const SizedBox(width: 6),
                    _buildLegendChip(l10n.low, Colors.green),
                  ],
                ),
              ),
            ),

            // FABs
            Positioned(
              bottom: 16,
              left: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'refresh_map',
                    onPressed: () => setState(() {}),
                    backgroundColor: theme.cardColor,
                    child: Icon(Icons.refresh, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 12),
                  FloatingActionButton(
                    heroTag: 'my_loc',
                    onPressed: _moveToCurrentLocation,
                    child: const Icon(Icons.my_location),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLegendChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
