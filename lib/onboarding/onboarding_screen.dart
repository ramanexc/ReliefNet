import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  String? _selectedRole; // 'reporter', 'volunteer', or 'admin'
  bool _locationGranted = false;

  // App theme colors (matching theme_light.dart)
  static const Color _primary = Color(0xFF3B82F6);
  static const Color _secondary = Color(0xFF6366F1);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMedium = Color(0xFF334155);
  static const Color _textLight = Color(0xFF94A3B8);
  static const Color _bgColor = Color(0xFFF5F7FB);

  static const int _totalPages = 4; // 3 info pages + 1 role page

  final List<Map<String, dynamic>> _pages = [
    {
      'title': 'Report Emergencies',
      'subtitle':
          'Quickly report disasters and emergencies in your area to get help where it\'s needed most.',
      'icon': Icons.campaign_rounded,
    },
    {
      'title': 'Find Nearby Tasks',
      'subtitle':
          'Get matched to relief tasks based on your skills and location.',
      'icon': Icons.location_on_rounded,
    },
    {
      'title': 'Make an Impact',
      'subtitle':
          'Complete tasks, submit proof, and track the difference you make in real time.',
      'icon': Icons.verified_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      HapticFeedback.lightImpact();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);

    // Trigger location permission on page 2
    if (index == 1 && !_locationGranted) {
      _requestLocation();
    }
  }

  Future<void> _requestLocation() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final result = await Geolocator.requestPermission();
      if (result == LocationPermission.whileInUse ||
          result == LocationPermission.always) {
        setState(() => _locationGranted = true);
      }
    } else if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      setState(() => _locationGranted = true);
    }
  }

  Future<void> _completeOnboarding() async {
    if (_selectedRole == null) return;

    HapticFeedback.mediumImpact();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    await prefs.setString('user_role', _selectedRole!);

    // Also save role to Firestore if logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'role': _selectedRole,
      }, SetOptions(merge: true));
    }

    if (!mounted) return;

    if (_selectedRole == 'admin') {
      await launchUrl(Uri.parse('https://reliefnet-eb5f2.web.app'));
      Navigator.pushReplacementNamed(context, '/auth');
    } else {
      Navigator.pushReplacementNamed(context, '/auth');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isRolePage = _currentPage == _totalPages - 1;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                physics: const BouncingScrollPhysics(),
                children: [
                  ..._pages.asMap().entries.map(
                    (e) => _buildInfoPage(e.key, e.value),
                  ),
                  _buildRolePage(),
                ],
              ),
            ),
            _buildDotIndicator(),
            const SizedBox(height: 20),
            _buildBottomButton(isRolePage),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  // ─── Info page (pages 0–2) ───────────────────────────────────────────────────

  Widget _buildInfoPage(int index, Map<String, dynamic> page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated icon illustration
          _AnimatedIconIllustration(
            icon: page['icon'] as IconData,
            index: index,
          ),
          const SizedBox(height: 40),
          // Title
          TweenAnimationBuilder<Offset>(
            tween: Tween(begin: const Offset(0, 0.3), end: Offset.zero),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
            builder: (context, offset, child) =>
                FractionalTranslation(translation: offset, child: child),
            child: Text(
              page['title'] as String,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: _textDark,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 14),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeOut,
            builder: (context, opacity, child) =>
                Opacity(opacity: opacity, child: child),
            child: Text(
              page['subtitle'] as String,
              style: const TextStyle(
                fontSize: 15,
                color: _textMedium,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Location granted badge on page 2
          if (index == 1 && _locationGranted) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green.shade600,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Location access granted',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Role selection page ─────────────────────────────────────────────────────

  Widget _buildRolePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Welcome to ReliefNet',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose your role to get a personalized experience.',
            style: TextStyle(color: _textMedium, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),
          _buildRoleCard(
            role: 'reporter',
            icon: Icons.report_rounded,
            title: 'Reporter',
            subtitle: 'Report emergencies and disasters in your area.',
          ),
          const SizedBox(height: 16),
          _buildRoleCard(
            role: 'volunteer',
            icon: Icons.volunteer_activism_rounded,
            title: 'Volunteer',
            subtitle: 'Find tasks, help communities, and track your impact.',
          ),
          const SizedBox(height: 16),
          _buildRoleCard(
            role: 'admin',
            icon: Icons.admin_panel_settings_rounded,
            title: 'NGO Admin',
            subtitle: 'Manage relief operations and coordinate volunteers.',
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard({
    required String role,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedRole == role;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedRole = role);
      },
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: isSelected ? 1.0 : 0.0),
        duration: Duration(milliseconds: isSelected ? 180 : 120),
        curve: Curves.easeOut,
        builder: (context, t, child) {
          final bgColor = Color.lerp(Colors.white, _primary, t)!;
          final borderColor = Color.lerp(
            const Color(0xFFE2E8F0), _primary, t,
          )!;
          final iconBgColor = Color.lerp(_bgColor, Colors.white24, t)!;
          final iconColor = Color.lerp(_primary, Colors.white, t)!;
          final titleColor = Color.lerp(_textDark, Colors.white, t)!;
          final subtitleColor = Color.lerp(_textLight, Colors.white70, t)!;

          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: _primary.withOpacity(0.04 + t * 0.26),
                  blurRadius: 8 + t * 8,
                  offset: Offset(0, 2 + t * 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 13, color: subtitleColor),
                      ),
                    ],
                  ),
                ),
                Opacity(
                  opacity: t,
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Small dot page indicator ────────────────────────────────────────────────

  Widget _buildDotIndicator() {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_totalPages, (i) {
          final isActive = i == _currentPage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? _primary : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  // ─── Bottom button ────────────────────────────────────────────────────────────

  Widget _buildBottomButton(bool isRolePage) {
    final canProceed = !isRolePage || _selectedRole != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: canProceed ? 1.0 : 0.5,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_primary, _secondary],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: canProceed
                  ? [
                      BoxShadow(
                        color: _primary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: ElevatedButton(
              onPressed: canProceed
                  ? () {
                      if (!isRolePage) {
                        _nextPage();
                      } else {
                        _completeOnboarding();
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                isRolePage
                    ? (_selectedRole == null
                        ? 'Select a role'
                        : 'Get Started →')
                    : 'Next',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Animated icon illustration widget ───────────────────────────────────────
// Replaces Lottie — uses only built-in Flutter widgets and icons.

class _AnimatedIconIllustration extends StatefulWidget {
  final IconData icon;
  final int index;

  const _AnimatedIconIllustration({
    required this.icon,
    required this.index,
  });

  @override
  State<_AnimatedIconIllustration> createState() =>
      _AnimatedIconIllustrationState();
}

class _AnimatedIconIllustrationState extends State<_AnimatedIconIllustration>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  static const Color _primary = Color(0xFF3B82F6);
  static const Color _secondary = Color(0xFF6366F1);

  @override
  void initState() {
    super.initState();
    // Single controller drives everything
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        height: 240,
        width: 240,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final v = _controller.value;
            // Derive float and pulse from the single controller value
            final floatOffset = math.sin(v * 2 * math.pi) * 8;
            final pulseScale = 1.0 + math.sin(v * 4 * math.pi) * 0.04;

            return Stack(
              alignment: Alignment.center,
              children: [
                // Soft glow
                Positioned(
                  top: 20 + floatOffset,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _primary.withOpacity(0.06),
                          _primary.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                // Ring
                Positioned(
                  top: 40 + floatOffset,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _primary.withOpacity(0.1),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                // Orbiting dots (4 instead of 6)
                for (int i = 0; i < 4; i++)
                  _buildDot(i, v, floatOffset),
                // Main icon
                Positioned(
                  top: 60 + floatOffset,
                  child: Transform.scale(
                    scale: pulseScale,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [_primary, _secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _primary.withOpacity(0.3),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.icon,
                        size: 52,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDot(int i, double v, double floatOffset) {
    final angle = (v * 2 * math.pi) + (i * math.pi / 2);
    final x = math.cos(angle) * 90;
    final y = math.sin(angle) * 45;
    final dotSize = 5.0 + (i % 2) * 3.0;
    final opacity = 0.25 + (math.sin(angle) + 1) * 0.25;

    return Positioned(
      left: 120 + x - dotSize / 2,
      top: 120 + y + floatOffset - dotSize / 2,
      child: Container(
        width: dotSize,
        height: dotSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: (i.isEven ? _primary : _secondary).withOpacity(opacity),
        ),
      ),
    );
  }
}

