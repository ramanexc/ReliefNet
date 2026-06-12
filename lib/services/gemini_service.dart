import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  static const _apiKey = String.fromEnvironment('GOOGLE_API_KEY');
  static const _modelName = 'gemini-3.1-flash-lite';

  static GenerativeModel? _model;

  static GenerativeModel get _getModel {
    _model ??= GenerativeModel(
      model: _modelName,
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 1024,
      ),
    );
    return _model!;
  }

  static Future<String?> _callGemini(String prompt) async {
    print('DEBUG: API Key length: ${_apiKey.length}');
    if (_apiKey.isNotEmpty) {
      print('DEBUG: API Key starts with: ${_apiKey.substring(0, min(5, _apiKey.length))}...');
    }

    if (_apiKey.isEmpty) {
      print('GEMINI ERROR: GOOGLE_API_KEY is not set. Make sure to use --dart-define=GOOGLE_API_KEY=your_key');
      return "AI Assistant is not configured. Please contact support.";
    }
    try {
      final content = [Content.text(prompt)];
      final response = await _getModel.generateContent(content);
      return response.text;
    } catch (e) {
      print('GEMINI ERROR: $e');
      return null;
    }
  }

  // ── Dashboard overview ────────────────────────────────────────────────────

  static Future<String?> generateDashboardOverview(
    List<Map<String, dynamic>> reports,
  ) async {
    if (reports.isEmpty) return null;

    final reportsText = reports
        .take(10)
        .map(
          (r) =>
              '- Type: ${r['issueType']}, Urgency: ${r['urgency']}, Description: ${r['description']}',
        )
        .join('\n');

    final prompt =
        'Summarize these crisis reports in 2-3 sentences for an NGO dashboard. '
        'Highlight the most urgent issues and overall situation:\n$reportsText';

    return await _callGemini(prompt);
  }

  // ── Mahi Chat Assistant ───────────────────────────────────────────────────

  static Future<String?> mahiChat(String prompt) async {
    return await _callGemini(prompt);
  }

  // ── Per-report analysis ───────────────────────────────────────────────────

  static final List<String> availableSkills = [
    "Animal Care / Veterinary", "Carpentry", "Child Care", "Community Outreach", "Cooking",
    "Counseling", "CPR", "Crisis Communication", "Data Entry", "Debris Removal",
    "Driving", "Elderly Care", "Electrical Work", "Emergency Response", "Event Coordination",
    "Firefighting", "First Aid", "Fundraising", "Heavy Machinery Operation", "Inventory Management",
    "IT Support", "Legal Support", "Logistics", "Medical Assistance", "Mental Health Support",
    "Nursing", "Nutrition & Dietetics", "Photography / Videography", "Plumbing", "Radio Operation",
    "Search & Rescue", "Security Services", "Social Media Management", "Supply Distribution",
    "swimming", "Teaching", "Translation", "Water Purification"
  ];

  static Future<Map<String, dynamic>?> analyzeReport({
    required String issueType,
    required String urgency,
    required String description,
  }) async {
    final skillsString = availableSkills.join(", ");
    final prompt =
        '''
You are an AI assistant for ReliefNet, an NGO field reporting platform.
Analyze the following field report and respond ONLY with a valid JSON object. No explanation, no markdown, no backticks.

Report:
- Issue Type: $issueType
- Urgency: $urgency
- Description: $description

Respond with exactly this JSON structure:
{
  "summary": "One clear sentence summarizing the situation",
  "solutions": ["Actionable solution 1", "Actionable solution 2", "Actionable solution 3"],
  "skillset_required": ["Skill 1", "Skill 2", "Skill 3"],
  "estimated_people_affected": "e.g. 10-20 people",
  "action_priority": "Immediate / Within 24 hours / Within a week"
}

IMPORTANT: For "skillset_required", you MUST choose 2-5 skills from this specific list: [$skillsString]. 
If a required skill is not in the list but is absolutely critical, you may add it, but prioritize the provided list.
Keep solutions practical and specific to the issue type.
''';

    final text = await _callGemini(prompt);
    if (text == null) return null;

    try {
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start != -1 && end != -1) {
        return jsonDecode(text.substring(start, end + 1))
            as Map<String, dynamic>;
      }
    } catch (e) {
      print('GEMINI JSON PARSE ERROR: $e');
    }
    return null;
  }

  // ── Credibility & Spam Detection ──────────────────────────────────────────

  static Future<Map<String, dynamic>> checkCredibility({
    required String issueType,
    required String description,
    List<Uint8List>? imageBytesList,
  }) async {
    final prompt = '''
As an Emergency Forensic Validator, analyze this report for credibility and spam.
REPORTED ISSUE: $issueType
DESCRIPTION: $description

TASKS:
1. SPAM DETECTION: Check for meaningless text (asdf, hello), jokes, test messages, or gibberish.
2. VISUAL TRUTH: If images are provided, do they show a real emergency? Reject memes, selfies, screenshots, or unrelated photos.
3. CONSISTENCY: Does the image match the described issue? (e.g., if "Fire" is reported, are flames/smoke visible?)
4. TYPOS/CLARITY: Is the description clear enough for responders?

STRICT JSON RESPONSE (No markdown):
{
  "score": 0-100 (Credibility score: 100 is high truth),
  "isSpam": boolean,
  "status": "verified | likely_genuine | needs_review | suspected_spam",
  "reason": "Clear explanation of the verdict",
  "spamProbability": 0-100
}
''';

    try {
      final content = [
        Content.multi([
          TextPart(prompt),
          if (imageBytesList != null)
            ...imageBytesList.take(2).map((bytes) => DataPart('image/jpeg', bytes)),
        ])
      ];

      final response = await _getModel.generateContent(content);
      final text = response.text;
      if (text == null) throw Exception("Empty AI response");

      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start != -1 && end != -1) {
        return jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
      }
      return {"score": 50, "status": "needs_review", "reason": "AI formatting error", "isSpam": false};
    } catch (e) {
      print('CREDIBILITY CHECK ERROR: $e');
      return {"score": 50, "status": "needs_review", "reason": "AI analysis failed", "isSpam": false};
    }
  }

  // ── Nearby hospitals ──────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getNearbyHospitals(
    double lat,
    double lng,
    String address,
  ) async {
    List<Map<String, dynamic>> results = [];
    final Set<String> seenNames = {};

    void addUniqueResult(
      String name,
      String addr,
      double pLat,
      double pLng,
      dynamic rating,
      String? phone,
    ) {
      final normalizedName = name.toLowerCase().trim();
      if (!seenNames.contains(normalizedName)) {
        seenNames.add(normalizedName);
        final distanceInKm =
            Geolocator.distanceBetween(lat, lng, pLat, pLng) / 1000;
        if (distanceInKm <= 7.0) {
          results.add({
            'name': name,
            'address': addr,
            'distance': distanceInKm.toStringAsFixed(1),
            'rating': rating?.toString() ?? '4.2',
            'phone': phone ?? 'N/A',
            'lat': pLat,
            'lng': pLng,
          });
        }
      }
    }

    // Primary: Google Places API (using http because the generative AI package doesn't cover this)
    try {
      final url = Uri.parse(
        'https://places.googleapis.com/v1/places:searchText',
      );
      final headers = {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _apiKey,
        'X-Goog-FieldMask':
            'places.displayName,places.formattedAddress,places.location,places.rating,places.internationalPhoneNumber',
      };
      final body = jsonEncode({
        'textQuery': 'hospitals and medical centers near $address',
        'locationBias': {
          'circle': {
            'center': {'latitude': lat, 'longitude': lng},
            'radius': 7000.0,
          },
        },
      });

      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> places = data['places'] ?? [];
        for (var p in places) {
          final loc = p['location'];
          if (loc != null) {
            addUniqueResult(
              p['displayName']?['text'] ?? 'Hospital',
              p['formattedAddress'] ?? 'Address unavailable',
              loc['latitude'],
              loc['longitude'],
              p['rating'],
              p['internationalPhoneNumber'],
            );
          }
        }
      }
    } catch (e) {
      print('Places SearchText Exception: $e');
    }

    // Fallback: Gemini AI
    if (results.isEmpty) {
      results = await _getNearbyHospitalsFallback(lat, lng, address);
    }

    if (results.isNotEmpty) {
      results.sort(
        (a, b) =>
            double.parse(a['distance']).compareTo(double.parse(b['distance'])),
      );
    }

    return results;
  }

  static Future<List<Map<String, dynamic>>> _getNearbyHospitalsFallback(
    double lat,
    double lng,
    String address,
  ) async {
    final prompt =
        '''
Identify exactly 5 REAL, PHYSICALLY EXISTING hospitals or major 24/7 medical centers located within 7km of these coordinates: $lat, $lng (Location: $address).
Return ONLY a valid JSON list of objects with these keys: "name", "address", "distance" (estimated km from user), "rating" (1-5), "phone", "lat", "lng".
No explanation, no markdown, no backticks.
''';

    final text = await _callGemini(prompt);
    if (text == null) return [];

    try {
      final start = text.indexOf('[');
      final end = text.lastIndexOf(']');
      if (start != -1 && end != -1) {
        final List<dynamic> decoded = jsonDecode(
          text.substring(start, end + 1),
        );
        return decoded.map((e) {
          final item = Map<String, dynamic>.from(e);
          item['distance'] = item['distance'].toString();
          return item;
        }).toList();
      }
    } catch (_) {}
    return [];
  }
}
