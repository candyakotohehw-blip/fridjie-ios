import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import '../models/fridge_setup_models.dart';

class FridgeAnalysisService {
  final String apiKey;
  static const String _modelName = 'gemini-2.5-flash'; // Using Gemini 2.5 Flash

  FridgeAnalysisService({required this.apiKey});

  /// Analyze fridge image using Gemini 2.5 Flash
  /// Returns parsed JSON map with fridge details
  Future<Map<String, dynamic>> analyzeFridgeImage(
    String base64Image, {
    Function(double)? onProgress,
    Function(int)? onStepComplete,
  }) async {
    const maxRetries = 1;
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_modelName:generateContent?key=$apiKey'
    );

    final prompt = """You are an expert at identifying refrigerator specifications and layouts. Analyze this refrigerator image with extreme precision.

IMPORTANT: Extract ACTUAL visible information from the image, not generic defaults. If you can see it, report it.

Required Analysis:
1. Brand - Look for brand logos, labels, or distinctive design (Samsung, LG, Condura, Electrolux, Whirlpool, GE, Panasonic, etc.)
2. Model number / SKU — Transcribe the EXACT alphanumeric model code as printed on the energy label, door frame, or badge (include regional suffixes if shown, e.g. "RB30N4050S8/HL"). Prefer the primary manufacturer model string over serial numbers. If nothing is legible, use "Not visible in image".
3. Color - Describe the actual color you see (e.g., Silver, Black, White, Stainless Steel, Chrome)
4. Type - Identify refrigerator type from design (French Door, Side-by-Side, Top Freezer, Bottom Freezer, Single Door, Compact)
5. Capacity - Estimate in liters based on size and proportions
6. Dimensions - Estimate W x H x D in mm
7. Layout - Describe the physical layout (number of doors, freezer position, drawer placement)
8. Visible Items/Sections - Identify what's visible in/on the fridge
9. Sections list — Return zone names for the in-app layout editor. Include one entry per distinct storage area matching the REAL appliance in the photo. Use separate entries for each insulated SWING DOOR on the fresh-food section (name them "Left Door" and "Right Door" when there are two; use "Door" when there is only one). Do NOT invent extra doors: a French-door model has 2 upper doors; a single-door top-freezer has 1 door; side-by-side has 2 full-height doors. Include main shelves/drawers/crispers/freezer as separate zones when visible or standard for that type.
10. refrigeratorDoorPanelCount — Integer 1–4 = number of insulated swing doors on the refrigerator (fresh-food) compartment only. Do NOT count freezer drawers as doors. Examples: French door = 2; single-door = 1; side-by-side = 2; four-door with two freezer doors below = still 2 for the upper fridge pair (add freezer zones separately in sections).
11. freezerAccessStyle — One of: "drawer", "single_door", "double_door", "unknown" based on how the freezer is accessed in the image or typical for that model.

Return ONLY a valid JSON object with NO markdown formatting:
{
  "brand": "Actual brand name or 'Unable to determine'",
  "model": "Exact model/SKU from the image if visible, otherwise 'Not visible in image'",
  "color": "Actual color description",
  "type": "Specific type of refrigerator",
  "capacity": "Estimated capacity in liters",
  "dimensions": "Estimated dimensions W x H x D in mm",
  "layoutType": "Description of layout",
  "refrigeratorDoorPanelCount": 2,
  "freezerAccessStyle": "drawer",
  "detections": [{"label": "Item description", "confidence": "high/medium/low"}, ...],
  "sections": ["Left Door", "Right Door", "Top Shelf", "Middle Shelf", "Crisper Drawer", "Freezer Drawer"],
}""";

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print("🔄 Attempt $attempt/$maxRetries to analyze fridge with $_modelName...");
        
        // Step 1: Initial request (30%)
        onProgress?.call(0.05);
        await Future.delayed(const Duration(milliseconds: 200));
        onProgress?.call(0.15);
        await Future.delayed(const Duration(milliseconds: 200));

        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt},
                  {
                    'inline_data': {
                      'mime_type': 'image/jpeg',
                      'data': base64Image,
                    }
                  }
                ]
              }
            ]
          }),
        ).timeout(
          const Duration(seconds: 60),
          onTimeout: () => throw Exception('API request timeout after 60 seconds'),
        );

        // Step 1 Finish (API Response received - 40%)
        onProgress?.call(0.25);
        await Future.delayed(const Duration(milliseconds: 150));
        onProgress?.call(0.35);
        await Future.delayed(const Duration(milliseconds: 150));
        onProgress?.call(0.40);
        await Future.delayed(const Duration(milliseconds: 150));
        onStepComplete?.call(0);

        if (response.statusCode == 503) {
          if (attempt < maxRetries) {
            final delayMs = pow(2, attempt.toDouble()).toInt() * 1000;
            print("⏳ 503 Error - retrying in ${delayMs}ms...");
            await Future.delayed(Duration(milliseconds: delayMs));
            continue;
          } else {
            throw Exception("API Error: 503 - Service temporarily unavailable. Please try again in a moment.");
          }
        }

        if (response.statusCode == 429) {
          throw Exception("API Error: 429 - Rate limited. Please wait before analyzing again.");
        }

        if (response.statusCode != 200) {
          throw Exception("API Error: ${response.statusCode} - ${response.body}");
        }

        // Step 2: Parsing response (50-70%)
        onProgress?.call(0.50);
        await Future.delayed(const Duration(milliseconds: 200));
        onProgress?.call(0.60);
        await Future.delayed(const Duration(milliseconds: 200));

        final Map<String, dynamic> data = jsonDecode(response.body);
        final responseText = data['candidates'][0]['content']['parts'][0]['text'] as String;

        // Clean the response text
        final cleanJson = responseText.replaceAll('```json', '').replaceAll('```', '').trim();
        final Map<String, dynamic> aiData = jsonDecode(cleanJson);

        onProgress?.call(0.70);
        await Future.delayed(const Duration(milliseconds: 150));
        onStepComplete?.call(1);

        // Step 3: Finalizing (70-100%)
        onProgress?.call(0.80);
        await Future.delayed(const Duration(milliseconds: 200));
        onProgress?.call(0.90);
        await Future.delayed(const Duration(milliseconds: 200));

        final type = _cleanValue(aiData['type']);
        final layoutType = _cleanValue(aiData['layoutType']);
        final aiDoorHint = _parseDoorPanelCount(aiData['refrigeratorDoorPanelCount']);
        final rawSectionList = _sectionsFromDynamic(aiData['sections']);
        var inferredDoors =
            aiDoorHint ?? inferRefrigeratorDoorPanelCount(type, layoutType);
        if (inferredDoors == 0 && rawSectionList.isNotEmpty) {
          final titled =
              rawSectionList.map((s) => _titleCaseWords(s.trim())).toList();
          final amb = titled.where(_isAmbiguousDoorLabel).length;
          final lr = titled
              .where((s) =>
                  _looksLikeDoorLabel(s) &&
                  (_hasLeftDoorWord(s) || _hasRightDoorWord(s)))
              .length;
          if (amb >= 2 || lr >= 2) {
            inferredDoors = 2;
          } else if (amb == 1 || lr == 1) {
            inferredDoors = 1;
          }
        }
        final sections = rawSectionList.isEmpty
            ? _defaultSectionsForInferredDoors(inferredDoors, type, layoutType)
            : _normalizeFridgeSections(
                rawSectionList,
                type: type,
                layoutType: layoutType,
                doorPanelHint: inferredDoors,
              );

        // Validate and preserve actual data, only use defaults if truly missing
        final validatedData = {
          'brand': _cleanValue(aiData['brand']),
          'model': _cleanValue(aiData['model']),
          'color': _cleanValue(aiData['color']),
          'type': type,
          'capacity': _cleanValue(aiData['capacity']),
          'dimensions': _cleanValue(aiData['dimensions']),
          'layoutType': layoutType,
          'detections': _validateDetections(aiData['detections']),
          'sections': sections,
          'refrigeratorDoorPanelCount': inferredDoors >= 1 ? inferredDoors : null,
          'freezerAccessStyle': _cleanFreezerStyle(aiData['freezerAccessStyle']),
        };

        print("✅ Analysis Data: $validatedData");

        onProgress?.call(1.0);
        await Future.delayed(const Duration(milliseconds: 200));
        onStepComplete?.call(2);

        print("✅ Fridge analysis complete!");
        return validatedData;
      } catch (e) {
        print("❌ Attempt $attempt failed: $e");
        if (attempt == maxRetries) {
          rethrow;
        }
      }
    }

    throw Exception("Analysis failed after $maxRetries attempts");
  }

  /// Vision-only: list food/grocery items actually visible in a shelf or fridge interior photo.
  /// Each map has `name` and `category` (strings).
  Future<List<Map<String, String>>> detectShelfItems(
    String base64Image, {
    String mimeType = 'image/jpeg',
  }) async {
    const maxRetries = 4;
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_modelName:generateContent?key=$apiKey',
    );

    final prompt = '''You are labeling groceries visible in ONE refrigerator shelf or interior photo.

STRICT rules (follow exactly):
- List ONLY distinct food or drink products you can clearly see (shape, label, color, or packaging).
- Do NOT invent items hidden behind others. Do NOT list the fridge, shelf, wire rack, drawer, door, plastic bag without identifying contents, or generic "food" if you cannot name it.
- If nothing is clearly identifiable, return {"items":[]}.
- Prefer simple names: "Milk", "Eggs", "Strawberries", "Ketchup" — not long marketing copy.
- category must be exactly one of: Dairy, Produce, Beverages, Condiments, Eggs, Bakery, Frozen, Snacks, Meat, Seafood, Prepared foods, Other
- Max 18 items. Merge duplicates (same product twice).
- Do NOT output confidence scores, bounding boxes, or markdown.

Return ONLY valid JSON:
{"items":[{"name":"...","category":"..."}]}''';

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'contents': [
                  {
                    'parts': [
                      {'text': prompt},
                      {
                        'inline_data': {
                          'mime_type': mimeType,
                          'data': base64Image,
                        },
                      },
                    ],
                  },
                ],
                'generationConfig': {
                  'temperature': 0.15,
                  'topP': 0.85,
                },
              }),
            )
            .timeout(
              const Duration(seconds: 45),
              onTimeout: () =>
                  throw Exception('API request timeout after 45 seconds'),
            );

        if (response.statusCode == 503) {
          if (attempt < maxRetries) {
            await Future.delayed(Duration(milliseconds: 800 * attempt));
            continue;
          }
          throw Exception('Service temporarily unavailable (503).');
        }
        if (response.statusCode == 429) {
          if (attempt < maxRetries) {
            final delay = _retryDelayForAttempt(
              attempt,
              retryAfterHeader: response.headers['retry-after'],
            );
            print(
              '⏳ detectShelfItems hit 429. Retry $attempt/$maxRetries in ${delay.inMilliseconds}ms...',
            );
            await Future.delayed(delay);
            continue;
          }
          throw Exception(
            'Rate limit reached. Please wait a bit before scanning again.',
          );
        }
        if (response.statusCode != 200) {
          throw Exception('API Error: ${response.statusCode}');
        }

        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        final candidates = data['candidates'];
        if (candidates == null || candidates is! List || candidates.isEmpty) {
          throw Exception('Walang sagot mula sa AI (blocked o empty).');
        }
        final parts = (candidates[0] as Map)['content']?['parts'];
        if (parts is! List || parts.isEmpty) {
          throw Exception('Walang text mula sa AI.');
        }
        final responseText = (parts[0] as Map)['text']?.toString() ?? '';
        final cleanJson = responseText
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        Map<String, dynamic> aiData;
        try {
          aiData = jsonDecode(cleanJson) as Map<String, dynamic>;
        } catch (_) {
          final start = cleanJson.indexOf('{');
          final end = cleanJson.lastIndexOf('}');
          if (start >= 0 && end > start) {
            aiData = jsonDecode(cleanJson.substring(start, end + 1))
                as Map<String, dynamic>;
          } else {
            throw Exception('Hindi ma-parse ang sagot ng AI.');
          }
        }
        return _parseShelfItemsJson(aiData);
      } catch (e) {
        print('❌ detectShelfItems attempt $attempt: $e');
        if (attempt == maxRetries) rethrow;
      }
    }
    return [];
  }

  Duration _retryDelayForAttempt(
    int attempt, {
    String? retryAfterHeader,
  }) {
    final retryAfterSeconds = int.tryParse((retryAfterHeader ?? '').trim());
    if (retryAfterSeconds != null && retryAfterSeconds > 0) {
      // Add small buffer to avoid immediate re-throttle.
      return Duration(seconds: retryAfterSeconds + 1);
    }

    // Exponential backoff with light jitter, capped to keep UX responsive.
    final expMs = 700 * pow(2, attempt - 1).toInt();
    final jitterMs = Random().nextInt(350);
    final totalMs = min(expMs + jitterMs, 7000);
    return Duration(milliseconds: totalMs);
  }

  List<Map<String, String>> _parseShelfItemsJson(Map<String, dynamic> aiData) {
    List<dynamic>? raw;
    for (final key in ['items', 'detected_items', 'groceries', 'products']) {
      final v = aiData[key];
      if (v is List) {
        raw = v;
        break;
      }
    }
    raw ??= [];

    const blocked = <String>{
      'refrigerator',
      'fridge',
      'shelf',
      'rack',
      'drawer',
      'door',
      'container',
      'plastic',
      'glass',
      'unknown',
      'food',
      'item',
    };

    String normCat(String? c) {
      if (c == null) return 'Other';
      final s = c.trim();
      if (s.isEmpty) return 'Other';
      const allowed = [
        'Dairy',
        'Produce',
        'Beverages',
        'Condiments',
        'Eggs',
        'Bakery',
        'Frozen',
        'Snacks',
        'Meat',
        'Seafood',
        'Prepared foods',
        'Other',
      ];
      for (final a in allowed) {
        if (s.toLowerCase() == a.toLowerCase()) return a;
      }
      final low = s.toLowerCase();
      if (low.contains('dairy') || low.contains('milk') || low.contains('cheese')) {
        return 'Dairy';
      }
      if (low.contains('vegetable') ||
          low.contains('fruit') ||
          low.contains('produce')) {
        return 'Produce';
      }
      if (low.contains('drink') ||
          low.contains('juice') ||
          low.contains('beverage') ||
          low.contains('soda')) {
        return 'Beverages';
      }
      if (low.contains('egg')) return 'Eggs';
      if (low.contains('bread') || low.contains('bakery')) return 'Bakery';
      if (low.contains('frozen') || low.contains('ice cream')) return 'Frozen';
      if (low.contains('meat') || low.contains('poultry')) return 'Meat';
      if (low.contains('fish') || low.contains('seafood')) return 'Seafood';
      if (low.contains('snack')) return 'Snacks';
      if (low.contains('sauce') ||
          low.contains('condiment') ||
          low.contains('dressing')) {
        return 'Condiments';
      }
      if (low.contains('leftover') ||
          low.contains('meal') ||
          low.contains('prepared')) {
        return 'Prepared foods';
      }
      return 'Other';
    }

    String? pickName(Map<String, dynamic> m) {
      for (final k in ['name', 'item', 'product', 'label', 'title']) {
        final v = m[k];
        if (v != null) {
          final t = v.toString().trim();
          if (t.length >= 2 && t.length <= 56) return t;
        }
      }
      return null;
    }

    final out = <Map<String, String>>[];
    final seen = <String>{};
    for (final e in raw ?? []) {
      if (e is! Map) continue;
      final map = Map<String, dynamic>.from(e as Map);
      final name = pickName(map);
      if (name == null) continue;
      final key = name.toLowerCase();
      if (blocked.contains(key)) continue;
      if (seen.contains(key)) continue;
      seen.add(key);
      final cat = normCat(map['category']?.toString());
      out.add({
        'name': name,
        'category': cat,
      });
      if (out.length >= 18) break;
    }
    return out;
  }

  // Helper to clean and validate string values
  String _cleanValue(dynamic value) {
    if (value == null || value.toString().isEmpty) return 'Unknown';
    final str = value.toString().trim();
    if (str.isEmpty || str.toLowerCase() == 'unknown' || str.toLowerCase() == 'unable to determine') return 'Unknown';
    return str;
  }

  // Helper to validate detections
  List<dynamic> _validateDetections(dynamic detections) {
    if (detections == null || detections is! List) return [];
    return (detections as List).where((item) {
      if (item is! Map) return false;
      final label = item['label']?.toString().trim();
      return label != null && label.isNotEmpty;
    }).toList();
  }

  List<String> _sectionsFromDynamic(dynamic sections) {
    if (sections == null || sections is! List) return [];
    return (sections as List)
        .map((s) => s.toString().trim())
        .where((s) => s.isNotEmpty && s.toLowerCase() != 'unknown')
        .toList();
  }

  int? _parseDoorPanelCount(dynamic v) {
    if (v == null) return null;
    if (v is int && v >= 1 && v <= 4) return v;
    final n = int.tryParse(v.toString().trim());
    if (n == null || n < 1 || n > 4) return null;
    return n;
  }

  String? _cleanFreezerStyle(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim().toLowerCase();
    if (s.isEmpty || s == 'unknown') return null;
    const allowed = {'drawer', 'single_door', 'double_door', 'unknown'};
    if (allowed.contains(s)) return s;
    if (s.contains('drawer')) return 'drawer';
    if (s.contains('double')) return 'double_door';
    if (s.contains('single') || s.contains('one')) return 'single_door';
    return null;
  }

  /// Insulated swing doors on the fresh-food compartment (not freezer drawers).
  static int inferRefrigeratorDoorPanelCount(String type, String layoutType) {
    final t = '${type.trim()} ${layoutType.trim()}'.toLowerCase();
    final explicit = RegExp(
      r'(\d+)\s*[- ]?(?:door|doors)\b',
      caseSensitive: false,
    ).firstMatch(t);
    if (explicit != null) {
      final n = int.tryParse(explicit.group(1)!);
      if (n != null && n >= 1 && n <= 4) return n;
    }
    if (t.contains('side by side') || t.contains('side-by-side')) return 2;
    if (t.contains('french')) return 2;
    if (t.contains('four-door') ||
        t.contains('four door') ||
        t.contains('4-door') ||
        t.contains('4 door')) {
      return 2;
    }
    if (t.contains('triple') ||
        t.contains('three door') ||
        t.contains('3-door') ||
        t.contains('3 door')) {
      return 2;
    }
    if (t.contains('double door') ||
        t.contains('two door') ||
        t.contains('2 door') ||
        t.contains('2-door')) {
      return 2;
    }
    if (t.contains('single door') ||
        t.contains('one door') ||
        t.contains('1 door') ||
        t.contains('1-door')) {
      return 1;
    }
    if (t.contains('top freezer') ||
        t.contains('bottom freezer') ||
        t.contains('compact') ||
        t.contains('mini fridge')) {
      return 1;
    }
    return 0;
  }

  List<String> _defaultSectionsForInferredDoors(
    int inferred,
    String type,
    String layout,
  ) {
    if (inferred >= 2) {
      return [
        'Left Door',
        'Right Door',
        'Top Shelf',
        'Middle Shelf',
        'Bottom Shelf',
        'Crisper Drawer',
        'Freezer Drawer',
      ];
    }
    if (inferred == 1) {
      return [
        'Door',
        'Top Shelf',
        'Middle Shelf',
        'Bottom Shelf',
        'Crisper Drawer',
        'Freezer Drawer',
      ];
    }
    return ['Main Compartment', 'Freezer', 'Door pockets'];
  }

  static bool _hasLeftDoorWord(String s) =>
      RegExp(r'\bleft\b', caseSensitive: false).hasMatch(s);

  static bool _hasRightDoorWord(String s) =>
      RegExp(r'\bright\b', caseSensitive: false).hasMatch(s);

  static bool _hasMiddleDoorWord(String s) =>
      RegExp(r'\b(middle|center)\b', caseSensitive: false).hasMatch(s);

  static bool _looksLikeDoorLabel(String s) {
    final low = s.toLowerCase();
    if (!RegExp(r'\bdoor\b', caseSensitive: false).hasMatch(low)) {
      return false;
    }
    if (low.contains('drawer')) return false;
    if (low.contains('bin') ||
        low.contains('pocket') ||
        low.contains('guard') ||
        low.contains('rack')) {
      return false;
    }
    return true;
  }

  static bool _isAmbiguousDoorLabel(String s) {
    if (!_looksLikeDoorLabel(s)) return false;
    if (_hasLeftDoorWord(s) ||
        _hasRightDoorWord(s) ||
        _hasMiddleDoorWord(s)) {
      return false;
    }
    final low = s.trim().toLowerCase();
    if (low == 'door' || low == 'doors') return true;
    if (RegExp(r'^door\s*\d+\s*$', caseSensitive: false).hasMatch(low)) {
      return true;
    }
    if (low == 'refrigerator door' || low == 'fridge door') return true;
    return false;
  }

  List<String> _normalizeFridgeSections(
    List<String> raw, {
    required String type,
    required String layoutType,
    required int doorPanelHint,
  }) {
    final seen = <String>{};
    final list = <String>[];
    for (final s0 in raw) {
      final s = s0.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (s.isEmpty) continue;
      final key = s.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      list.add(_titleCaseWords(s));
    }

    var out = List<String>.from(list);

    void applyDoorNumberPattern() {
      for (var i = 0; i < out.length; i++) {
        final m = RegExp(r'^door\s*(\d+)\s*$', caseSensitive: false)
            .firstMatch(out[i].trim());
        if (m == null) continue;
        final d = int.tryParse(m.group(1)!) ?? -1;
        if (doorPanelHint == 2) {
          if (d == 1) out[i] = 'Left Door';
          if (d == 2) out[i] = 'Right Door';
        }
      }
    }

    applyDoorNumberPattern();

    final ambIdx = <int>[];
    for (var i = 0; i < out.length; i++) {
      if (_isAmbiguousDoorLabel(out[i])) ambIdx.add(i);
    }

    if (doorPanelHint == 2 && ambIdx.length == 2) {
      out[ambIdx[0]] = 'Left Door';
      out[ambIdx[1]] = 'Right Door';
    } else if (doorPanelHint == 1 && ambIdx.length == 1) {
      out[ambIdx[0]] = 'Door';
    } else if (doorPanelHint >= 2 && ambIdx.length > 2) {
      for (var k = 0; k < ambIdx.length; k++) {
        if (k == 0) {
          out[ambIdx[k]] = 'Left Door';
        } else if (k == 1) {
          out[ambIdx[k]] = 'Right Door';
        } else {
          out[ambIdx[k]] = 'Door ${k + 1}';
        }
      }
    } else if (doorPanelHint == 2 &&
        ambIdx.length == 1 &&
        !out.any(_hasLeftDoorWord) &&
        !out.any(_hasRightDoorWord)) {
      out[ambIdx[0]] = 'Left Door';
    }

    if (doorPanelHint == 1) {
      var doorLike = 0;
      for (final z in out) {
        if (_looksLikeDoorLabel(z)) doorLike++;
      }
      if (doorLike > 1) {
        final next = <String>[];
        var keptDoor = false;
        for (final z in out) {
          if (_looksLikeDoorLabel(z)) {
            if (!keptDoor) {
              next.add('Door');
              keptDoor = true;
            }
            continue;
          }
          next.add(z);
        }
        out = next;
      }
    }

    return out;
  }

  static String _titleCaseWords(String s) {
    return s
        .split(' ')
        .map((w) {
          if (w.isEmpty) return w;
          if (w.length == 1) return w.toUpperCase();
          final lower = w.substring(1).toLowerCase();
          return '${w[0].toUpperCase()}$lower';
        })
        .join(' ');
  }
}
