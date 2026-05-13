import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/detection_result.dart';
import '../models/gemini_insights.dart';

class GeminiAIService {
  static final GeminiAIService _instance = GeminiAIService._internal();
  
  late GenerativeModel _model;
  bool _isInitialized = false;
  
  static const String _modelName = 'gemini-2.5-flash'; // Using Gemini 2.5 Flash

  factory GeminiAIService() {
    return _instance;
  }

  GeminiAIService._internal();

  // Initialize with API key
  void initialize({required String apiKey}) async {
    if (_isInitialized) return;

    _model = GenerativeModel(
      model: _modelName,
      apiKey: apiKey,
      safetySettings: [
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
      ],
    );

    _isInitialized = true;
    print('✅ Gemini AIService initialized');
    
    // Debug: List available models to find the right name
    try {
      print('🔍 Listing available models...');
      // Note: GenerativeModel doesn't have listModels, usually handled via rest or special client
      // For now, let's try a simple test call
      final test = await _model.generateContent([Content.text('hi')]);
      print('✅ Model test success: ${test.text != null}');
    } catch (e) {
      print('⚠️ Model test failed: $e');
    }
  }

  bool get isInitialized => _isInitialized;

  // Generate insights from detection result with retry logic
  Future<GeminiInsights> generateInsights(
    DetectionResult detection, {
    List<String>? additionalContext,
    int retryCount = 0,
  }) async {
    if (!_isInitialized) {
      throw Exception('GeminiAIService not initialized. Call initialize() first.');
    }

    try {
      final prompt = _buildPrompt(detection, additionalContext);
      
      // Use Gemini 1.5 Flash for testing
      final response = await _model.generateContent([
        Content.text(prompt),
      ]);

      if (response.text == null || response.text!.isEmpty) {
        throw Exception('Empty response from Gemini');
      }

      return GeminiInsights.fromGeminiResponse(response.text!);
    } catch (e) {
      // Handle Rate Limit (429) with exponential backoff
      if (e.toString().contains('429') && retryCount < 3) {
        final waitSeconds = (retryCount + 1) * 5;
        print('⚠️ Rate limited (429). Retrying in $waitSeconds seconds (Attempt ${retryCount + 1})...');
        await Future.delayed(Duration(seconds: waitSeconds));
        return generateInsights(detection, 
          additionalContext: additionalContext, 
          retryCount: retryCount + 1
        );
      }
      
      print('❌ Error generating insights: $e');
      rethrow;
    }
  }

  // Batch generate insights from multiple detection results
  Future<List<GeminiInsights>> batchGenerateInsights(
    List<DetectionResult> detections,
  ) async {
    final results = <GeminiInsights>[];

    for (final detection in detections) {
      try {
        final insights = await generateInsights(detection);
        results.add(insights);
      } catch (e) {
        print('⚠️ Skipped one detection due to: $e');
      }
    }

    return results;
  }

  // Custom prompt generation - only sends TEXT, never the image
  String _buildPrompt(
    DetectionResult detection,
    List<String>? additionalContext,
  ) {
    final buffer = StringBuffer();

    // Main detection data
    buffer.writeln('## Refrigerator Analysis');
    buffer.writeln('Type: ${detection.fridgeType}');
    buffer.writeln('Doors: ${detection.numDoors}');
    buffer.writeln('Detected Items: ${detection.itemsDetected.join(", ")}');
    buffer.writeln('Confidence: ${(detection.confidence * 100).toStringAsFixed(1)}%');
    buffer.writeln();

    // Additional context
    if (additionalContext != null && additionalContext.isNotEmpty) {
      buffer.writeln('## Additional Context');
      for (final context in additionalContext) {
        buffer.writeln('- $context');
      }
      buffer.writeln();
    }

    // Actual prompt
    buffer.writeln('''## Analysis Request

Based on the refrigerator details above, provide:

1. **Appliance Description** (2-3 sentences): Describe this refrigerator type and its typical use cases.

2. **Grocery Insights** (3-4 bullet points):
   - What items might be missing or low on stock
   - Expiration concerns for visible items
   - Freshness recommendations

3. **Recipe Recommendations** (3-5 recipes):
   - List recipes you can make with the detected items
   - Include a brief description

4. **Storage Optimization** (3-4 tips):
   - Best practices for storing the detected items
   - Organization tips for this fridge type
   - Temperature zones to optimize

Keep response concise and actionable. Focus on practical advice.''');

    return buffer.toString();
  }

  // Quick insight without full parsing (raw response)
  Future<String> getQuickInsight(DetectionResult detection) async {
    if (!_isInitialized) {
      throw Exception('GeminiAIService not initialized. Call initialize() first.');
    }

    try {
      final response = await _model.generateContent([
        Content.text(detection.toGeminiPrompt()),
      ]);

      return response.text ?? 'No response from Gemini';
    } catch (e) {
      print('❌ Error getting quick insight: $e');
      rethrow;
    }
  }
}
