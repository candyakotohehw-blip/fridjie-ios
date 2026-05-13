class GroceryItem {
  final String id;
  final String name;
  final String? quantity;
  final String? unit; // e.g., "kg", "pieces", "bottles"
  final double? estimatedPrice;
  final bool isPurchased;
  final DateTime dateAdded;
  final String? category;

  GroceryItem({
    required this.id,
    required this.name,
    this.quantity,
    this.unit,
    this.estimatedPrice,
    this.isPurchased = false,
    required this.dateAdded,
    this.category,
  });

  String getDisplayText() {
    String text = name;
    if (quantity != null) {
      text = '$quantity ${unit ?? ''} $name'.trim();
    }
    return text;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'estimatedPrice': estimatedPrice,
      'isPurchased': isPurchased,
      'dateAdded': dateAdded.toIso8601String(),
      'category': category,
    };
  }

  factory GroceryItem.fromJson(Map<String, dynamic> json) {
    return GroceryItem(
      id: json['id'],
      name: json['name'],
      quantity: json['quantity'],
      unit: json['unit'],
      estimatedPrice: json['estimatedPrice'],
      isPurchased: json['isPurchased'] ?? false,
      dateAdded: DateTime.parse(json['dateAdded']),
      category: json['category'],
    );
  }

  GroceryItem copyWith({
    String? id,
    String? name,
    String? quantity,
    String? unit,
    double? estimatedPrice,
    bool? isPurchased,
    DateTime? dateAdded,
    String? category,
  }) {
    return GroceryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      isPurchased: isPurchased ?? this.isPurchased,
      dateAdded: dateAdded ?? this.dateAdded,
      category: category ?? this.category,
    );
  }
}
