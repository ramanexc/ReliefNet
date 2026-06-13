import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:reliefnet/login-signup/signup_page.dart';
import 'package:reliefnet/login-signup/otp_page.dart';
import 'package:reliefnet/login-signup/otp_test_page.dart';
import 'package:reliefnet/services/auth_service.dart';
import 'package:reliefnet/components/phone_formatter.dart';
import 'package:reliefnet/l10n/app_localizations.dart';
import 'package:reliefnet/main-pages/report_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  bool _obscure = true;
  bool _isEmailMode = true; // Toggle between email and phone
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _phoneController.text = "+91 ";
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
  }

  Future<void> _signInWithEmail() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError("Please fill in all fields.");
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _authService.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String msg = "An error occurred. Please try again.";
        if (e.code == 'user-not-found') {
          msg = "No user found for that email.";
        } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') msg = "Wrong password provided.";
        _showError(msg);
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError("Please enter your email address to reset your password.");
      return;
    }

    // Basic email validation regex
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showError("Please enter a valid email address.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.sendPasswordResetEmail(email);
      if (mounted) {
        _showSuccess("A password reset link has been sent to your email. Please check your inbox and spam folder.");
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String msg = "Error: ${e.message}";
        if (e.code == 'user-not-found') {
          msg = "No user found with this email.";
        }
        _showError(msg);
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendOTP() async {
    // Strip all spaces and non-digits except the leading plus
    final rawPhone = _phoneController.text;
    final phone = rawPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    
    if (phone.isEmpty || !phone.startsWith('+') || phone.length < 10) {
      _showError("Enter a valid phone number with country code (e.g. +91...)");
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Check if user is registered
      final exists = await _authService.checkPhoneExists(phone);
      if (!exists) {
        setState(() => _isLoading = false);
        _showError("This phone number is not registered. Please sign up first.");
        return;
      }

      // 2. If exists, send OTP
      await _authService.verifyPhoneNumber(
        phone,
        onCodeSent: (verificationId, resendToken) {
          if (mounted) {
            setState(() => _isLoading = false);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OTPPage(verificationId: verificationId, phoneNumber: phone),
              ),
            );
          }
        },
        onFailed: (e) {
          if (mounted) {
            setState(() => _isLoading = false);
            _showError(e.message ?? "Phone verification failed.");
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError("An error occurred: $e");
      }
    }
  }

  Future<void> _goToSignup() async {
    final success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SignupPage()),
    );
    if (success == true) {
      _showSuccess('Account created! Please sign in.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 30),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colorScheme.primary, colorScheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset("assets/images/logo.png", height: 48),
                    const SizedBox(height: 16),
                    Text(
                      l10n.welcome_back,
                      style: textTheme.bodyLarge?.copyWith(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isEmailMode ? "Sign in to your account" : "Sign in with your phone number",
                      style: textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // Mode Toggle
                    Container(
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(child: _modeButton(true, "Email")),
                          Expanded(child: _modeButton(false, "Phone")),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    if (_isEmailMode) ...[
                      _buildTextField(
                        controller: _emailController,
                        label: l10n.email,
                        hint: "your@email.com",
                        icon: Icons.email_outlined,
                        type: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: _passwordController,
                        label: l10n.password,
                        hint: "Min. 8 characters",
                        icon: Icons.lock_outline,
                        obscure: _obscure,
                        suffix: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _forgotPassword,
                          child: Text(
                            "Forgot Password?",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      _buildTextField(
                        controller: _phoneController,
                        label: "Phone Number",
                        hint: "+91 70655 58444",
                        icon: Icons.phone_outlined,
                        type: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                          IndiaPhoneFormatter(),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text("We'll send a 6-digit code to verify your number.", style: textTheme.bodySmall?.copyWith(color: Colors.grey)),
                    ],

                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isLoading ? null : (_isEmailMode ? _signInWithEmail : _sendOTP),
                        child: _isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(_isEmailMode ? l10n.sign_in : "Send OTP", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),

                    if (_isEmailMode) ...[
                      const SizedBox(height: 20),
                      Center(
                        child: GestureDetector(
                          onTap: _goToSignup,
                          child: RichText(
                            text: TextSpan(
                              style: textTheme.bodyMedium,
                              children: [
                                TextSpan(text: l10n.dont_have_account),
                                TextSpan(
                                  text: l10n.sign_up,
                                  style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 40),
                    const Divider(),
                    const SizedBox(height: 20),

                    // Emergency Report Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.red.shade300),
                        foregroundColor: Colors.red.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => Scaffold(appBar: AppBar(title: const Text("Emergency Report")), body: const ReportPage(isEmergency: true))));
                      },
                      icon: const Icon(Icons.emergency_share),
                      label: const Text("Report Emergency Anonymously", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),

                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeButton(bool mode, String label) {
    final isSelected = _isEmailMode == mode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => setState(() => _isEmailMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))] : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected 
                  ? (isDark ? Colors.white : Theme.of(context).primaryColor) 
                  : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType type = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: type,
          inputFormatters: inputFormatters,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.normal),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}
