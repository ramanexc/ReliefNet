import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class GeminiService {
  static const _apiKey = String.fromEnvironment('GOOGLE_API_KEY');
  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';
  static const _model = 'gemini-3.1-flash-lite';

  static Future<String?> _callGemini(String prompt) async {
    if (_apiKey.isEmpty) {
      print('GEMINI ERROR: GOOGLE_API_KEY is not set. Use --dart-define=GOOGLE_API_KEY=your_key');
      return "AI Assistant is not configured. Please contact support.";
    }
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/$_model:generateContent?key=$_apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt},
                  ],
                },
              ],
              'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 1024},
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        print('GEMINI ERROR: ${response.statusCode} ${response.body}');
        return null;
      }

      final data = jsonDecode(response.body);
      return data['candidates']?[0]?['content']?['parts']?[0]?['text']
          as String?;
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

  static Future<Map<String, dynamic>?> analyzeReport({
    required String issueType,
    required String urgency,
    required String description,
  }) async {
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

Keep solutions practical and specific to the issue type. Keep each skillset item short (1-3 words each, e.g. "First Aid", "Logistics", "Counseling").
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

    // Primary: Google Places API
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
