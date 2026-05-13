// Detection result from YOLOv8 model
class DetectionResult {
  final String fridgeType; // e.g., "French Door", "Side-by-Side", "Top Freezer"
  final int numDoors; // Number of visible doors
  final List<String> itemsDetected; // Items visible in fridge (e.g., ["milk", "eggs", "juice"])
  final double confidence; // Overall confidence score (0-1)
  final String rawJson; // Raw YOLO output for debugging

  DetectionResult({
    required this.fridgeType,
    required this.numDoors,
    required this.itemsDetected,
    required this.confidence,
    required this.rawJson,
  });

  // Convert detection to structured text for Gemini
  String toGeminiPrompt() {
    return '''User has scanned their refrigerator with these details:

Refrigerator Type: $fridgeType
Number of Doors: $numDoors
Visible Items: ${itemsDetected.join(", ")}
Detection Confidence: ${(confidence * 100).toStringAsFixed(1)}%

Please provide:
1. Brief appliance description
2. Smart grocery insights (what items might be missing, expiration concerns)
3. Recipe recommendations based on detected items
4. Storage optimization tips for this fridge type''';
  }

  @override
  String toString() =>
      'DetectionResult(type: $fridgeType, doors: $numDoors, items: ${itemsDetected.length}, confidence: ${(confidence * 100).toStringAsFixed(1)}%)';
}
