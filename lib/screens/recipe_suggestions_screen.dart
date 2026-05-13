import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/fridge_provider.dart';

class RecipeSuggestionsScreen extends StatelessWidget {
  const RecipeSuggestionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FridgeProvider>(
      builder: (context, fridgeProvider, _) {
        final suggestedRecipes = fridgeProvider.getSuggestedRecipes();
        final availableItems = fridgeProvider.items
            .where((item) => !item.isConsumed && !item.isExpired())
            .map((item) => item.name)
            .toList();

        if (suggestedRecipes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.restaurant_menu,
                  size: 80,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                const Text(
                  'No recipe suggestions yet! 🍳',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add more items to your fridge',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: suggestedRecipes.length,
          itemBuilder: (context, index) {
            final recipe = suggestedRecipes[index];
            final matchPercentage = recipe.getMatchPercentage(availableItems);
            final availableCount = recipe.getAvailableIngredientsCount(availableItems);
            final totalIngredients = recipe.ingredients.length;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Colors.grey[50]!,
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Recipe Header with Match Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  recipe.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$availableCount of $totalIngredients ingredients',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green[800],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: matchPercentage >= 80
                                  ? Colors.green
                                  : matchPercentage >= 60
                                      ? Colors.orange
                                      : Colors.grey,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '${matchPercentage.toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'Match',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Ingredients List
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ingredients:',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...recipe.ingredients.map((ingredient) {
                              final isAvailable = availableItems.any((item) =>
                                  item.toLowerCase()
                                      .contains(ingredient.name.toLowerCase()));

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isAvailable
                                            ? Colors.green
                                            : Colors.grey[300],
                                      ),
                                      child: Icon(
                                        isAvailable
                                            ? Icons.check
                                            : Icons.close,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        ingredient.getDisplayText(),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isAvailable
                                              ? Colors.black
                                              : Colors.grey[600],
                                          decoration: isAvailable
                                              ? TextDecoration.none
                                              : TextDecoration.lineThrough,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Recipe Details
                      if (recipe.description != null || recipe.prepTime != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue[200]!,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (recipe.description != null) ...[
                                Text(
                                  recipe.description!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.blue[900],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              Row(
                                children: [
                                  if (recipe.prepTime != null) ...[
                                    Icon(Icons.timer,
                                        size: 16, color: Colors.blue[700]),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Prep: ${recipe.prepTime}min',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                  ],
                                  if (recipe.servings != null) ...[
                                    Icon(Icons.people,
                                        size: 16, color: Colors.blue[700]),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${recipe.servings} servings',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),

                      // Missing Items Button
                      if (availableCount < totalIngredients)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _showMissingItemsDialog(
                                context,
                                recipe,
                                availableItems,
                              );
                            },
                            icon: const Icon(Icons.shopping_cart),
                            label: const Text('Add Missing Items to List'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.check_circle),
                            label: const Text('All Ingredients Available!'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showMissingItemsDialog(
    BuildContext context,
    dynamic recipe,
    List<String> availableItems,
  ) {
    final missingIngredients = recipe.ingredients
        .where((ing) =>
            !availableItems.any((item) =>
                item.toLowerCase().contains(ing.name.toLowerCase())))
        .toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Missing Ingredients'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: missingIngredients.map((ingredient) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        ingredient.getDisplayText(),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              for (var ingredient in missingIngredients) {
                context.read<FridgeProvider>().addGroceryItem(
                      ingredient.name,
                      quantity: ingredient.quantity,
                      unit: ingredient.unit,
                    );
              }
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Missing items added to shopping list!'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Add to Shopping'),
          ),
        ],
      ),
    );
  }
}
