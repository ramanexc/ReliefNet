import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:reliefnet/login-signup/signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validatePassword() {
    if (_passwordController.text.length < 8) {
      _showError("Password must be at least 8 characters long.");
      return false;
    }
    return true;
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

  Future<void> _signIn() async {
    if (!_validatePassword()) return;
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String msg = "An error occurred. Please try again.";
        if (e.code == 'user-not-found') {
          msg = "No user found for that email.";
        } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') msg = "Wrong password provided.";
        else if (e.code == 'invalid-email') msg = "The email address is badly formatted.";
        _showError(msg);
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      setState(() => _isLoading = true);
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result = await FirebaseAuth.instance.signInWithCredential(credential);
      if (result.user == null) throw Exception("Firebase user is null");

      // Fix 3: create Firestore doc for first-time Google users
      if (result.additionalUserInfo?.isNewUser == true) {
        final user = result.user!;
        final baseName = (user.displayName ?? 'user').toLowerCase().replaceAll(' ', '_');
        final username = '${baseName}_${user.uid.substring(0, 4)}';

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': user.displayName ?? '',
          'username': username,
          'phone': user.phoneNumber ?? '',
          'email': user.email ?? '',
          'isVolunteer': false,
          'volunteerId': '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (FirebaseAuth.instance.currentUser == null) {
        _showError("Google sign-in failed. Please try again.");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Fix 6: navigate to signup and handle the result
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

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ── Hero ─────────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(24, 52, 24, 40),
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
                    Image.asset("assets/images/logo.png", height: 56),
                    const SizedBox(height: 20),
                    Text(
                      "Welcome Back",
                      style: textTheme.bodyLarge?.copyWith(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Sign in to continue helping your community",
                      style: textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),

              // ── Form ─────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Text("Email", style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: textTheme.bodyMedium,
                      decoration: const InputDecoration(
                        hintText: "your@email.com",
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text("Password", style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscure,
                      style: textTheme.bodyMedium,
                      decoration: InputDecoration(
                        hintText: "Min. 8 characters",
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Sign In Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _isLoading ? null : _signIn,
                        child: _isLoading
                            ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : const Text("Sign In", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // OR Divider
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text("OR", style: textTheme.bodySmall),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Google Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _isLoading ? null : _signInWithGoogle,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset("assets/images/google.png", height: 20),
                            const SizedBox(width: 12),
                            const Text("Continue with Google", style: TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Sign Up Link
                    Center(
                      child: GestureDetector(
                        onTap: _goToSignup, // Fix 6: use _goToSignup instead of inline push
                        child: RichText(
                          text: TextSpan(
                            style: textTheme.bodyMedium,
                            children: [
                              const TextSpan(text: "Don't have an account? "),
                              TextSpan(
                                text: "Sign Up",
                                style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
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
}