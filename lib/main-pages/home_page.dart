import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:reliefnet/main-pages/dashboard_page.dart';
import 'package:reliefnet/main-pages/nearby_hospitals_page.dart';
import 'package:reliefnet/secondary-pages/profile_page.dart';
import 'package:reliefnet/main-pages/report_page.dart';
import 'package:reliefnet/secondary-pages/settings_page.dart';
import 'package:reliefnet/main-pages/volunteer_page.dart';
import 'package:reliefnet/main-pages/apply_volunteer_page.dart';
import 'package:reliefnet/main-pages/heatmap_page.dart';
import 'package:reliefnet/components/app_bar.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:reliefnet/l10n/app_localizations.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  int selectedindex = 0;
  bool _isVolunteer = false;

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomeContent(
        isVolunteer: _isVolunteer,
        onNavigateToReport: () => setState(() => selectedindex = 1),
        onNavigateToHospitals: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NearbyHospitalsPage()),
          );
        },
        onNavigateToApply: () => setState(() => selectedindex = 4),
        onNavigateToVolunteer: () => setState(() => selectedindex = 3),
      ),
      const ReportPage(),
      const DashboardPage(),
      const VolunteerPage(),
      const ApplyVolunteerPage(),
      const ProfilePage(),
      const SettingsPage(),
      const HeatMapPage(),
    ];
    _checkVolunteerStatus();
  }

  Future<void> _checkVolunteerStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((doc) {
        if (doc.exists && mounted) {
          setState(() {
            _isVolunteer = doc.data()?['isVolunteer'] ?? false;
            _pages[0] = HomeContent(
              isVolunteer: _isVolunteer,
              onNavigateToReport: () => setState(() => selectedindex = 1),
              onNavigateToHospitals: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NearbyHospitalsPage()),
                );
              },
              onNavigateToApply: () => setState(() => selectedindex = 4),
              onNavigateToVolunteer: () => setState(() => selectedindex = 3),
            );
          });
        }
      });
    }
  }

  void _navigate(int index) {
    setState(() => selectedindex = index);
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;

    final List<String> pageTitles = [
      l10n.app_title,
      l10n.report_issue,
      l10n.dashboard,
      l10n.my_tasks,
      l10n.application_status,
      l10n.profile,
      l10n.settings,
      "Crisis Heat Map",
    ];

    return Scaffold(
      appBar: AppBarComponent(appBarText: pageTitles[selectedindex]),
      body: IndexedStack(
        index: selectedindex,
        children: _pages,
      ),
      drawer: Drawer(
        width: 240,
        child: Column(
          children: [
            DrawerHeader(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset("assets/images/logo.png", height: 80),
                  const SizedBox(height: 10),
                  Text(l10n.app_title, style: textTheme.bodyLarge),
                ],
              ),
            ),
            _buildTile(Icons.home_outlined, l10n.home, 0, textTheme),
            _buildTile(Icons.report_outlined, l10n.report, 1, textTheme),
            _buildTile(Icons.map_outlined, "Crisis Heat Map", 7, textTheme),
            if (_isVolunteer) ...[
              _buildTile(Icons.dashboard_outlined, l10n.dashboard, 2, textTheme),
              _buildTile(Icons.help_outline, l10n.volunteer, 3, textTheme),
            ] else
              ListTile(
                leading: const Icon(Icons.volunteer_activism_outlined),
                title: Text(l10n.apply_as_volunteer, style: textTheme.bodyMedium),
                selected: selectedindex == 4,
                onTap: () => _navigate(4),
              ),
            _buildTile(Icons.person_outline, l10n.profile, 5, textTheme),
            _buildTile(Icons.settings_outlined, l10n.settings, 6, textTheme),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text(
                l10n.logout,
                style: textTheme.bodyMedium?.copyWith(color: Colors.red),
              ),
              onTap: () => _showLogoutDialog(context, textTheme, l10n),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(IconData icon, String title, int index, TextTheme textTheme) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: textTheme.bodyMedium),
      selected: selectedindex == index,
      onTap: () => _navigate(index),
    );
  }

  void _showLogoutDialog(BuildContext context, TextTheme textTheme, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.logout, style: textTheme.bodyLarge),
        content: Text(l10n.logout_confirm, style: textTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel, style: textTheme.bodySmall),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();
              await GoogleSignIn().signOut();
            },
            child: Text(
              l10n.logout,
              style: textTheme.bodyMedium?.copyWith(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeContent extends StatelessWidget {
  final bool isVolunteer;
  final VoidCallback onNavigateToReport;
  final VoidCallback onNavigateToApply;
  final VoidCallback onNavigateToVolunteer;
  final VoidCallback onNavigateToHospitals;

  const HomeContent({
    super.key,
    required this.isVolunteer,
    required this.onNavigateToReport,
    required this.onNavigateToApply,
    required this.onNavigateToVolunteer,
    required this.onNavigateToHospitals,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    Future<void> makeCall(String number) async {
      final Uri uri = Uri(scheme: 'tel', path: number);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${l10n.hello}, ${user?.displayName?.split(' ').first ?? 'there'} 👋",
            style: textTheme.bodyLarge,
          ),
          Text(
            isVolunteer ? l10n.active_volunteer : l10n.how_can_we_help,
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onNavigateToReport,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade400, Colors.red.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.shade300.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.report_problem_rounded, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.report_issue,
                          style: textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          l10n.need_help_desc,
                          style: textTheme.bodySmall?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: l10n.quick_emergency_actions, icon: Icons.bolt_rounded),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _EmergencyActionBtn(
                icon: Icons.local_hospital_outlined,
                label: l10n.hospitals,
                color: Colors.green,
                onTap: onNavigateToHospitals,
              ),
              _EmergencyActionBtn(
                icon: Icons.local_police_outlined,
                label: l10n.police,
                color: Colors.blue,
                onTap: () => makeCall('100'),
              ),
              _EmergencyActionBtn(
                icon: Icons.medical_services_outlined,
                label: l10n.ambulance,
                color: Colors.red,
                onTap: () => makeCall('102'),
              ),
              _EmergencyActionBtn(
                icon: Icons.local_fire_department_outlined,
                label: l10n.fire_brigade,
                color: Colors.orange,
                onTap: () => makeCall('101'),
              ),
              _EmergencyActionBtn(
                icon: Icons.sos_rounded,
                label: l10n.sos,
                color: Colors.red.shade900,
                onTap: () => makeCall('112'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: l10n.safety_preparedness, icon: Icons.security_rounded),
          const SizedBox(height: 12),
          SizedBox(
            height: 130,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: const [
                _SafetyTipCard(
                  title: "Earthquake Safety",
                  desc: "Drop, Cover, and Hold On! Stay away from glass.",
                  icon: Icons.terrain_rounded,
                  color: Colors.brown,
                ),
                _SafetyTipCard(
                  title: "First Aid Basics",
                  desc: "Keep a kit ready with bandages, antiseptic, and meds.",
                  icon: Icons.health_and_safety_rounded,
                  color: Colors.teal,
                ),
                _SafetyTipCard(
                  title: "Fire Emergency",
                  desc: "Crawl low under smoke and use stairs, not elevators.",
                  icon: Icons.fireplace_rounded,
                  color: Colors.deepOrange,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (!isVolunteer)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.blue.withValues(alpha: 0.12) : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.blue.shade700 : Colors.blue.shade200,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Icon(Icons.volunteer_activism, color: Colors.blue.shade700),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.make_a_difference, style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        Text(l10n.join_volunteer_desc, style: textTheme.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: onNavigateToApply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(l10n.apply),
                  ),
                ],
              ),
            ),
          if (!isVolunteer) const SizedBox(height: 24),
          _ImpactSummaryCard(isDark: isDark, l10n: l10n),
          const SizedBox(height: 24),
          _SectionHeader(title: l10n.active_reports, icon: Icons.list_alt_rounded),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('reports')
                .where('submittedBy', isEqualTo: user?.uid)
                .where('status', isNotEqualTo: 'completed')
                .orderBy('status')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _EmptyState(
                  icon: Icons.inbox_rounded,
                  message: l10n.no_active_reports,
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final issue = doc['issueType'] ?? 'Unknown';
                  final status = doc['status'] ?? '';
                  return _ActiveReportCard(issue: issue, status: status, l10n: l10n);
                },
              );
            },
          ),
          const SizedBox(height: 24),
          if (isVolunteer) ...[
            _SectionHeader(title: l10n.pending_tasks, icon: Icons.assignment_turned_in_outlined),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reports')
                  .where('assignedVolunteers', arrayContains: user?.uid)
                  .where('status', whereIn: ['assigned', 'in_progress', 'reached'])
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _EmptyState(
                    icon: Icons.check_circle_outline_rounded,
                    message: l10n.no_pending_tasks,
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final issue = doc['issueType'] ?? 'Task';
                    final urgency = doc['urgency'] ?? 'Normal';
                    final status = doc['status'] ?? 'assigned';
                    return _PendingTaskCard(
                      issue: issue,
                      urgency: urgency,
                      status: status,
                      onTap: onNavigateToVolunteer,
                    );
                  },
                );
              },
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ActiveReportCard extends StatelessWidget {
  final String issue;
  final String status;
  final AppLocalizations l10n;
  const _ActiveReportCard({required this.issue, required this.status, required this.l10n});

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'food': return Icons.fastfood_rounded;
      case 'medical': return Icons.medical_services_rounded;
      case 'shelter': return Icons.house_rounded;
      case 'fire': return Icons.local_fire_department_rounded;
      case 'water': return Icons.water_drop_rounded;
      default: return Icons.help_center_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type.toLowerCase()) {
      case 'food': return Colors.orange;
      case 'medical': return Colors.red;
      case 'shelter': return Colors.indigo;
      case 'fire': return Colors.deepOrange;
      case 'water': return Colors.blue;
      default: return Colors.blueGrey;
    }
  }

  Color _colorForStatus(String s) {
    switch (s) {
      case 'assigned': return Colors.blue.shade600;
      case 'in_progress': return Colors.orange.shade600;
      case 'reached': return Colors.purple.shade600;
      default: return Colors.grey.shade500;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForType(issue);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_iconForType(issue), color: color, size: 22),
        ),
        title: Text(issue, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          "${l10n.status}: ${status.replaceAll('_', ' ')}",
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _colorForStatus(status),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            status.replaceAll('_', ' ').toUpperCase(),
            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class _EmergencyActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _EmergencyActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _SafetyTipCard extends StatelessWidget {
  final String title;
  final String desc;
  final IconData icon;
  final Color color;

  const _SafetyTipCard({
    required this.title,
    required this.desc,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            desc,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ImpactSummaryCard extends StatelessWidget {
  final bool isDark;
  final AppLocalizations l10n;
  const _ImpactSummaryCard({required this.isDark, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
            ? [Colors.blueGrey.shade800, Colors.blueGrey.shade900]
            : [Colors.indigo.shade50, Colors.indigo.shade100],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            l10n.community_impact,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ImpactStat(label: l10n.resolved, value: "1.2k", color: Colors.green),
              _ImpactStat(label: l10n.volunteers, value: "450+", color: Colors.blue),
              _ImpactStat(label: l10n.active, value: "84", color: Colors.orange),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImpactStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _ImpactStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

class _PendingTaskCard extends StatelessWidget {
  final String issue;
  final String urgency;
  final String status;
  final VoidCallback onTap;

  const _PendingTaskCard({
    required this.issue,
    required this.urgency,
    required this.status,
    required this.onTap,
  });

  Color _urgencyColor(String u) {
    switch (u.toLowerCase()) {
      case 'high':
        return const Color(0xFFEF4444);
      case 'medium':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF10B981);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uColor = _urgencyColor(urgency);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [uColor.withValues(alpha: 0.2), uColor.withValues(alpha: 0.05)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.assignment_late_rounded, color: uColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              issue,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          _UrgencyBadge(label: urgency, color: uColor),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.radio_button_checked_rounded,
                            size: 14,
                            color: isDark ? Colors.blue.shade400 : Colors.blue.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            status.replaceAll('_', ' ').toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.blue.shade400 : Colors.blue.shade600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.grey.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UrgencyBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _UrgencyBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
