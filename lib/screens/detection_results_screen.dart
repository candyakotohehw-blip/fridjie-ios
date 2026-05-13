import 'dart:io';
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import '../models/detection_result.dart';
import '../models/gemini_insights.dart';

class DetectionResultsScreen extends StatefulWidget {
  final DetectionResult detection;
  final GeminiInsights insights;
  final File imageFile;

  const DetectionResultsScreen({
    super.key,
    required this.detection,
    required this.insights,
    required this.imageFile,
  });

  @override
  State<DetectionResultsScreen> createState() => _DetectionResultsScreenState();
}

class _DetectionResultsScreenState extends State<DetectionResultsScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Results'),
        centerTitle: true,
        elevation: 0,
      ),
      body: PageView(
        controller: _pageController,
        children: [
          _buildDetectionPage(),
          _buildInsightsPage(),
          _buildImagePage(),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        color: Colors.grey[100],
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _navButton(0, Icons.scanner, 'Detection'),
            _navButton(1, Icons.lightbulb, 'Insights'),
            _navButton(2, Icons.image, 'Photo'),
          ],
        ),
      ),
    );
  }

  Widget _buildDetectionPage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header card
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFFB6C1),
                  const Color(0xFFFFC0CB).withOpacity(0.7),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🔍 Detection Results',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Powered by YOLOv8 (Local Inference)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Refrigerator Type
        _infoCard(
          icon: Icons.kitchen,
          title: 'Refrigerator Type',
          value: widget.detection.fridgeType,
          color: Colors.blue,
        ),

        // Number of Doors
        _infoCard(
          icon: Icons.door_front_door,
          title: 'Number of Doors',
          value: widget.detection.numDoors.toString(),
          color: Colors.orange,
        ),

        // Confidence Score
        _infoCard(
          icon: Icons.check_circle,
          title: 'Detection Confidence',
          value: '${(widget.detection.confidence * 100).toStringAsFixed(1)}%',
          color: Colors.green,
        ),

        const SizedBox(height: 24),

        // Detected Items
        Text(
          'Items Detected (${widget.detection.itemsDetected.length})',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),

        if (widget.detection.itemsDetected.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'No items detected',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.detection.itemsDetected
                .map(
                  (item) => Chip(
                    avatar: const Icon(Icons.check_circle, size: 18),
                    label: Text(item),
                    backgroundColor: Colors.blue[50],
                  ),
                )
                .toList(),
          ),

        const SizedBox(height: 24),

        // Raw JSON (for debugging)
        ExpansionTile(
          title: const Text('Debug Info'),
          subtitle: const Text('Technical details'),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                widget.detection.rawJson,
                style: const TextStyle(
                  color: Colors.green,
                  fontFamily: 'Courier',
                  fontSize: 12,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInsightsPage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  Colors.purple[400]!,
                  Colors.purple[200]!,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '✨ AI Insights',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Powered by Gemini 2.5 Flash',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Appliance Description
        _sectionCard(
          title: '🏠 Appliance Description',
          content: widget.insights.applianceDescription,
          icon: Icons.description,
        ),

        // Grocery Insights
        _sectionCard(
          title: '🛒 Grocery Insights',
          content: widget.insights.groceryInsights,
          icon: Icons.shopping_cart,
        ),

        // Recipe Recommendations
        _recipeCard(),

        // Storage Optimization
        _sectionCard(
          title: '📦 Storage Optimization',
          content: widget.insights.storageOptimization,
          icon: Icons.storage,
        ),

        const SizedBox(height: 16),
        Text(
          'Generated: ${widget.insights.generatedAt.toString().substring(0, 19)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _recipeCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: const Icon(Icons.restaurant, color: Colors.orange),
        title: const Text('🍳 Recipe Recommendations'),
        subtitle: Text('${widget.insights.recipeRecommendations.length} recipes'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: widget.insights.recipeRecommendations.isEmpty
                ? Text(
                    'No recipes found',
                    style:
                        Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: widget.insights.recipeRecommendations
                        .map(
                          (recipe) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('•',
                                    style: TextStyle(fontSize: 20)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(recipe),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  widget.imageFile,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Scanned Image',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        trailing: Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String content,
    required IconData icon,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.deepPurple),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _navButton(int index, IconData icon, String label) {
    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
