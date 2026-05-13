import 'package:flutter/foundation.dart';

enum ItemCategory {
  vegetables,
  fruits,
  dairy,
  meat,
  bakery,
  condiments,
  beverages,
  frozen,
  pantry,
  other,
}

class FridgeItem {
  final String id;
  final String name;
  final ItemCategory category;
  final DateTime expirationDate;
  final DateTime addedDate;
  final String? quantity; // e.g., "500g", "2 bottles", "1 dozen"
  final String? shelf; // e.g., "Top shelf", "Door", "Bottom drawer"
  final String? notes;
  final String? imageUrl;
  bool isConsumed;

  FridgeItem({
    required this.id,
    required this.name,
    required this.category,
    required this.expirationDate,
    required this.addedDate,
    this.quantity,
    this.shelf,
    this.notes,
    this.imageUrl,
    this.isConsumed = false,
  });

  // Check if item is expiring soon (within 2 days)
  bool isExpiringSoon() {
    final now = DateTime.now();
    final difference = expirationDate.difference(now).inDays;
    return difference <= 2 && difference > 0;
  }

  // Check if item has expired
  bool isExpired() {
    return DateTime.now().isAfter(expirationDate);
  }

  // Days remaining
  int daysRemaining() {
    final now = DateTime.now();
    return expirationDate.difference(now).inDays;
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category.toString().split('.').last,
      'expirationDate': expirationDate.toIso8601String(),
      'addedDate': addedDate.toIso8601String(),
      'quantity': quantity,
      'shelf': shelf,
      'notes': notes,
      'imageUrl': imageUrl,
      'isConsumed': isConsumed,
    };
  }

  // Create from JSON
  factory FridgeItem.fromJson(Map<String, dynamic> json) {
    return FridgeItem(
      id: json['id'],
      name: json['name'],
      category: ItemCategory.values.firstWhere(
        (e) => e.toString().split('.').last == json['category'],
      ),
      expirationDate: DateTime.parse(json['expirationDate']),
      addedDate: DateTime.parse(json['addedDate']),
      quantity: json['quantity'],
      shelf: json['shelf'],
      notes: json['notes'],
      imageUrl: json['imageUrl'],
      isConsumed: json['isConsumed'] ?? false,
    );
  }

  // Copy with changes
  FridgeItem copyWith({
    String? id,
    String? name,
    ItemCategory? category,
    DateTime? expirationDate,
    DateTime? addedDate,
    String? quantity,
    String? shelf,
    String? notes,
    String? imageUrl,
    bool? isConsumed,
  }) {
    return FridgeItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      expirationDate: expirationDate ?? this.expirationDate,
      addedDate: addedDate ?? this.addedDate,
      quantity: quantity ?? this.quantity,
      shelf: shelf ?? this.shelf,
      notes: notes ?? this.notes,
      imageUrl: imageUrl ?? this.imageUrl,
      isConsumed: isConsumed ?? this.isConsumed,
    );
  }
}
