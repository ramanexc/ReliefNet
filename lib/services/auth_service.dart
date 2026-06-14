import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get userStream => _auth.authStateChanges();

  // --- CHECK IF PHONE EXISTS ---
  Future<bool> checkPhoneExists(String phone) async {
    final query = await _db.collection('users')
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  // --- PHONE AUTH ---
  Future<void> verifyPhoneNumber(
    String phone, {
    required Function(String, int?) onCodeSent,
    required Function(FirebaseAuthException) onFailed,
  }) async {
    print("DEBUG: Starting Phone Verification for $phone");
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          print("DEBUG: Verification Completed Automatically: ${credential.smsCode}");
          // Auto-retrieval on Android
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          print("DEBUG: Verification Failed. Code: ${e.code}, Message: ${e.message}");
          onFailed(e);
        },
        codeSent: (String vid, int? resendToken) {
          print("DEBUG: Code Sent. Verification ID: $vid");
          onCodeSent(vid, resendToken);
        },
        codeAutoRetrievalTimeout: (String vid) {
          print("DEBUG: Auto Retrieval Timeout. Verification ID: $vid");
        },
      );
    } catch (e) {
      print("DEBUG: Unexpected Error in verifyPhoneNumber: $e");
    }
  }

  Future<UserCredential> signInWithOTP(String vid, String code, {bool sync = true}) async {
    AuthCredential credential = PhoneAuthProvider.credential(verificationId: vid, smsCode: code);
    UserCredential userCredential = await _auth.signInWithCredential(credential);
    if (sync) {
      await _syncUserToFirestore(userCredential.user);
    }
    return userCredential;
  }

  // --- EMAIL AUTH ---
  Future<UserCredential> signInWithEmail(String email, String password) async {
    UserCredential credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
    await _syncUserToFirestore(credential.user);
    return credential;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // --- GOOGLE AUTH ---
  Future<UserCredential?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null;
    
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    
    UserCredential userCredential = await _auth.signInWithCredential(credential);
    await _syncUserToFirestore(userCredential.user);
    return userCredential;
  }

  // --- SYNC USER TO FIRESTORE ---
  Future<void> _syncUserToFirestore(User? user) async {
    if (user == null) return;
    
    DocumentReference userDoc = _db.collection('users').doc(user.uid);
    DocumentSnapshot doc = await userDoc.get();

    if (!doc.exists) {
      final baseName = (user.displayName ?? 'user').toLowerCase().replaceAll(' ', '_');
      final username = '${baseName}_${user.uid.substring(0, 4)}';
      
      await userDoc.set({
        'uid': user.uid,
        'name': user.displayName ?? "New User",
        'username': username,
        'email': user.email ?? "",
        'phone': user.phoneNumber ?? "",
        'isVolunteer': false,
        'volunteerId': '',
        'role': 'citizen', // Default role
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> signOut() async => await _auth.signOut();
}
