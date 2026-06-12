import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:reliefnet/services/gemini_service.dart';
import 'package:path/path.dart' as p;

class OfflineReportService {
  static bool _isSyncing = false;
  static bool get isSyncing => _isSyncing;

  static Future<bool> hasInternet() async {
    try {
      final result = await InternetAddress.lookup('example.com').timeout(const Duration(seconds: 4));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<String> _saveMediaPermanently(String tempPath) async {
    try {
      final file = File(tempPath);
      if (!await file.exists()) return tempPath;
      final appDir = await getApplicationDocumentsDirectory();
      final offlineDir = Directory('${appDir.path}/offline_media');
      if (!await offlineDir.exists()) {
        await offlineDir.create(recursive: true);
      }
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(tempPath)}';
      final savedFile = await file.copy('${offlineDir.path}/$fileName');
      return savedFile.path;
    } catch (e) {
      print("Error saving offline media: $e");
      return tempPath;
    }
  }

  static Future<void> saveReportOffline({
    required String issueType,
    required String urgency,
    required String description,
    required double? latitude,
    required double? longitude,
    required double? accuracy,
    required bool isLifeThreatening,
    required List<String> lifeThreateningScenarios,
    required List<String> immediateNeeds,
    required String? peopleAffected,
    required String landmark,
    required bool allowContact,
    required String contactPhone,
    required String contactAltPhone,
    required List<String> tempMediaPaths,
  }) async {
    final List<String> permanentPaths = [];
    for (final path in tempMediaPaths) {
      final permanentPath = await _saveMediaPermanently(path);
      permanentPaths.add(permanentPath);
    }

    final reportData = {
      'issueType': issueType,
      'urgency': urgency,
      'description': description,
      'lat': latitude,
      'lng': longitude,
      'gpsAccuracy': accuracy,
      'isLifeThreatening': isLifeThreatening,
      'lifeThreateningScenarios': lifeThreateningScenarios,
      'immediateNeeds': immediateNeeds,
      'peopleAffected': peopleAffected ?? 'Unknown',
      'landmark': landmark,
      'allowContact': allowContact,
      'contactPhone': contactPhone,
      'contactAltPhone': contactAltPhone,
      'localMediaPaths': permanentPaths,
      'timestamp': DateTime.now().toIso8601String(),
    };

    final prefs = await SharedPreferences.getInstance();
    final List<String> existing = prefs.getStringList('offline_reports') ?? [];
    existing.add(jsonEncode(reportData));
    await prefs.setStringList('offline_reports', existing);
  }

  static Future<int> getOfflineCount() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList('offline_reports') ?? []).length;
  }

  static Future<void> syncOfflineReports({Function(String)? onStatusUpdate}) async {
    if (_isSyncing) return;
    if (!await hasInternet()) return;

    final prefs = await SharedPreferences.getInstance();
    final List<String> reportsJson = prefs.getStringList('offline_reports') ?? [];
    if (reportsJson.isEmpty) return;

    _isSyncing = true;
    onStatusUpdate?.call("Syncing ${reportsJson.length} offline report(s)...");

    final List<String> remainingReports = List.from(reportsJson);

    try {
      for (final reportStr in reportsJson) {
        final Map<String, dynamic> data = jsonDecode(reportStr);
        final docRef = FirebaseFirestore.instance.collection('reports').doc();
        final docId = docRef.id;

        final List<String> localMediaPaths = List<String>.from(data['localMediaPaths'] ?? []);
        final List<String> mediaUrls = [];

        final user = FirebaseAuth.instance.currentUser;
        final uid = user?.uid ?? 'anonymous';

        // 1. Upload local media files
        for (final path in localMediaPaths) {
          final file = File(path);
          if (await file.exists()) {
            final ext = p.extension(path);
            final fileName = '${DateTime.now().millisecondsSinceEpoch}$ext';
            final ref = FirebaseStorage.instance.ref().child('reports/$uid/$docId/$fileName');
            await ref.putFile(file);
            final url = await ref.getDownloadURL();
            mediaUrls.add(url);
          }
        }

        // 2. Perform Credibility analysis
        Map<String, dynamic> credibility = {
          'status': 'unassigned',
          'isSpam': false,
          'reason': 'Synced offline; skipped real-time checks.',
        };

        try {
          final List<Uint8List> imageBytesList = [];
          for (final path in localMediaPaths.take(2)) {
            final ext = p.extension(path).toLowerCase();
            final isVideo = ['.mp4', '.mov', '.avi', '.mkv', '.webm'].contains(ext);
            if (!isVideo) {
              final file = File(path);
              if (await file.exists()) {
                imageBytesList.add(await file.readAsBytes());
              }
            }
          }

          credibility = await GeminiService.checkCredibility(
            issueType: data['issueType'],
            description: data['description'],
            imageBytesList: imageBytesList.isNotEmpty ? imageBytesList : null,
          );
        } catch (e) {
          print("Offline sync credibility check failed: $e");
        }

        // 3. Write Firestore Doc
        await docRef.set({
          'issueType': data['issueType'],
          'urgency': data['urgency'],
          'description': data['description'],
          'lat': data['lat'],
          'lng': data['lng'],
          'timestamp': FieldValue.serverTimestamp(),
          'status': credibility['status'] == 'suspected_spam' ? 'flagged' : 'unassigned',
          'assignedVolunteers': [],
          'submittedBy': uid,
          'isAnonymous': user == null,
          'mediaUrls': mediaUrls,
          'aiSummary': null,
          'credibility': credibility,
          'isLifeThreatening': data['isLifeThreatening'] ?? false,
          'lifeThreateningScenarios': data['lifeThreateningScenarios'] ?? [],
          'immediateNeeds': data['immediateNeeds'] ?? [],
          'peopleAffected': data['peopleAffected'] ?? 'Unknown',
          'landmark': data['landmark'] ?? '',
          'allowContact': data['allowContact'] ?? false,
          'contactPhone': data['contactPhone'] ?? '',
          'contactAltPhone': data['contactAltPhone'] ?? '',
          'verificationScore': _calculateVerificationScore(data, localMediaPaths),
          'gpsAccuracy': data['gpsAccuracy'],
          'locationTimestamp': data['timestamp'] != null ? DateTime.parse(data['timestamp']) : FieldValue.serverTimestamp(),
        });

        // 4. Try AI Summary
        try {
          final aiSummary = await GeminiService.analyzeReport(
            issueType: data['issueType'],
            urgency: data['urgency'],
            description: data['description'],
          );
          if (aiSummary != null) {
            await docRef.update({'aiSummary': aiSummary});
          }
        } catch (e) {
          print("Offline sync AI analysis failed: $e");
        }

        // 5. Clean up local persistent media files
        for (final path in localMediaPaths) {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        }

        // Remove from list
        remainingReports.remove(reportStr);
        await prefs.setStringList('offline_reports', remainingReports);
      }
      onStatusUpdate?.call("Sync completed successfully!");
    } catch (e) {
      print("Offline sync failed: $e");
      onStatusUpdate?.call("Sync failed. Will retry later.");
    } finally {
      _isSyncing = false;
    }
  }

  static int _calculateVerificationScore(Map<String, dynamic> data, List<String> paths) {
    int score = 0;
    if (data['lat'] != null) score += 25;
    if (paths.isNotEmpty) score += 25;
    if ((data['description'] as String?)?.trim().length != null && (data['description'] as String).trim().length >= 15) score += 25;
    if (data['allowContact'] == true && (data['contactPhone'] as String?)?.trim().length != null && (data['contactPhone'] as String).trim().length >= 10) score += 25;
    return score;
  }
}
