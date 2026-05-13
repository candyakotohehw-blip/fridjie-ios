import 'package:flutter/material.dart';

class ExpiringItemHorizontalCard extends StatelessWidget {
  final String name;
  final String category;
  final String quantity;
  final String daysLeft;
  final String emoji;
  final Color categoryColor;
  final VoidCallback onDelete;

  const ExpiringItemHorizontalCard({
    Key? key,
    required this.name,
    required this.category,
    required this.quantity,
    required this.daysLeft,
    required this.emoji,
    required this.categoryColor,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Colored Left Border
          Container(
            width: 4,
            height: 70,
            decoration: BoxDecoration(
              color: categoryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          // Image/Emoji
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: categoryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 38),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '$quantity • $category',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Days Left Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _getDaysLeftBgColor(daysLeft),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getDaysLeftIcon(daysLeft),
                  color: _getDaysLeftTextColor(daysLeft),
                  size: 18,
                ),
                const SizedBox(height: 2),
                Text(
                  daysLeft,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _getDaysLeftTextColor(daysLeft),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getDaysLeftBgColor(String daysLeft) {
    if (daysLeft.contains('0') || daysLeft.contains('expired')) {
      return Colors.red[50]!;
    } else if (daysLeft.contains('1') || daysLeft.contains('2')) {
      return Colors.orange[50]!;
    } else {
      return Colors.green[50]!;
    }
  }

  Color _getDaysLeftTextColor(String daysLeft) {
    if (daysLeft.contains('0') || daysLeft.contains('expired')) {
      return Colors.red[600]!;
    } else if (daysLeft.contains('1') || daysLeft.contains('2')) {
      return Colors.orange[600]!;
    } else {
      return Colors.green[600]!;
    }
  }

  IconData _getDaysLeftIcon(String daysLeft) {
    if (daysLeft.contains('0') || daysLeft.contains('expired')) {
      return Icons.warning_rounded;
    } else if (daysLeft.contains('1') || daysLeft.contains('2')) {
      return Icons.schedule;
    } else {
      return Icons.check_circle;
    }
  }
}

class LowStockItemCard extends StatelessWidget {
  final String name;
  final String emoji;
  final double stockPercentage;
  final Color stockColor;

  const LowStockItemCard({
    Key? key,
    required this.name,
    required this.emoji,
    required this.stockPercentage,
    required this.stockColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Product Image/Emoji
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 32),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Product Name
            Text(
              name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // Stock Bar
            Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: stockPercentage / 100,
                    minHeight: 6,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(stockColor),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${stockPercentage.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 10,
                    color: stockColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class TipOfTheDayCard extends StatelessWidget {
  final String tip;
  final String emoji;

  const TipOfTheDayCard({
    Key? key,
    required this.tip,
    required this.emoji,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFB6C1).withOpacity(0.15),
            Color(0xFFFFB6C1).withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFFFB6C1).withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFB6C1).withOpacity(0.3),
                  Color(0xFFFFB6C1).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tip for today',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFFFFB6C1),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tip,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
