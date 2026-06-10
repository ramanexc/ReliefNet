import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:reliefnet/services/gemini_service.dart';
import 'package:reliefnet/widgets/ai_summary_card.dart';
import 'package:reliefnet/l10n/app_localizations.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with AutomaticKeepAliveClientMixin {
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
    switch (type) {
      case 'Food': return Icons.restaurant_outlined;
      case 'Medical': return Icons.local_hospital_outlined;
      case 'Shelter': return Icons.home_outlined;
      default: return Icons.help_outline;
    }
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
                        if (_fetchingLocation) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        else if (_userPosition != null) Icon(Icons.location_on, size: 16, color: theme.colorScheme.primary)
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
                      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(issueIcon, color: theme.colorScheme.primary, size: 24)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(data['issueType'] ?? 'Other', style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.bold)), Text(timeAgo, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12))])),
                      _Badge(label: data['urgency'] ?? 'Low', color: urgencyColor, icon: Icons.circle, iconSize: 8),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(children: [Icon(statusIcon, size: 14, color: statusColor), const SizedBox(width: 6), Text(localizedStatus, style: TextStyle(color: statusColor, fontSize: 13, fontWeight: FontWeight.w600)), const SizedBox(width: 12), Icon(Icons.near_me_outlined, size: 14, color: theme.textTheme.bodyMedium?.color), const SizedBox(width: 4), Text(distanceLabel, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13))]),
                  const SizedBox(height: 20),
                  _DetailSection(title: l10n.description, child: Text(data['description'] ?? '', style: theme.textTheme.bodyMedium?.copyWith(height: 1.5))),
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

    final uid = FirebaseAuth.instance.currentUser?.uid;
    final assigned = List<String>.from(data['assignedVolunteers'] ?? []);
    final alreadyAccepted = assigned.contains(uid);

    if (alreadyAccepted || _status == 'completed') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(Icons.near_me_outlined, size: 14, color: theme.textTheme.bodyMedium?.color), const SizedBox(width: 6), Text(distanceLabel, style: theme.textTheme.bodyMedium)]),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () async { final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'); if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication); }, icon: const Icon(Icons.open_in_new, size: 16), label: Text(l10n.open_in_google_maps))),
        ],
      );
    }
    return Row(children: [Icon(Icons.lock_outline, size: 14, color: theme.colorScheme.primary.withOpacity(0.6)), const SizedBox(width: 8), Expanded(child: Text('$distanceLabel · Accept task to view map', style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13)))]);
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
