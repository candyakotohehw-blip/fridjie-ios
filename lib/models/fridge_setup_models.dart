import 'package:flutter/material.dart';

class DetectedObject {
  final String label;
  final Alignment alignment;
  final IconData icon;

  DetectedObject({
    required this.label,
    required this.alignment,
    this.icon = Icons.location_searching_rounded,
  });
}

class FridgeAnalysisResult {
  final String brand;
  final String model;
  final String color;
  final String type;
  final String capacity;
  final String dimensions;
  final String layoutType;
  final List<DetectedObject> detections;
  final List<String> sections;

  /// Swing doors on the fresh-food compartment (1–4). Null if not provided by AI.
  final int? refrigeratorDoorPanelCount;

  /// e.g. drawer, single_door, double_door — from vision model when available.
  final String? freezerAccessStyle;

  FridgeAnalysisResult({
    required this.brand,
    required this.model,
    required this.color,
    required this.type,
    required this.capacity,
    required this.dimensions,
    required this.layoutType,
    required this.detections,
    required this.sections,
    this.refrigeratorDoorPanelCount,
    this.freezerAccessStyle,
  });

  FridgeAnalysisResult copyWith({
    String? brand,
    String? model,
    String? color,
    String? type,
    String? capacity,
    String? dimensions,
    String? layoutType,
    List<DetectedObject>? detections,
    List<String>? sections,
    int? refrigeratorDoorPanelCount,
    String? freezerAccessStyle,
  }) {
    return FridgeAnalysisResult(
      brand: brand ?? this.brand,
      model: model ?? this.model,
      color: color ?? this.color,
      type: type ?? this.type,
      capacity: capacity ?? this.capacity,
      dimensions: dimensions ?? this.dimensions,
      layoutType: layoutType ?? this.layoutType,
      detections: detections ?? this.detections,
      sections: sections ?? this.sections,
      refrigeratorDoorPanelCount:
          refrigeratorDoorPanelCount ?? this.refrigeratorDoorPanelCount,
      freezerAccessStyle: freezerAccessStyle ?? this.freezerAccessStyle,
    );
  }

  factory FridgeAnalysisResult.fromJson(Map<String, dynamic> json) {
    final detectionsRaw = json['detections'] as List? ?? [];
    final detections = detectionsRaw.map((d) {
      final label = (d['label'] ?? 'Unknown').toString();
      final align = d['alignment'] as Map?;
      final x = (align?['x'] as num?)?.toDouble() ?? 0.0;
      final y = (align?['y'] as num?)?.toDouble() ?? 0.0;
      return DetectedObject(
        label: label,
        alignment: Alignment(x, y),
      );
    }).toList();

    final sections = (json['sections'] as List?)
            ?.map((s) => s.toString())
            .toList() ??
        ['Main', 'Freezer'];

    int? doorPanels;
    final rawDoor = json['refrigeratorDoorPanelCount'];
    if (rawDoor is int && rawDoor >= 1 && rawDoor <= 4) {
      doorPanels = rawDoor;
    } else if (rawDoor != null) {
      final p = int.tryParse(rawDoor.toString().trim());
      if (p != null && p >= 1 && p <= 4) doorPanels = p;
    }

    return FridgeAnalysisResult(
      brand: json['brand'] ?? 'Unknown',
      model: json['model'] ?? 'Unknown',
      color: json['color'] ?? 'Unknown',
      type: json['type'] ?? 'Unknown',
      capacity: json['capacity'] ?? 'Unknown',
      dimensions: json['dimensions'] ?? 'Unknown',
      layoutType: json['layoutType'] ?? 'Standard',
      detections: detections,
      sections: sections,
      refrigeratorDoorPanelCount: doorPanels,
      freezerAccessStyle: json['freezerAccessStyle']?.toString(),
    );
  }
}

class FridgeSetupConstants {
  static const List<Map<String, String>> testimonials = [
    {
      'text': '🌟 "Friji saved me from throwing away expired food! So smart!"',
      'author': '- Maria',
    },
    {
      'text': '💡 "Love how it suggests recipes based on what I have. Pure genius!"',
      'author': '- Juan',
    },
    {
      'text': '✨ "Finally know what\'s in my fridge. Game changer!"',
      'author': '- Ana',
    },
  ];

  static const List<String> setupMethods = ['Take a Photo', 'Upload from Gallery', 'Choose Manually'];

  static const Map<String, Alignment> layoutAnchors = {
    'Left Door': Alignment(-0.6, -0.3),
    'Right Door': Alignment(0.6, -0.3),
    'Main Compartment': Alignment(0, 0.2),
    'Freezer': Alignment(0, -0.8),
    'Vegetable Drawer': Alignment(0, 0.7),
    'Meat Shelf': Alignment(-0.4, 0.4),
    'Dairy Shelf': Alignment(0.4, 0.4),
  };
}
