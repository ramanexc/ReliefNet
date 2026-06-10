import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:reliefnet/themes/theme_provider.dart';
import 'package:reliefnet/themes/locale_provider.dart';
import 'package:reliefnet/l10n/app_localizations.dart';
import 'package:reliefnet/onboarding/onboarding_screen.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with SingleTickerProviderStateMixin {
  // ── Notification prefs (Firestore) ────────────────────────────────────────
  bool _notifyNewReports = true;
  bool _notifyTaskAssigned = true;
  bool _notifyTaskCompleted = true;
  bool _notifyUrgentOnly = false;

  // ── State ─────────────────────────────────────────────────────────────────
  bool _isLoading = true;
  final bool _savingNotifs = false;
  String _appVersion = '';

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadAll();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Loaders ───────────────────────────────────────────────────────────────

  Future<void> _loadAll() async {
    await Future.wait([_loadNotifPrefs(), _loadAppVersion()]);
    if (mounted) {
      setState(() => _isLoading = false);
      _fadeCtrl.forward();
    }
  }

  Future<void> _loadNotifPrefs() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists) {
        final prefs = doc.data()?['notificationPrefs'] as Map<String, dynamic>?;
        if (prefs != null && mounted) {
          setState(() {
            _notifyNewReports = prefs['newReports'] ?? true;
            _notifyTaskAssigned = prefs['taskAssigned'] ?? true;
            _notifyTaskCompleted = prefs['taskCompleted'] ?? true;
            _notifyUrgentOnly = prefs['urgentOnly'] ?? false;
          });
        }
      }
    } catch (e) {
      debugPrint('loadNotifPrefs error: $e');
    }
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _appVersion = info.version);
    } catch (_) {
      if (mounted) setState(() => _appVersion = '1.0.0');
    }
  }

  // ── Savers ────────────────────────────────────────────────────────────────

  Future<void> _saveNotifPref(String key, bool value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'notificationPrefs': {
          'newReports': _notifyNewReports,
          'taskAssigned': _notifyTaskAssigned,
          'taskCompleted': _notifyTaskCompleted,
          'urgentOnly': _notifyUrgentOnly,
        },
      }, SetOptions(merge: true));
    } catch (e) {
      _snack('Failed to save: $e');
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _makeCall(String number) async {
    final Uri uri = Uri(scheme: 'tel', path: number);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _snack('Could not launch dialer for $number');
      }
    } catch (e) {
      _snack('Error: $e');
    }
  }

  Future<void> _openFeedbackEmail() async {
    final Uri uri = Uri(
      scheme: 'mailto',
      path: 'support@reliefnet.app',
      query:
          'subject=ReliefNet%20Feedback&body=App%20version%3A%20$_appVersion',
    );

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      _snack('No email app found. Contact support@reliefnet.app');
    }
  }

  Future<void> _clearCache() async {
    final confirm = await _confirmDialog(
      title: 'Clear Cache',
      message:
          'This will clear locally cached data. Your account and reports are safe.',
      action: 'Clear',
    );
    if (confirm != true) return;
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString('theme');
    final language = prefs.getString('language_code');
    await prefs.clear();
    if (theme != null) await prefs.setString('theme', theme);
    if (language != null) await prefs.setString('language_code', language);
    _snack('Cache cleared');
  }

  Future<void> _showPrivacyPolicy() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PrivacyPolicySheet(),
    );
  }

  void _showProjectDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ProjectDetailsSheet(),
    );
  }

  Future<void> _showDeleteAccountDialog() async {
    final confirm = await _confirmDialog(
      title: 'Delete Account',
      message:
          'This will permanently delete your account and all associated data. This cannot be undone.',
      action: 'Delete',
      isDanger: true,
    );
    if (confirm != true || !mounted) return;
    _snack('Contact support@reliefnet.app to complete account deletion');
  }

  Future<bool?> _confirmDialog({
    required String title,
    required String message,
    required String action,
    bool isDanger = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              action,
              style: TextStyle(
                color: isDanger
                    ? Colors.red
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final l10n = AppLocalizations.of(context)!;
    final themeProvider = context.watch<ThemeProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    final isDark = themeProvider.isDarkMode;
    final onThemeToggle = themeProvider.toggleTheme;

    String currentLangName = 'English';
    if (localeProvider.locale.languageCode == 'hi') currentLangName = 'हिन्दी';
    if (localeProvider.locale.languageCode == 'pa') currentLangName = 'ਪੰਜਾਬੀ';

    return FadeTransition(
      opacity: _fadeAnim,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          // ── Emergency Hotlines ──────────────────────────────────────────
          _SectionLabel(label: l10n.emergency_hotlines),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              _TapTile(
                icon: Icons.local_police_outlined,
                iconColor: Colors.blue.shade800,
                label: l10n.police,
                subtitle: '100',
                onTap: () => _makeCall('100'),
              ),
              _TapTile(
                icon: Icons.medical_services_outlined,
                iconColor: Colors.red.shade700,
                label: l10n.ambulance,
                subtitle: '102',
                onTap: () => _makeCall('102'),
              ),
              _TapTile(
                icon: Icons.local_fire_department_outlined,
                iconColor: Colors.orange.shade800,
                label: l10n.fire_brigade,
                subtitle: '101',
                onTap: () => _makeCall('101'),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Appearance ─────────────────────────────────────────────────
          _SectionLabel(label: l10n.appearance),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              _SwitchTile(
                icon: isDark
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined,
                iconColor: const Color(0xFF6366F1),
                label: l10n.dark_mode,
                subtitle: isDark ? 'Currently dark' : 'Currently light',
                value: isDark,
                onChanged: (_) => onThemeToggle(),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Notifications ───────────────────────────────────────────────
          _SectionLabel(label: l10n.notifications),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              _SwitchTile(
                icon: Icons.fiber_new_outlined,
                iconColor: const Color(0xFF22C55E),
                label: l10n.new_reports,
                subtitle: 'Alert when a new report\nis filed',
                value: _notifyNewReports,
                loading: _savingNotifs,
                onChanged: (v) {
                  setState(() => _notifyNewReports = v);
                  _saveNotifPref('newReports', v);
                },
              ),
              _SwitchTile(
                icon: Icons.handshake_outlined,
                iconColor: const Color(0xFFF59E0B),
                label: l10n.task_assigned,
                subtitle: 'Alert when a task is\nassigned to you',
                value: _notifyTaskAssigned,
                loading: _savingNotifs,
                onChanged: (v) {
                  setState(() => _notifyTaskAssigned = v);
                  _saveNotifPref('taskAssigned', v);
                },
              ),
              _SwitchTile(
                icon: Icons.check_circle_outline,
                iconColor: const Color(0xFF22C55E),
                label: l10n.task_completed,
                subtitle: 'Alert when a task you\nfiled is resolved',
                value: _notifyTaskCompleted,
                loading: _savingNotifs,
                onChanged: (v) {
                  setState(() => _notifyTaskCompleted = v);
                  _saveNotifPref('taskCompleted', v);
                },
              ),
              _SwitchTile(
                icon: Icons.priority_high_rounded,
                iconColor: const Color(0xFFEF4444),
                label: l10n.urgent_only,
                subtitle: 'Only notify for High\nurgency reports',
                value: _notifyUrgentOnly,
                loading: _savingNotifs,
                onChanged: (v) {
                  setState(() => _notifyUrgentOnly = v);
                  _saveNotifPref('urgentOnly', v);
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Language / Region ───────────────────────────────────────────
          _SectionLabel(label: l10n.language_region),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              _TapTile(
                icon: Icons.language_outlined,
                iconColor: const Color(0xFF06B6D4),
                label: l10n.language,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currentLangName,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ],
                ),
                onTap: () => _showLanguagePicker(localeProvider, l10n),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Privacy & Data ──────────────────────────────────────────────
          _SectionLabel(label: l10n.privacy_data),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              _TapTile(
                icon: Icons.policy_outlined,
                iconColor: const Color(0xFF8B5CF6),
                label: l10n.privacy_policy,
                onTap: _showPrivacyPolicy,
              ),
              _TapTile(
                icon: Icons.cleaning_services_outlined,
                iconColor: const Color(0xFF6366F1),
                label: l10n.clear_cache,
                subtitle: 'Free up local storage',
                onTap: _clearCache,
              ),
              _TapTile(
                icon: Icons.delete_forever_outlined,
                iconColor: Colors.red,
                label: l10n.delete_account,
                subtitle: 'Permanently remove your data',
                labelColor: Colors.red,
                onTap: _showDeleteAccountDialog,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Help & Feedback ─────────────────────────────────────────────
          _SectionLabel(label: l10n.help_feedback),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              _TapTile(
                icon: Icons.mail_outline_rounded,
                iconColor: const Color(0xFFF59E0B),
                label: l10n.send_feedback,
                subtitle: 'support@reliefnet.app',
                onTap: _openFeedbackEmail,
              ),
            ],
          ),

          const SizedBox(height: 24),
          // ── About ───────────────────────────────────────────────────────
          _SectionLabel(label: l10n.about),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              _TapTile(
                icon: Icons.info_outline_rounded,
                iconColor: const Color(0xFF06B6D4),
                label: l10n.app_version,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'v$_appVersion',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                onTap: null,
              ),
              _TapTile(
                icon: Icons.favorite_outline_rounded,
                iconColor: Colors.red,
                label: l10n.built_for_gsc,
                onTap: () => _showProjectDetails(context),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // ── Footer ──────────────────────────────────────────────────────
          Center(
            child: Text(
              'ReliefNet v$_appVersion · Made with ❤️ for communities',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguagePicker(LocaleProvider provider, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: BoxDecoration(
            color: theme.cardTheme.color ?? theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.select_language,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _langTile(ctx, provider, 'English', const Locale('en')),
              _langTile(ctx, provider, 'हिन्दी', const Locale('hi')),
              _langTile(ctx, provider, 'ਪੰਜਾਬੀ', const Locale('pa')),
            ],
          ),
        );
      },
    );
  }

  Widget _langTile(
    BuildContext ctx,
    LocaleProvider provider,
    String name,
    Locale locale,
  ) {
    final theme = Theme.of(ctx);
    final isSelected = provider.locale.languageCode == locale.languageCode;
    return ListTile(
      title: Text(name, style: theme.textTheme.bodyMedium),
      trailing: isSelected
          ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
          : null,
      onTap: () {
        provider.setLocale(locale);
        Navigator.pop(ctx);
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}

class _PrivacyPolicySheet extends StatelessWidget {
  const _PrivacyPolicySheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Privacy Policy',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: const [
                  _PolicySection(
                    title: 'Data We Collect',
                    body:
                        'ReliefNet collects your name, username, profile picture, and volunteer ID for account management. '
                        'Location data is collected only when you submit a report, and is stored with the report in Firestore. '
                        'We do not sell your data to third parties.',
                  ),
                  _PolicySection(
                    title: 'How We Use Your Data',
                    body:
                        'Your data is used solely to power ReliefNet features: matching volunteers to reports, '
                        'displaying distances, and maintaining your activity history. '
                        'Notification preferences are synced across devices via Firestore.',
                  ),
                  _PolicySection(
                    title: 'Data Retention',
                    body:
                        'Your account data is retained as long as your account is active. '
                        'You may request deletion at any time via Settings → Delete Account.',
                  ),
                  _PolicySection(
                    title: 'Third-Party Services',
                    body:
                        'ReliefNet uses Firebase (Google) for authentication, database, and storage. '
                        'Google Maps is used for location display. Their respective privacy policies apply.',
                  ),
                  _PolicySection(
                    title: 'Contact',
                    body:
                        'For privacy concerns, contact us at support@reliefnet.app.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectDetailsSheet extends StatelessWidget {
  const _ProjectDetailsSheet();

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "ReliefNet Project",
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "ReliefNet is a mobile app that connects people in need with nearby volunteers, enabling quick and reliable help during emergencies. It streamlines how requests are made and how volunteers respond, making relief efforts faster and more organized.",
            ),

            const SizedBox(height: 24),
            Text(
              "TEAM MEMBERS",
              style: textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.person_outline, "Ramandeep Singh"),
            _buildInfoRow(Icons.person_outline, "Japneet Singh"),
            _buildInfoRow(Icons.person_outline, "Aamandeep Singh"),

            const SizedBox(height: 24),
            Text(
              "PROJECT LINKS",
              style: textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            _buildLinkTile(
              Icons.code,
              "GitHub Repository",
              "https://github.com/ramanexc/reliefnet",
              theme,
            ),
            _buildLinkTile(
              Icons.share,
              "LinkedIn Post",
              "https://linkedin.com/posts/your-post",
              theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildLinkTile(
    IconData icon,
    String label,
    String url,
    ThemeData theme,
  ) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.primary.withValues(alpha: 0.05),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.open_in_new, size: 18),
        onTap: () => _launchURL(url),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.loading = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final bool value;
  final bool loading;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StatefulBuilder(
      builder: (context, setLocalState) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Switch.adaptive(
                      value: value,
                      onChanged: (newValue) {
                        setLocalState(() {});
                        onChanged(newValue);
                      },
                    ),
            ],
          ),
        );
      },
    );
  }
}

class _TapTile extends StatelessWidget {
  const _TapTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.subtitle,
    this.trailing,
    this.labelColor,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final Color? labelColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: labelColor,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
            )
          : null,
      trailing:
          trailing ??
          (onTap != null
              ? Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: theme.textTheme.bodySmall?.color,
                )
              : null),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}
