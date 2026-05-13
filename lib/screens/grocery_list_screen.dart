import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/fridge_provider.dart';

class GroceryListScreen extends StatefulWidget {
  const GroceryListScreen({super.key});

  @override
  State<GroceryListScreen> createState() => _GroceryListScreenState();
}

class _GroceryListScreenState extends State<GroceryListScreen> {
  late TextEditingController _itemNameController;

  @override
  void initState() {
    super.initState();
    _itemNameController = TextEditingController();
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    super.dispose();
  }

  void _addGroceryItem() {
    if (_itemNameController.text.isNotEmpty) {
      context.read<FridgeProvider>().addGroceryItem(
            _itemNameController.text,
          );
      _itemNameController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Item added to shopping list'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FridgeProvider>(
      builder: (context, fridgeProvider, _) {
        final pendingItems =
            fridgeProvider.groceryItems.where((item) => !item.isPurchased).toList();
        final completedItems =
            fridgeProvider.groceryItems.where((item) => item.isPurchased).toList();

        return Scaffold(
          body: Column(
            children: [
              // Add Item Input Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.deepOrange,
                      Colors.orange[400]!,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What do you need to buy?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _itemNameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'e.g., Milk, Eggs, Vegetables',
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.2),
                              prefixIcon: Icon(
                                Icons.shopping_cart,
                                color: Colors.white.withOpacity(0.7),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: (_) => _addGroceryItem(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          child: FloatingActionButton(
                            mini: true,
                            onPressed: _addGroceryItem,
                            backgroundColor: Colors.white.withOpacity(0.3),
                            elevation: 0,
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // List
              Expanded(
                child: pendingItems.isEmpty && completedItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_bag,
                              size: 80,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Shopping list is empty! 🛒',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Add items to start shopping',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            // Pending Items
                            if (pendingItems.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.orange[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.checklist,
                                        color: Colors.orange[700],
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'To Buy (${pendingItems.length})',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: pendingItems.length,
                                  itemBuilder: (context, index) {
                                    final item = pendingItems[index];
                                    return Dismissible(
                                      key: Key(item.id),
                                      onDismissed: (_) =>
                                          fridgeProvider.deleteGroceryItem(item.id),
                                      background: Container(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.only(right: 16),
                                        child: const Icon(
                                          Icons.delete,
                                          color: Colors.white,
                                        ),
                                      ),
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Colors.grey[200]!,
                                          ),
                                        ),
                                        child: CheckboxListTile(
                                          value: false,
                                          activeColor: Colors.green,
                                          onChanged: (_) =>
                                              fridgeProvider.markGroceryAsCompleted(
                                                item.id,
                                              ),
                                          title: Text(
                                            item.getDisplayText(),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          subtitle: item.estimatedPrice != null
                                              ? Text(
                                                  '₱${item.estimatedPrice!.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                )
                                              : null,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            // Completed Items
                            if (completedItems.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.green[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.check_circle,
                                        color: Colors.green[700],
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Purchased (${completedItems.length})',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: completedItems.length,
                                  itemBuilder: (context, index) {
                                    final item = completedItems[index];
                                    return Dismissible(
                                      key: Key(item.id),
                                      onDismissed: (_) =>
                                          fridgeProvider.deleteGroceryItem(item.id),
                                      background: Container(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.only(right: 16),
                                        child: const Icon(
                                          Icons.delete,
                                          color: Colors.white,
                                        ),
                                      ),
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Colors.grey[200]!,
                                          ),
                                        ),
                                        child: CheckboxListTile(
                                          value: true,
                                          activeColor: Colors.green,
                                          onChanged: (_) =>
                                              fridgeProvider.markGroceryAsCompleted(
                                                item.id,
                                              ),
                                          title: Text(
                                            item.getDisplayText(),
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                              decoration:
                                                  TextDecoration.lineThrough,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
