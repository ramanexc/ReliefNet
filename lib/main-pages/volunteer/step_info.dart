import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:reliefnet/widgets/ai_summary_card.dart';

class StepInfo extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback onNext;
  const StepInfo({super.key, required this.docId, required this.data, required this.onNext});

  @override
  State<StepInfo> createState() => _StepInfoState();
}

class _StepInfoState extends State<StepInfo> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Color _urgencyColor(String urgency) {
    switch (urgency) {
      case 'High':
        return Colors.red.shade600;
      case 'Medium':
        return Colors.amber.shade700;
      case 'Low':
        return Colors.green.shade600;
      default:
        return Colors.grey;
    }
  }

  IconData _issueIcon(String type) {
    switch (type.toLowerCase()) {
      case 'medical':
        return Icons.medical_services;
      case 'food':
        return Icons.fastfood;
      case 'shelter':
        return Icons.house;
      case 'fire':
        return Icons.local_fire_department;
      case 'water':
        return Icons.water_drop;
      default:
        return Icons.report_problem;
    }
  }


  Future<void> _startJourney() async {
    await FirebaseFirestore.instance.collection('reports').doc(widget.docId).update({
      'status': 'in_progress',
    });
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by KeepAlive

    final issue = widget.data['issueType'] ?? 'Unknown Issue';
    final urgency = widget.data['urgency'] ?? 'Low';
    final description = widget.data['description'] ?? '';
    final reporterName = widget.data['reporterName'] ?? widget.data['userName'] ?? widget.data['submittedByName'] ?? 'Anonymous';
    final timestamp = widget.data['timestamp'] as Timestamp?;
    final mediaUrls = List<String>.from(widget.data['mediaUrls'] ?? []);
    final aiSummary = widget.data['aiSummary'] as Map<String, dynamic>?;
    final lat = (widget.data['lat'] as num?)?.toDouble();
    final lng = (widget.data['lng'] as num?)?.toDouble();
    final address = widget.data['address'] ?? widget.data['location'] ?? '';
    final status = widget.data['status'] ?? 'assigned';

    final colorScheme = Theme.of(context).colorScheme;

    String dateStr = '';
    if (timestamp != null) {
      dateStr = DateFormat('dd MMM, hh:mm a').format(timestamp.toDate());
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Meta Info
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(_issueIcon(issue), color: colorScheme.primary, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              issue,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  "Urgency: ",
                                  style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _urgencyColor(urgency).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    urgency,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                      color: _urgencyColor(urgency),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Reporter Details
                  _buildSectionCard(
                    context: context,
                    title: "INCIDENT DESCRIPTION",
                    icon: Icons.description_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          description.isNotEmpty ? description : "No description provided.",
                          style: const TextStyle(fontSize: 15, height: 1.6),
                        ),
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: colorScheme.onSurface.withValues(alpha: 0.08),
                              child: Icon(Icons.person, size: 14, color: colorScheme.onSurface.withValues(alpha: 0.7)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Reported by $reporterName",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (dateStr.isNotEmpty)
                              Text(
                                dateStr,
                                style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Gemini AI card
                  if (aiSummary != null) ...[
                    AiSummaryCard(aiSummary: aiSummary),
                    const SizedBox(height: 16),
                  ],

                  // Reporter Uploaded Media
                  if (mediaUrls.isNotEmpty) ...[
                    const Row(
                      children: [
                        Icon(Icons.photo_library, size: 16),
                        SizedBox(width: 8),
                        Text(
                          "ATTACHED MEDIA FILES",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: mediaUrls.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 10),
                        itemBuilder: (ctx, idx) {
                          final url = mediaUrls[idx];
                          final isVideo = url.toLowerCase().contains('.mp4') || url.toLowerCase().contains('.mov');
                          return GestureDetector(
                            onTap: () async {
                              final uri = Uri.parse(url);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: isVideo
                                  ? Container(
                                      width: 120,
                                      color: Colors.black12,
                                      child: const Icon(Icons.play_circle_fill, size: 40, color: Colors.black45),
                                    )
                                  : Image.network(
                                      url,
                                      width: 120,
                                      height: 120,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        width: 120,
                                        color: Colors.black12,
                                        child: const Icon(Icons.broken_image),
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Map & Location
                  if (lat != null && lng != null) ...[
                    _buildSectionCard(
                      context: context,
                      title: "INCIDENT LOCATION",
                      icon: Icons.location_on_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (address.toString().isNotEmpty) ...[
                            Text(
                              address.toString(),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 6),
                          ],
                          Text(
                            "${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}",
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                          ),
                          const SizedBox(height: 14),
                          
                          // Mini Map View using Google Maps Tiles Template
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: SizedBox(
                              height: 180,
                              child: FlutterMap(
                                options: MapOptions(
                                  initialCenter: LatLng(lat, lng),
                                  initialZoom: 14.0,
                                  interactionOptions: const InteractionOptions(
                                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                                  ),
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
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: LatLng(lat, lng),
                                        width: 40,
                                        height: 40,
                                        child: const Icon(Icons.location_on, color: Colors.red, size: 36),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          
                          // Google Maps button
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                side: BorderSide(color: Colors.blue.shade400),
                                foregroundColor: Colors.blue.shade600,
                              ),
                              onPressed: () async {
                                final mapsUri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
                                try {
                                  await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
                                } catch (_) {
                                  final webUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                                  await launchUrl(webUri, mode: LaunchMode.externalApplication);
                                }
                              },
                              icon: const Icon(Icons.navigation_outlined, size: 18),
                              label: const Text("Open in Google Maps", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // Start Journey button fixed bottom
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4)),
              ],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: status == 'assigned' ? _startJourney : widget.onNext,
                icon: Icon(status == 'assigned' ? Icons.directions_run : Icons.arrow_forward),
                label: Text(
                  status == 'assigned' ? "Start Journey" : "Next: Verify Arrival",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: colorScheme.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
