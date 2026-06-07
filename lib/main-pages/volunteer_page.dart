import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'task_detail_page.dart';
import 'package:reliefnet/l10n/app_localizations.dart';

class VolunteerPage extends StatelessWidget {
  const VolunteerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final l10n = AppLocalizations.of(context)!;
    if (user == null) {
      return Center(child: Text(l10n.please_login));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
          elevation: 0,
          centerTitle: true,
          title: PreferredSize(
            preferredSize: const Size.fromHeight(70),
            child: Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withOpacity(0.2) : colorScheme.surface.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: isDark ? const Color(0xFF334155) : colorScheme.surface,
                    boxShadow: [ if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)) ],
                  ),
                  labelColor: isDark ? Colors.white : colorScheme.onSurface,
                  unselectedLabelColor: Theme.of(context).textTheme.bodySmall?.color,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  tabs: [
                    Tab(text: l10n.active),
                    Tab(text: l10n.completed),
                    Tab(text: l10n.rejected),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('reports')
              .where('assignedVolunteers', arrayContains: user.uid)
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(16), child: SelectableText("Error: ${snapshot.error}")));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

            final docs = snapshot.data!.docs;
            final activeTasks = docs.where((d) {
              final s = (d.data() as Map<String, dynamic>)['status'] as String?;
              return s == 'assigned' || s == 'in_progress' || s == 'reached';
            }).toList();
            final completedTasks = docs.where((d) => d['status'] == 'completed').toList();
            final rejectedTasks = docs.where((d) => d['status'] == 'rejected').toList();

            return TabBarView(
              children: [
                _TaskGrid(tasks: activeTasks, emptyMessage: l10n.no_active_tasks, emptyIcon: Icons.assignment_outlined, l10n: l10n),
                _TaskGrid(tasks: completedTasks, emptyMessage: l10n.no_completed_tasks, emptyIcon: Icons.check_circle_outline, l10n: l10n),
                _TaskGrid(tasks: rejectedTasks, emptyMessage: l10n.no_rejected_tasks, emptyIcon: Icons.cancel_outlined, l10n: l10n),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TaskGrid extends StatelessWidget {
  final List<QueryDocumentSnapshot> tasks;
  final String emptyMessage;
  final IconData emptyIcon;
  final AppLocalizations l10n;

  const _TaskGrid({required this.tasks, required this.emptyMessage, required this.emptyIcon, required this.l10n});

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 72, color: Theme.of(context).textTheme.bodySmall?.color),
            const SizedBox(height: 16),
            Text(emptyMessage, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      itemCount: tasks.length,
      itemBuilder: (context, i) => _TaskCard(doc: tasks[i], l10n: l10n),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final AppLocalizations l10n;
  const _TaskCard({required this.doc, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final issue = data['issueType'] ?? 'Unknown';
    final description = data['description'] ?? '';
    final status = data['status'] ?? 'assigned';
    final timestamp = data['timestamp'] as Timestamp?;
    String address = '';

    if (data['address'] != null && data['address'] is String) {
      address = data['address'];
    } else if (data['location'] != null) {
      final loc = data['location'];
      if (loc is GeoPoint) {
        address = "Lat: ${loc.latitude.toStringAsFixed(4)}, Lng: ${loc.longitude.toStringAsFixed(4)}";
      } else if (loc is String) address = loc;
    }

    final color = _issueColor(issue);
    final icon = _issueIcon(issue);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    final statusMap = {
      'assigned': (const Color(0xFF3B82F6), l10n.assigned, Icons.assignment_ind_rounded),
      'in_progress': (const Color(0xFFF59E0B), l10n.en_route, Icons.directions_run_rounded),
      'reached': (const Color(0xFF8B5CF6), l10n.on_site, Icons.location_on_rounded),
      'completed': (const Color(0xFF10B981), l10n.completed, Icons.check_circle_rounded),
      'rejected': (const Color(0xFFEF4444), l10n.declined, Icons.cancel_rounded),
    };
    final statusEntry = statusMap[status] ?? (Colors.grey.shade600, 'Unknown', Icons.help_outline_rounded);

    String localizedIssue = issue;
    if (issue == 'Food') {
      localizedIssue = l10n.food;
    } else if (issue == 'Medical') localizedIssue = l10n.medical;
    else if (issue == 'Shelter') localizedIssue = l10n.shelter;
    else if (issue == 'Other') localizedIssue = l10n.other;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [ BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 15, offset: const Offset(0, 5)) ],
        border: Border.all(color: colorScheme.outline.withOpacity(isDark ? 0.05 : 0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailPage(docId: doc.id))),
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 24)),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(localizedIssue, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface, letterSpacing: -0.5)), if (timestamp != null) Text(_formatDate(timestamp.toDate(), l10n), style: Theme.of(context).textTheme.bodySmall)])),
                    _StatusBadge(label: statusEntry.$2, color: statusEntry.$1, icon: statusEntry.$3),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 1, color: colorScheme.outline.withOpacity(0.05)),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (description.isNotEmpty) ...[ Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium), const SizedBox(height: 16) ],
                    if (address.isNotEmpty) Row(children: [Icon(Icons.map_rounded, size: 16, color: isDark ? Colors.blue.shade400 : Colors.blue.shade600), const SizedBox(width: 8), Expanded(child: Text(address, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colorScheme.onSurface)))]),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: isDark ? Colors.black.withOpacity(0.1) : colorScheme.surfaceContainerHighest.withOpacity(0.3) ?? colorScheme.surface, borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("${l10n.task_id}: ${doc.id.substring(0, 8).toUpperCase()}", style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1, fontSize: 11)),
                    Row(children: [Text(l10n.details, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)), const SizedBox(width: 4), Icon(Icons.arrow_forward_rounded, size: 14, color: color)]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date, AppLocalizations l10n) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return l10n.today;
    if (diff.inDays == 1) return l10n.yesterday;
    return "${date.day}/${date.month}/${date.year}";
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _StatusBadge({required this.label, required this.color, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(30), border: Border.all(color: color.withOpacity(0.2))), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 12, color: color), const SizedBox(width: 6), Text(label.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5))]));
  }
}

Color _issueColor(String type) {
  switch (type.toLowerCase()) {
    case 'medical': return Colors.red.shade600;
    case 'food': return Colors.orange.shade700;
    case 'shelter': return Colors.indigo.shade600;
    case 'fire': return Colors.deepOrange.shade600;
    case 'water': return Colors.blue.shade600;
    default: return Colors.blueGrey.shade600;
  }
}

IconData _issueIcon(String type) {
  switch (type.toLowerCase()) {
    case 'medical': return Icons.medical_services;
    case 'food': return Icons.fastfood;
    case 'shelter': return Icons.house;
    case 'fire': return Icons.local_fire_department;
    case 'water': return Icons.water_drop;
    default: return Icons.report_problem;
  }
}
