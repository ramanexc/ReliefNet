import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:reliefnet/services/auth_service.dart';

class OTPPage extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;
  final Map<String, String>? signupData;

  const OTPPage({
    super.key, 
    required this.verificationId, 
    required this.phoneNumber,
    this.signupData,
  });

  @override
  State<OTPPage> createState() => _OTPPageState();
}

class _OTPPageState extends State<OTPPage> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  final _authService = AuthService();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  Future<void> _verifyOTP() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      _showError("Please enter a valid 6-digit code.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (widget.signupData != null) {
        // --- SIGNUP COMPLETION ---
        // 1. Verify Phone OTP first (this signs them in temporarily with phone)
        // We set sync: false to avoid creating a partial Firestore document for the phone-only user
        await _authService.signInWithOTP(widget.verificationId, code, sync: false);
        
        // 2. Create Email User (this will sign them in with email instead)
        final email = widget.signupData!['email']!;
        final password = widget.signupData!['password']!;
        final name = widget.signupData!['name']!;
        
        final emailCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        if (emailCred.user != null) {
          await emailCred.user!.updateDisplayName(name);
          
          // 3. Save to Firestore using the new Email UID
          await FirebaseFirestore.instance.collection('users').doc(emailCred.user!.uid).set({
            'uid': emailCred.user!.uid,
            'name': name,
            'email': email,
            'phone': widget.phoneNumber,
            'username': '${name.toLowerCase().replaceAll(' ', '_')}_${emailCred.user!.uid.substring(0, 4)}',
            'isVolunteer': false,
            'volunteerId': '',
            'role': 'citizen',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        // --- LOGIN FLOW ---
        await _authService.signInWithOTP(widget.verificationId, code);
      }

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        _showError("Verification failed: $e");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(title: const Text("Verify Phone")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Verify your phone number",
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Enter the 6-digit code sent to ${widget.phoneNumber}",
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.normal),
              decoration: const InputDecoration(
                counterText: "",
                hintText: "000000",
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _verifyOTP,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text("Verify & Continue", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Change Phone Number"),
            ),
          ],
        ),
      ),
    );
  }
}
