import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/fridge_item.dart';

class ItemCard extends StatelessWidget {
  final FridgeItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onConsume;

  const ItemCard({
    Key? key,
    required this.item,
    required this.onTap,
    required this.onDelete,
    required this.onConsume,
  }) : super(key: key);

  Color _getCategoryColor(ItemCategory category) {
    switch (category) {
      case ItemCategory.vegetables:
        return Colors.green;
      case ItemCategory.fruits:
        return Colors.orange;
      case ItemCategory.dairy:
        return Colors.blue;
      case ItemCategory.meat:
        return Colors.red;
      case ItemCategory.bakery:
        return Colors.brown;
      case ItemCategory.condiments:
        return Colors.amber;
      case ItemCategory.beverages:
        return Colors.cyan;
      case ItemCategory.frozen:
        return Colors.lightBlue;
      case ItemCategory.pantry:
        return Colors.grey;
      case ItemCategory.other:
        return Colors.blueGrey;
    }
  }

  String _getExpirationText() {
    final daysLeft = item.daysRemaining();
    if (item.isExpired()) {
      return 'Expired';
    } else if (daysLeft == 0) {
      return 'Expires today';
    } else if (daysLeft == 1) {
      return 'Expires tomorrow';
    } else {
      return 'Expires in $daysLeft days';
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = _getCategoryColor(item.category);
    final isExpiringSoon = item.isExpiringSoon();
    final isExpired = item.isExpired();

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(
                color: isExpired
                    ? Colors.red
                    : isExpiringSoon
                        ? Colors.orange
                        : categoryColor,
                width: 4,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (item.quantity != null)
                            Text(
                              'Quantity: ${item.quantity}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          if (item.shelf != null)
                            Text(
                              'Shelf: ${item.shelf}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                    PopupMenuButton(
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          child: const Text('Mark as Consumed'),
                          onTap: onConsume,
                        ),
                        PopupMenuItem(
                          child: const Text('Delete'),
                          onTap: onDelete,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _getExpirationText(),
                  style: TextStyle(
                    fontSize: 12,
                    color: isExpired
                        ? Colors.red
                        : isExpiringSoon
                            ? Colors.orange
                            : Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.notes != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Note: ${item.notes}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
