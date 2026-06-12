import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:reliefnet/services/gemini_service.dart';
import 'package:reliefnet/widgets/ai_summary_card.dart';
import 'package:reliefnet/l10n/app_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage> with AutomaticKeepAliveClientMixin {
  String _selectedFilter = 'All';
  String _selectedSort = 'Nearest';
  Position? _userPosition;
  bool _fetchingLocation = false;
  Map<String, dynamic>? _userProfile;
  String? _aiDashboardSummary;
  bool _isAnalyzingDashboard = false;
  bool _summaryRequested = false;
  Stream<QuerySnapshot>? _reportsStream;

  @override
  bool get wantKeepAlive => true;

  final List<String> _sortOptions = ['Nearest', 'Latest', 'Most Urgent', 'Unassigned Only', 'Completed Only'];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _fetchUserLocation();
    _reportsStream = FirebaseFirestore.instance
        .collection('reports')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> _loadUserProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (doc.exists && mounted) setState(() => _userProfile = doc.data());
  }

  Future<void> _generateDashboardSummary(List<QueryDocumentSnapshot> docs) async {
    if (docs.isEmpty || _isAnalyzingDashboard) return;
    setState(() => _isAnalyzingDashboard = true);
    try {
      final reports = docs.take(10).map((d) => d.data() as Map<String, dynamic>).toList();
      final summary = await GeminiService.generateDashboardOverview(reports);
      if (mounted) setState(() => _aiDashboardSummary = summary);
    } finally {
      if (mounted) setState(() => _isAnalyzingDashboard = false);
    }
  }

  Future<void> _fetchUserLocation() async {
    if (mounted) setState(() => _fetchingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) setState(() => _userPosition = pos);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _fetchingLocation = false);
    }
  }

  Color _urgencyColor(String urgency) {
    switch (urgency) {
      case 'High': return const Color(0xFFEF4444);
      case 'Medium': return const Color(0xFFF59E0B);
      case 'Low': return const Color(0xFF22C55E);
      default: return Colors.grey;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'assigned': return const Color(0xFF6366F1);
      case 'completed': return const Color(0xFF22C55E);
      default: return const Color(0xFF9CA3AF);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'assigned': return Icons.person_outline;
      case 'completed': return Icons.check_circle_outline;
      default: return Icons.radio_button_unchecked;
    }
  }

  IconData _issueIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('food')) return Icons.restaurant_outlined;
    if (t.contains('medical')) return Icons.local_hospital_outlined;
    if (t.contains('shelter')) return Icons.home_outlined;
    if (t.contains('water') || t.contains('sanitation')) return Icons.water_drop_outlined;
    if (t.contains('rescue')) return Icons.volunteer_activism_outlined;
    if (t.contains('utilities') || t.contains('infrastructure')) return Icons.build_outlined;
    return Icons.help_outline;
  }

  String _timeAgo(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    final diff = DateTime.now().difference(timestamp.toDate());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  double _distanceKm(double lat, double lng) {
    if (_userPosition == null) return 10000.0; // Arbitrary high number instead of infinity for sorting
    const R = 6371.0;
    final dLat = (lat - _userPosition!.latitude) * pi / 180;
    final dLng = (lng - _userPosition!.longitude) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) + cos(_userPosition!.latitude * pi / 180) * cos(lat * pi / 180) * sin(dLng / 2) * sin(dLng / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  String _distanceLabel(double? lat, double? lng) {
    if (lat == null || lng == null) return 'No location';
    if (_userPosition == null) return '...';
    final d = _distanceKm(lat, lng);
    if (d >= 10000) return '';
    return d < 1 ? '${(d * 1000).toStringAsFixed(0)} m' : '${d.toStringAsFixed(1)} km';
  }

  int _urgencyRank(String urgency) {
    switch (urgency) {
      case 'High': return 0;
      case 'Medium': return 1;
      case 'Low': return 2;
      default: return 3;
    }
  }

  List<QueryDocumentSnapshot> _applyFilterAndSort(List<QueryDocumentSnapshot> docs) {
    List<QueryDocumentSnapshot> filtered = _selectedFilter == 'All' ? docs : docs.where((d) => d['urgency'] == _selectedFilter).toList();
    
    final unassignedDocs = filtered.where((d) => d['status'] == 'unassigned').toList();
    final assignedDocs = filtered.where((d) => d['status'] == 'assigned').toList();
    final completedDocs = filtered.where((d) => d['status'] == 'completed').toList();

    if (_selectedSort == 'Completed Only') return completedDocs;
    if (_selectedSort == 'Unassigned Only') return unassignedDocs;

    // Get user skills for recommendation logic
    final userSkills = List<String>.from(_userProfile?['skills'] ?? []);

    void sortList(List<QueryDocumentSnapshot> list) {
      list.sort((a, b) {
        // 1. Prioritize skill matches for unassigned tasks
        if (a['status'] == 'unassigned' && b['status'] == 'unassigned' && userSkills.isNotEmpty) {
          final aSkills = List<String>.from(a['aiSummary']?['skillset_required'] ?? []);
          final bSkills = List<String>.from(b['aiSummary']?['skillset_required'] ?? []);
          
          bool aMatch = aSkills.any((s) => userSkills.contains(s));
          bool bMatch = bSkills.any((s) => userSkills.contains(s));

          if (aMatch != bMatch) return aMatch ? -1 : 1;
        }

        switch (_selectedSort) {
          case 'Most Urgent':
            return _urgencyRank(a['urgency'] ?? '').compareTo(_urgencyRank(b['urgency'] ?? ''));
          case 'Nearest':
            return _distanceKm((a['lat'] ?? 0).toDouble(), (a['lng'] ?? 0).toDouble()).compareTo(_distanceKm((b['lat'] ?? 0).toDouble(), (b['lng'] ?? 0).toDouble()));
          case 'Latest':
          default:
            return ((b['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0).compareTo(((a['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0));
        }
      });
    }

    sortList(unassignedDocs);
    sortList(assignedDocs);
    sortList(completedDocs);

    return [...unassignedDocs, ...assignedDocs, ...completedDocs];
  }

  void _showReportDetail(BuildContext context, Map<String, dynamic> data, String docId, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReportDetailSheet(
        data: data,
        docId: docId,
        userProfile: _userProfile,
        distanceLabel: _distanceLabel(data['lat'] as double?, data['lng'] as double?),
        urgencyColor: _urgencyColor(data['urgency'] ?? 'Low'),
        statusColor: _statusColor(data['status'] ?? 'unassigned'),
        statusIcon: _statusIcon(data['status'] ?? 'unassigned'),
        issueIcon: _issueIcon(data['issueType'] ?? 'Other'),
        timeAgo: _timeAgo(data['timestamp'] as Timestamp?),
        l10n: l10n,
      ),
    );
  }

  Future<void> openReportById(String docId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('reports').doc(docId).get();
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        final l10n = AppLocalizations.of(context)!;
        _showReportDetail(context, data, docId, l10n);
      }
    } catch (e) {
      debugPrint("Error opening report: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return StreamBuilder<QuerySnapshot>(
      stream: _reportsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('Error'));
        
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allDocs = snapshot.data?.docs ?? [];
        final total = allDocs.length;
        final high = allDocs.where((d) => d['urgency'] == 'High').length;
        final medium = allDocs.where((d) => d['urgency'] == 'Medium').length;
        final low = allDocs.where((d) => d['urgency'] == 'Low').length;
        final displayDocs = _applyFilterAndSort(allDocs);

        if (allDocs.isNotEmpty && !_summaryRequested) {
          _summaryRequested = true;
          Future.delayed(const Duration(milliseconds: 800), () { if (mounted) _generateDashboardSummary(allDocs); });
        }

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.live_reports, style: theme.textTheme.bodyLarge?.copyWith(fontSize: 22, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text('$total ${l10n.active_reports.toLowerCase()}', style: theme.textTheme.bodyMedium),
                            ],
                          ),
                        ),
                        if (_fetchingLocation) ...[
                          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          const SizedBox(width: 12),
                        ] else if (_userPosition != null) ...[
                          Icon(Icons.location_on, size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 12),
                        ],
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          onPressed: () {
                            _fetchUserLocation();
                            setState(() {
                              _summaryRequested = false;
                              _aiDashboardSummary = null;
                            });
                          },
                          tooltip: 'Reload Reports',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_aiDashboardSummary != null || _isAnalyzingDashboard) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [theme.colorScheme.primary.withOpacity(0.05), theme.colorScheme.primary.withOpacity(0.12)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.auto_awesome, size: 18, color: Colors.blue),
                                const SizedBox(width: 8),
                                Text(l10n.ai_situation_summary, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(_isAnalyzingDashboard ? l10n.analyzing_crisis_data : _aiDashboardSummary ?? '', style: theme.textTheme.bodyMedium?.copyWith(height: 1.4, fontSize: 13, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _sortOptions.map((opt) {
                          final isSel = _selectedSort == opt;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(opt, style: TextStyle(fontSize: 12, color: isSel ? Colors.white : theme.colorScheme.primary)),
                              selected: isSel,
                              selectedColor: theme.colorScheme.primary,
                              backgroundColor: theme.colorScheme.primary.withOpacity(0.05),
                              onSelected: (val) { if (val) setState(() => _selectedSort = opt); },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _FilterChip(label: l10n.all, count: total, color: theme.colorScheme.primary, isSelected: _selectedFilter == 'All', onTap: () => setState(() => _selectedFilter = 'All')),
                        const SizedBox(width: 8),
                        _FilterChip(label: l10n.high, count: high, color: const Color(0xFFEF4444), isSelected: _selectedFilter == 'High', onTap: () => setState(() => _selectedFilter = 'High')),
                        const SizedBox(width: 8),
                        _FilterChip(label: l10n.medium, count: medium, color: const Color(0xFFF59E0B), isSelected: _selectedFilter == 'Medium', onTap: () => setState(() => _selectedFilter = 'Medium')),
                        const SizedBox(width: 8),
                        _FilterChip(label: l10n.low, count: low, color: const Color(0xFF22C55E), isSelected: _selectedFilter == 'Low', onTap: () => setState(() => _selectedFilter = 'Low')),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            if (displayDocs.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inbox_outlined, size: 48, color: theme.colorScheme.primary.withOpacity(0.4)), const SizedBox(height: 12), Text(l10n.no_reports_found, style: theme.textTheme.bodyMedium)])),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final doc = displayDocs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final urgency = data['urgency'] ?? 'Low';
                      final issueType = data['issueType'] ?? 'Other';
                      final status = data['status'] ?? 'unassigned';
                      final isCompleted = status == 'completed';
                      final isUnassigned = status == 'unassigned';

                      bool showHeader = false;
                      String headerTitle = '';
                      if (index == 0) {
                        if (!isUnassigned) {
                          showHeader = true;
                          headerTitle = status == 'assigned' ? 'In Progress' : 'Completed';
                        }
                      } else {
                        final prevStatus = displayDocs[index - 1]['status'] ?? 'unassigned';
                        if (status != prevStatus) {
                          showHeader = true;
                          headerTitle = status == 'assigned' ? 'In Progress' : 'Completed';
                        }
                      }

                      String localizedIssue = issueType;
                      if (issueType == 'Food') {
                        localizedIssue = l10n.food;
                      } else if (issueType == 'Medical') localizedIssue = l10n.medical;
                      else if (issueType == 'Shelter') localizedIssue = l10n.shelter;
                      else if (issueType == 'Other') localizedIssue = l10n.other;

                      String localizedUrgency = urgency;
                      if (urgency == 'High') {
                        localizedUrgency = l10n.high;
                      } else if (urgency == 'Medium') localizedUrgency = l10n.medium;
                      else if (urgency == 'Low') localizedUrgency = l10n.low;

                      String localizedStatus = status;
                      if (status == 'unassigned') {
                        localizedStatus = l10n.unassigned;
                      } else if (status == 'assigned') localizedStatus = l10n.assigned;
                      else if (status == 'completed') localizedStatus = l10n.completed;

                      // Skill matching logic
                      final userSkills = List<String>.from(_userProfile?['skills'] ?? []);
                      final requiredSkills = List<String>.from(data['aiSummary']?['skillset_required'] ?? []);
                      final hasMatch = userSkills.isNotEmpty && requiredSkills.any((s) => userSkills.contains(s));
                      final isRecommended = isUnassigned && hasMatch;

                      return Column(
                        key: ValueKey(doc.id),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showHeader) Padding(
                            padding: const EdgeInsets.only(top: 20, bottom: 10, left: 4),
                            child: Text(headerTitle.toUpperCase(), style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Opacity(
                              opacity: isCompleted ? 0.6 : 1.0,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (isRecommended)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.star, color: Colors.amber, size: 14),
                                          const SizedBox(width: 4),
                                          Text(
                                            "RECOMMENDED FOR YOU",
                                            style: theme.textTheme.labelSmall?.copyWith(
                                              color: Colors.amber.shade800,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  Card(
                                    elevation: isRecommended ? 6 : (isUnassigned ? 4 : 1),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: isRecommended
                                          ? BorderSide(color: Colors.amber.withValues(alpha: 0.5), width: 1.5)
                                          : (isUnassigned 
                                              ? BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.3), width: 1)
                                              : BorderSide.none),
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () => _showReportDetail(context, data, doc.id, l10n),
                                      child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(_issueIcon(issueType), color: theme.colorScheme.primary, size: 20)),
                                                const SizedBox(width: 10),
                                                Expanded(child: Text(localizedIssue, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600))),
                                                if (data['credibility'] != null && data['credibility']['isSpam'] == true)
                                                  Padding(
                                                    padding: const EdgeInsets.only(right: 8),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(4)),
                                                      child: const Text("SPAM", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                                                    ),
                                                  ),
                                                if (data['credibility'] != null && data['credibility']['status'] == 'verified')
                                                  const Padding(
                                                    padding: EdgeInsets.only(right: 8),
                                                    child: Icon(Icons.verified, color: Colors.green, size: 16),
                                                  ),
                                                _Badge(label: localizedUrgency, color: _urgencyColor(urgency), icon: Icons.circle, iconSize: 8),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(data['description'] ?? '', style: theme.textTheme.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                                            if (data['aiSummary'] != null) ...[ const SizedBox(height: 10), AiSummaryCard(aiSummary: data['aiSummary'], compact: true) ],
                                            const SizedBox(height: 10),
                                            Row(
                                              children: [
                                                Icon(Icons.near_me_outlined, size: 14, color: theme.textTheme.bodyMedium?.color),
                                                const SizedBox(width: 4),
                                                Text(_distanceLabel(data['lat'], data['lng']), style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12)),
                                                const SizedBox(width: 12),
                                                Icon(Icons.access_time_rounded, size: 14, color: theme.textTheme.bodyMedium?.color),
                                                const SizedBox(width: 4),
                                                Text(_timeAgo(data['timestamp'] as Timestamp?), style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12)),
                                                const Spacer(),
                                                _Badge(label: localizedStatus, color: _statusColor(status), icon: _statusIcon(status), iconSize: 12),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                    childCount: displayDocs.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        );
      },
    );
  }
}

class _ReportDetailSheet extends StatelessWidget {
  const _ReportDetailSheet({required this.data, required this.docId, required this.userProfile, required this.distanceLabel, required this.urgencyColor, required this.statusColor, required this.statusIcon, required this.issueIcon, required this.timeAgo, required this.l10n});
  final Map<String, dynamic> data;
  final String docId;
  final Map<String, dynamic>? userProfile;
  final String distanceLabel;
  final Color urgencyColor;
  final Color statusColor;
  final IconData statusIcon;
  final IconData issueIcon;
  final String timeAgo;
  final AppLocalizations l10n;

  bool get _isVolunteer => userProfile?['isVolunteer'] == true;
  String get _status => data['status'] ?? 'unassigned';

  Future<void> _acceptTask(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('reports').doc(docId).update({ 'assignedVolunteers': FieldValue.arrayUnion([uid]), 'status': 'assigned' });
      if (context.mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.task_accepted_success), backgroundColor: Colors.green)); }
    } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aiSummary = data['aiSummary'] as Map<String, dynamic>?;

    String localizedStatus = _status;
    if (_status == 'unassigned') {
      localizedStatus = l10n.unassigned;
    } else if (_status == 'assigned') localizedStatus = l10n.assigned;
    else if (_status == 'completed') localizedStatus = l10n.completed;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(color: theme.cardTheme.color ?? theme.scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          children: [
            Container(margin: const EdgeInsets.only(top: 12, bottom: 8), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.4), borderRadius: BorderRadius.circular(2))),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Row(
                    children: [
                      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(issueIcon, color: theme.colorScheme.primary, size: 24)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(data['issueType'] ?? 'Other', style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.bold)), Text(timeAgo, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12))])),
                      _Badge(label: data['urgency'] ?? 'Low', color: urgencyColor, icon: Icons.circle, iconSize: 8),
                    ],
                  ),
                  if (data['isLifeThreatening'] == true) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "IMMEDIATE LIFE-THREATENING EMERGENCY",
                                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                if (data['lifeThreateningScenarios'] != null && (data['lifeThreateningScenarios'] as List).isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    "Scenarios: ${(data['lifeThreateningScenarios'] as List).join(', ')}",
                                    style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (data['verificationScore'] != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.verified_user_outlined, color: theme.colorScheme.primary, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            "Verification Score:",
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const Spacer(),
                          Text(
                            "${data['verificationScore']}%",
                            style: TextStyle(
                              color: (data['verificationScore'] as int) >= 75
                                  ? Colors.green
                                  : ((data['verificationScore'] as int) >= 50 ? Colors.amber : Colors.red),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 60,
                            child: LinearProgressIndicator(
                              value: (data['verificationScore'] as int) / 100,
                              backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.3),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                (data['verificationScore'] as int) >= 75
                                    ? Colors.green
                                    : ((data['verificationScore'] as int) >= 50 ? Colors.amber : Colors.red),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(children: [Icon(statusIcon, size: 14, color: statusColor), const SizedBox(width: 6), Text(localizedStatus, style: TextStyle(color: statusColor, fontSize: 13, fontWeight: FontWeight.w600)), const SizedBox(width: 12), Icon(Icons.near_me_outlined, size: 14, color: theme.textTheme.bodyMedium?.color), const SizedBox(width: 4), Text(distanceLabel, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13))]),
                  const SizedBox(height: 20),
                  _DetailSection(title: l10n.description, child: Text(data['description'] ?? '', style: theme.textTheme.bodyMedium?.copyWith(height: 1.5))),
                  if ((data['peopleAffected'] != null && data['peopleAffected'] != 'Unknown') || (data['immediateNeeds'] != null && (data['immediateNeeds'] as List).isNotEmpty)) ...[
                    const SizedBox(height: 20),
                    _DetailSection(
                      title: "Impact & Urgent Needs",
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (data['peopleAffected'] != null && data['peopleAffected'] != 'Unknown') ...[
                            Row(
                              children: [
                                Icon(Icons.people_outline, size: 16, color: theme.textTheme.bodyMedium?.color),
                                const SizedBox(width: 8),
                                Text(
                                  "Estimated People Affected: ",
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  data['peopleAffected'] as String,
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            if (data['immediateNeeds'] != null && (data['immediateNeeds'] as List).isNotEmpty) const SizedBox(height: 10),
                          ],
                          if (data['immediateNeeds'] != null && (data['immediateNeeds'] as List).isNotEmpty) ...[
                            Text(
                              "Immediate Needs:",
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500, fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: (data['immediateNeeds'] as List).map((need) {
                                return Chip(
                                  label: Text(need.toString(), style: const TextStyle(fontSize: 12)),
                                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.08),
                                  side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (data['allowContact'] == true && data['contactPhone'] != null && (data['contactPhone'] as String).isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _DetailSection(
                      title: "Contact Information",
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.phone_outlined, size: 16, color: theme.textTheme.bodyMedium?.color),
                              const SizedBox(width: 8),
                              Text(
                                "Phone: ",
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                              ),
                              Text(
                                data['contactPhone'] as String,
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              if (_isVolunteer) ...[
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.call, color: Colors.green, size: 20),
                                  onPressed: () async {
                                    final uri = Uri.parse('tel:${data['contactPhone']}');
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri);
                                    }
                                  },
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                ),
                              ],
                            ],
                          ),
                          if (data['contactAltPhone'] != null && (data['contactAltPhone'] as String).isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.phone_android_outlined, size: 16, color: theme.textTheme.bodyMedium?.color),
                                const SizedBox(width: 8),
                                Text(
                                  "Alternative: ",
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  data['contactAltPhone'] as String,
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                if (_isVolunteer) ...[
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.call, color: Colors.green, size: 20),
                                    onPressed: () async {
                                      final uri = Uri.parse('tel:${data['contactAltPhone']}');
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(uri);
                                      }
                                    },
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _DetailSection(title: l10n.location, child: _buildLocationSection(context, theme, l10n)),
                  const SizedBox(height: 20),
                  if (aiSummary != null) ...[ _DetailSection(title: l10n.ai_analysis, child: AiSummaryCard(aiSummary: aiSummary)), const SizedBox(height: 20) ],
                  _DetailSection(title: 'Report ID', child: Text(docId, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12, fontFamily: 'monospace'))),
                  const SizedBox(height: 28),
                  _buildActionButton(context, theme, l10n),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection(BuildContext context, ThemeData theme, AppLocalizations l10n) {
    final lat = data['lat'] as double?;
    final lng = data['lng'] as double?;
    if (lat == null || lng == null) return Text('No location data', style: theme.textTheme.bodyMedium);

    final isDark = theme.brightness == Brightness.dark;
    final point = LatLng(lat, lng);
    final landmark = data['landmark'] as String?;
    final accuracy = data['gpsAccuracy'] as num?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.near_me_outlined, size: 14, color: theme.textTheme.bodyMedium?.color),
            const SizedBox(width: 6),
            Text(distanceLabel, style: theme.textTheme.bodyMedium),
            if (accuracy != null) ...[
              const SizedBox(width: 12),
              Icon(Icons.gps_fixed, size: 13, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              Text("±${accuracy.toStringAsFixed(1)}m", style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7))),
            ],
          ],
        ),
        if (landmark != null && landmark.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.pin_drop_outlined, size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Landmark: $landmark",
                  style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 180,
            width: double.infinity,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: point,
                initialZoom: 14.0,
                maxZoom: 18,
                minZoom: 3,
                interactionOptions: const InteractionOptions(
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
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 36,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(l10n.open_in_google_maps),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, ThemeData theme, AppLocalizations l10n) {
    if (!_isVolunteer) return Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2))), child: Row(children: [Icon(Icons.lock_outline, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 10), Expanded(child: Text(l10n.only_verified_volunteers, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13)))]));
    if (_status == 'completed') return Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF22C55E).withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.3))), child: Row(children: [const Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF22C55E)), const SizedBox(width: 10), Text(l10n.task_completed_desc, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13))]));
    
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final assigned = List<String>.from(data['assignedVolunteers'] ?? []);
    if (assigned.contains(uid)) return SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () { Navigator.pop(context); Navigator.pushNamed(context, '/volunteer', arguments: docId); }, icon: const Icon(Icons.volunteer_activism_outlined), label: Text(l10n.go_to_my_tasks), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E), foregroundColor: Colors.white, padding: const EdgeInsets.all(14.0))));
    return SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () => _acceptTask(context), icon: const Icon(Icons.handshake_outlined), label: Text(l10n.accept_task), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14))));
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, required this.icon, required this.iconSize});
  final String label;
  final Color color;
  final IconData icon;
  final double iconSize;
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.4))), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: iconSize, color: color), const SizedBox(width: 5), Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600))]));
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.count, required this.color, required this.isSelected, required this.onTap});
  final String label;
  final int count;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Expanded(child: GestureDetector(onTap: onTap, child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: isSelected ? color : color.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: isSelected ? color : color.withOpacity(0.3), width: isSelected ? 2 : 1)), child: Column(children: [Text('$count', style: TextStyle(color: isSelected ? Colors.white : color, fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 2), Text(label, style: TextStyle(color: isSelected ? Colors.white : color, fontSize: 11, fontWeight: FontWeight.w500))]))));
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: theme.colorScheme.primary)), const SizedBox(height: 6), child]);
  }
}
