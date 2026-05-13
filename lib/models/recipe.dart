class Recipe {
  final String id;
  final String name;
  final List<RecipeIngredient> ingredients;
  final String? description;
  final int? servings;
  final int? prepTime; // in minutes
  final int? cookTime; // in minutes
  final List<String>? instructions;
  final String? imageUrl;
  final String? source;

  Recipe({
    required this.id,
    required this.name,
    required this.ingredients,
    this.description,
    this.servings,
    this.prepTime,
    this.cookTime,
    this.instructions,
    this.imageUrl,
    this.source,
  });

  // Calculate how many ingredients are available in fridge
  int getAvailableIngredientsCount(List<String> fridgeItems) {
    int count = 0;
    for (var ingredient in ingredients) {
      if (fridgeItems.any((item) =>
          item.toLowerCase().contains(ingredient.name.toLowerCase()))) {
        count++;
      }
    }
    return count;
  }

  // Get match percentage
  double getMatchPercentage(List<String> fridgeItems) {
    int available = getAvailableIngredientsCount(fridgeItems);
    return (available / ingredients.length) * 100;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ingredients': ingredients.map((e) => e.toJson()).toList(),
      'description': description,
      'servings': servings,
      'prepTime': prepTime,
      'cookTime': cookTime,
      'instructions': instructions,
      'imageUrl': imageUrl,
      'source': source,
    };
  }

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'],
      name: json['name'],
      ingredients: List<RecipeIngredient>.from(
        json['ingredients'].map((e) => RecipeIngredient.fromJson(e)),
      ),
      description: json['description'],
      servings: json['servings'],
      prepTime: json['prepTime'],
      cookTime: json['cookTime'],
      instructions: json['instructions'] != null
          ? List<String>.from(json['instructions'])
          : null,
      imageUrl: json['imageUrl'],
      source: json['source'],
    );
  }
}

class RecipeIngredient {
  final String name;
  final String? quantity;
  final String? unit; // e.g., "cups", "grams", "tbsp"

  RecipeIngredient({
    required this.name,
    this.quantity,
    this.unit,
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
      'name': name,
      'quantity': quantity,
      'unit': unit,
    };
  }

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      name: json['name'],
      quantity: json['quantity'],
      unit: json['unit'],
    );
  }
}
