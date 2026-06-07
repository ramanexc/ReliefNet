import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = credential.user;
      if (user != null) {
        await user.updateDisplayName(_nameController.text.trim());

        // Fix 3: append UID suffix to avoid duplicate usernames
        final baseName = _nameController.text.trim().toLowerCase().replaceAll(' ', '_');
        final username = '${baseName}_${user.uid.substring(0, 4)}';

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': _nameController.text.trim(),
          'username': username,
          'phone': _phoneController.text.trim(),
          'email': _emailController.text.trim(),
          'isVolunteer': false,
          'volunteerId': '',
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Sign out so authStateChanges doesn't auto-navigate to home
        await FirebaseAuth.instance.signOut();
      }

      if (mounted) {
        // Fix 6: pop with true so login page shows the snackbar, not this page
        Navigator.pop(context, true);
      }
    } on FirebaseAuthException catch (e) {
      String error = "Signup failed. Please try again.";
      if (e.code == 'email-already-in-use') {
        error = "An account with this email already exists.";
      } else if (e.code == 'weak-password') error = "Password is too weak. Use at least 8 characters.";
      else if (e.code == 'invalid-email') error = "The email address is badly formatted.";
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 36),
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
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Create Account",
                      style: textTheme.bodyLarge?.copyWith(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Join ReliefNet and start making a difference",
                      style: textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),

              // ── Form ─────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                // Fix 5: wrap in Form for inline validation errors
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Full Name
                      _FieldLabel(label: "Full Name", icon: Icons.person_outline),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        style: textTheme.bodyMedium,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          hintText: "John Doe",
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return "Full name is required";
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Phone
                      _FieldLabel(label: "Phone Number", icon: Icons.phone_outlined),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: textTheme.bodyMedium,
                        decoration: const InputDecoration(
                          hintText: "+91 98765 43210",
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        // Fix 2: proper phone regex
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return "Phone number is required";
                          if (!RegExp(r'^\+?[0-9]{10,13}$').hasMatch(v.trim())) {
                            return "Enter a valid phone number (10–13 digits)";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Email
                      _FieldLabel(label: "Email", icon: Icons.email_outlined),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: textTheme.bodyMedium,
                        decoration: const InputDecoration(
                          hintText: "your@email.com",
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return "Email is required";
                          if (!RegExp(r'^[\w\.\+\-]+@[\w\-]+\.\w{2,}$').hasMatch(v.trim())) {
                            return "Enter a valid email address";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Password
                      _FieldLabel(label: "Password", icon: Icons.lock_outline),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscure1,
                        style: textTheme.bodyMedium,
                        decoration: InputDecoration(
                          hintText: "Min. 8 characters",
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure1 ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            onPressed: () => setState(() => _obscure1 = !_obscure1),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.length < 8) return "Password must be at least 8 characters";
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Confirm Password
                      _FieldLabel(label: "Confirm Password", icon: Icons.lock_outline),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscure2,
                        style: textTheme.bodyMedium,
                        decoration: InputDecoration(
                          hintText: "Re-enter password",
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure2 ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            onPressed: () => setState(() => _obscure2 = !_obscure2),
                          ),
                        ),
                        validator: (v) {
                          if (v != _passwordController.text) return "Passwords do not match";
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),

                      // Create Account Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _isLoading ? null : _signUp,
                          child: _isLoading
                              ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.person_add_rounded),
                                    SizedBox(width: 8),
                                    Text("Create Account", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Back to login link
                      Center(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: RichText(
                            text: TextSpan(
                              style: textTheme.bodyMedium,
                              children: [
                                const TextSpan(text: "Already have an account? "),
                                TextSpan(
                                  text: "Sign In",
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Field Label ───────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const _FieldLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}