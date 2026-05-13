import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/fridge_item.dart';
import '../models/recipe.dart';
import '../models/grocery_item.dart';

class FridgeProvider extends ChangeNotifier {
  List<FridgeItem> _items = [];
  List<GroceryItem> _groceryItems = [];
  List<Recipe> _recipes = [];
  List<String> _configuredShelves = [];

  // Getters
  List<FridgeItem> get items => _items;
  List<GroceryItem> get groceryItems => _groceryItems;
  List<Recipe> get recipes => _recipes;
  List<String> get configuredShelves => List.unmodifiable(_configuredShelves);

  // Get items expiring soon
  List<FridgeItem> get expiringItems =>
      _items.where((item) => item.isExpiringSoon() && !item.isConsumed).toList()
        ..sort((a, b) => a.expirationDate.compareTo(b.expirationDate));

  // Get expired items
  List<FridgeItem> get expiredItems =>
      _items.where((item) => item.isExpired() && !item.isConsumed).toList();

  // Get items by category
  List<FridgeItem> getItemsByCategory(ItemCategory category) =>
      _items.where((item) => item.category == category && !item.isConsumed).toList();

  // Get items by shelf
  List<FridgeItem> getItemsByShelf(String shelf) =>
      _items.where((item) => item.shelf == shelf && !item.isConsumed).toList();

  void setConfiguredShelves(List<String> shelves) {
    final normalized = shelves
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    _configuredShelves = normalized;
    notifyListeners();
  }

  // Add item
  void addItem(String name, ItemCategory category, DateTime expirationDate,
      {String? quantity, String? shelf, String? notes, String? imageUrl}) {
    final newItem = FridgeItem(
      id: const Uuid().v4(),
      name: name,
      category: category,
      expirationDate: expirationDate,
      addedDate: DateTime.now(),
      quantity: quantity,
      shelf: shelf,
      notes: notes,
      imageUrl: imageUrl,
    );
    _items.add(newItem);
    notifyListeners();
  }

  // Update item
  void updateItem(FridgeItem item) {
    final index = _items.indexWhere((i) => i.id == item.id);
    if (index != -1) {
      _items[index] = item;
      notifyListeners();
    }
  }

  // Delete item
  void deleteItem(String itemId) {
    _items.removeWhere((item) => item.id == itemId);
    notifyListeners();
  }

  // Mark item as consumed
  void markAsConsumed(String itemId) {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(isConsumed: true);
      notifyListeners();
    }
  }

  // Grocery list methods
  void addGroceryItem(String name,
      {String? quantity, String? unit, double? estimatedPrice, String? category}) {
    final newItem = GroceryItem(
      id: const Uuid().v4(),
      name: name,
      quantity: quantity,
      unit: unit,
      estimatedPrice: estimatedPrice,
      dateAdded: DateTime.now(),
      category: category,
    );
    _groceryItems.add(newItem);
    notifyListeners();
  }

  void updateGroceryItem(GroceryItem item) {
    final index = _groceryItems.indexWhere((i) => i.id == item.id);
    if (index != -1) {
      _groceryItems[index] = item;
      notifyListeners();
    }
  }

  void deleteGroceryItem(String itemId) {
    _groceryItems.removeWhere((item) => item.id == itemId);
    notifyListeners();
  }

  void markGroceryAsCompleted(String itemId) {
    final index = _groceryItems.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _groceryItems[index] = _groceryItems[index].copyWith(isPurchased: true);
      notifyListeners();
    }
  }

  // Get suggested recipes based on available items
  List<Recipe> getSuggestedRecipes() {
    final fridgeItemNames = _items
        .where((item) => !item.isConsumed && !item.isExpired())
        .map((item) => item.name)
        .toList();

    final suggested = _recipes.where((recipe) {
      final matchPercentage = recipe.getMatchPercentage(fridgeItemNames);
      return matchPercentage >= 60; // Show recipes with 60% or more ingredients available
    }).toList();

    suggested.sort((a, b) {
      final aMatch = a.getMatchPercentage(fridgeItemNames);
      final bMatch = b.getMatchPercentage(fridgeItemNames);
      return bMatch.compareTo(aMatch);
    });

    return suggested;
  }

  // Add sample recipes
  void addSampleRecipes() {
    _recipes = [
      Recipe(
        id: '1',
        name: 'Simple Vegetable Salad',
        ingredients: [
          RecipeIngredient(name: 'lettuce', quantity: '2', unit: 'cups'),
          RecipeIngredient(name: 'tomato', quantity: '2', unit: 'pieces'),
          RecipeIngredient(name: 'cucumber', quantity: '1', unit: 'piece'),
        ],
        description: 'Fresh and healthy salad',
        servings: 2,
        prepTime: 10,
      ),
      Recipe(
        id: '2',
        name: 'Yogurt Smoothie',
        ingredients: [
          RecipeIngredient(name: 'yogurt', quantity: '1', unit: 'cup'),
          RecipeIngredient(name: 'banana', quantity: '1', unit: 'piece'),
          RecipeIngredient(name: 'milk', quantity: '1', unit: 'cup'),
        ],
        description: 'Quick breakfast smoothie',
        servings: 1,
        prepTime: 5,
      ),
    ];
    notifyListeners();
  }
}
