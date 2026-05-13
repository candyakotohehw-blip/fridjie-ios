import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../providers/fridge_provider.dart';
import '../models/fridge_item.dart';
import '../widgets/enhanced_item_cards.dart';
import 'add_item_screen.dart';
import 'recipe_suggestions_screen.dart';
import 'grocery_list_screen.dart';
import 'open_fridge_setup_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  // Colors
  static const Color frijiBlue = Color(0xFF4A90E2);
  static const Color backgroundLight = Color(0xFFFAFAFA);
  static const Color pinkSoft = Color(0xFFFFB6C1);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isQuickMenuOpen = false;
  late PageController _quoteController;
  late PageController _tipController;
  Timer? _quoteTimer;
  Timer? _tipTimer;
  int _quotePage = 0;
  int _tipPage = 0;

  @override
  void initState() {
    super.initState();
    _quoteController = PageController();
    _tipController = PageController();

    _startAutoSliders();

    Future.microtask(() {
      if (mounted) {
        context.read<FridgeProvider>().addSampleRecipes();
      }
    });
  }

  void _autoSlideQuotes() {
    if (!mounted || !_quoteController.hasClients) return;
    _quotePage = (_quotePage + 1) % 3;
    _quoteController.animateToPage(
      _quotePage,
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeInOut,
    );
  }

  void _autoSlideTips() {
    if (!mounted || !_tipController.hasClients) return;
    _tipPage = (_tipPage + 1) % 3;
    _tipController.animateToPage(
      _tipPage,
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeInOut,
    );
  }

  void _startAutoSliders() {
    _quoteTimer?.cancel();
    _tipTimer?.cancel();

    _quoteTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _autoSlideQuotes(),
    );
    _tipTimer = Timer.periodic(
      const Duration(seconds: 6),
      (_) => _autoSlideTips(),
    );
  }

  @override
  void dispose() {
    _quoteTimer?.cancel();
    _tipTimer?.cancel();
    _quoteController.dispose();
    _tipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeScreen.backgroundLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.black54),
            onPressed: () {},
          ),
        ),
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.ac_unit_rounded, color: HomeScreen.frijiBlue, size: 28),
            const SizedBox(width: 8),
            Text(
              'Friji',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: HomeScreen.frijiBlue,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: Stack(
              children: [
                const Icon(Icons.notifications_none_rounded, color: Colors.black54),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text('3', style: TextStyle(color: Colors.white, fontSize: 6, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 15),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: HomeScreen.frijiBlue.withOpacity(0.1),
              child: const Text('C',
                  style: TextStyle(
                      color: HomeScreen.frijiBlue,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Consumer<FridgeProvider>(
            builder: (context, fridgeProvider, _) {
              return _buildTabContent(fridgeProvider);
            },
          ),
          if (_isQuickMenuOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _isQuickMenuOpen = false),
                child: Container(color: Colors.black12),
              ),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _buildQuickFabMenu(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 10,
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem(0, Icons.home_rounded, 'Home'),
              _buildBottomNavItem(1, Icons.inventory_2_rounded, 'Inventory'),
              const SizedBox(width: 40),
              _buildBottomNavItem(2, Icons.restaurant_rounded, 'Recipes'),
              _buildBottomNavItem(3, Icons.shopping_cart_rounded, 'List'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(int index, IconData icon, String label) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedIndex = index;
        _isQuickMenuOpen = false;
      }),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? HomeScreen.frijiBlue : Colors.grey[400],
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? HomeScreen.frijiBlue : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(FridgeProvider fridgeProvider) {
    switch (_selectedIndex) {
      case 1:
        return _buildInventoryTab(fridgeProvider);
      case 2:
        return const RecipeSuggestionsScreen();
      case 3:
        return const GroceryListScreen();
      default:
        return _buildDashboardTab(fridgeProvider);
    }
  }

  Widget _buildDashboardTab(FridgeProvider fridgeProvider) {
    final items = fridgeProvider.items.where((item) => !item.isConsumed).toList();
    final expiringItems = fridgeProvider.expiringItems;
    final useSoonItems = items
        .where((item) => item.daysRemaining() > 2 && item.daysRemaining() <= 7)
        .toList();
    final freshItems = items
        .where((item) => !item.isExpired() && item.daysRemaining() > 7)
        .toList();

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '🧊',
              style: TextStyle(fontSize: 80),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your fridge is empty!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the + button to add items',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting & Mascot (Winter Pikachu)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Good morning,',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Master! ⚡',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: HomeScreen.frijiBlue,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Quote Swiper
                      SizedBox(
                        height: 40,
                        child: PageView(
                          controller: _quoteController,
                          children: [
                            Text(
                              'Here\'s what\'s happening in your fridge.',
                              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            ),
                            Text(
                              'Cooking is love made visible! 🍳',
                              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            ),
                            Text(
                              'Why did the tomato turn red? Because it saw the salad dressing! 🍅',
                              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.blue[100]!),
                  ),
                  child: Stack(
                    children: [
                      const Center(child: Text('❄️', style: TextStyle(fontSize: 40, color: Colors.blue))),
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: const Text('�', style: TextStyle(fontSize: 40)), // Pikachu substitute
                        ),
                      ),
                      const Positioned(
                        left: 10,
                        top: 20,
                        child: Text('🧊', style: TextStyle(fontSize: 25)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search items in your fridge...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400]),
                  suffixIcon: Icon(Icons.tune_rounded, color: Colors.grey[400]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                ),
              ),
            ),
          ),

          // Status Overview (Colorful Cards)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _StatusCard(
                    title: 'Expiring',
                    subtitle: '3 days',
                    count: expiringItems.length,
                    color: const Color(0xFFFFECEF),
                    textColor: const Color(0xFFFF5252),
                    icon: Icons.calendar_today_rounded,
                    hasAlert: expiringItems.isNotEmpty,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatusCard(
                    title: 'Use Soon',
                    subtitle: '7 days',
                    count: useSoonItems.length,
                    color: const Color(0xFFFFF7EB),
                    textColor: const Color(0xFFFFAB40),
                    icon: Icons.access_time_filled_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatusCard(
                    title: 'Fresh',
                    subtitle: '7+ days',
                    count: freshItems.length,
                    color: const Color(0xFFE8F5E9),
                    textColor: const Color(0xFF43A047),
                    icon: Icons.eco_rounded,
                  ),
                ),
              ],
            ),
          ),

          // Expiring Soon List
          if (expiringItems.isNotEmpty) ...[
            _buildSectionHeader('Expiring Soon', () {}),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: expiringItems.length.clamp(0, 3),
              itemBuilder: (context, index) {
                final item = expiringItems[index];
                return _HorizontalItemCard(item: item);
              },
            ),
          ],

          // Low Stock Swiper
          _buildSectionHeader('Low Stock', () {}),
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 15),
                  child: SizedBox(
                    width: 140,
                    child: _LowStockCard(item: item),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 25),

          // Tip Swiper (Modern Version)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              height: 120,
              child: PageView(
                controller: _tipController,
                children: [
                  _buildTipWidget(
                    'Tip for today',
                    'Keep your Greek yogurt on the middle shelf! 😋',
                    Icons.lightbulb_outline_rounded,
                  ),
                  _buildTipWidget(
                    'Cooking Quote',
                    'No one is born a great cook, one learns by doing. 👨‍🍳',
                    Icons.restaurant_menu_rounded,
                  ),
                  _buildTipWidget(
                    'Kitchen Joke',
                    'I\'m on a seafood diet. I see food and I eat it! 🐟',
                    Icons.emoji_emotions_outlined,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryTab(FridgeProvider fridgeProvider) {
    final activeItems = fridgeProvider.items.where((item) => !item.isConsumed).toList();
    final consumedItems = fridgeProvider.items.where((item) => item.isConsumed).toList();

    if (activeItems.isEmpty && consumedItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text('📦', style: TextStyle(fontSize: 70)),
            SizedBox(height: 12),
            Text(
              'No inventory items yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 6),
            Text(
              'Tap + and add your first item',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        if (activeItems.isNotEmpty) ...[
          const Text(
            'In Fridge',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ...activeItems.map((item) => _InventoryItemTile(item: item)),
          const SizedBox(height: 18),
        ],
        if (consumedItems.isNotEmpty) ...[
          const Text(
            'Consumed',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ...consumedItems.map((item) => _InventoryItemTile(item: item)),
        ],
      ],
    );
  }

  Widget _buildQuickFabMenu() {
    return Transform.translate(
      offset: const Offset(0, -40),
      child: SizedBox(
        width: 320,
        height: 360,
        child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            ..._buildMenuActions(),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              transform: Matrix4.identity()
                ..scale(_isQuickMenuOpen ? 1.05 : 1.0),
              child: FloatingActionButton(
                backgroundColor: HomeScreen.frijiBlue,
                elevation: 10,
                shape: const CircleBorder(),
                onPressed: () {
                  setState(() => _isQuickMenuOpen = !_isQuickMenuOpen);
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    _isQuickMenuOpen ? Icons.close_rounded : Icons.add_rounded,
                    key: ValueKey(_isQuickMenuOpen),
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMenuActions() {
    if (!_isQuickMenuOpen) return const [];
    return [
      _buildRadialAction(
        action: const _FabMenuAction(
          Icons.qr_code_scanner_rounded,
          'Scan Barcode',
        ),
        color: const Color(0xFF7A5CFA),
        dx: -78,
        dy: -145,
      ),
      _buildRadialAction(
        action: const _FabMenuAction(
          Icons.playlist_add_circle_rounded,
          'Add Item',
        ),
        color: const Color(0xFF4A90E2),
        dx: 0,
        dy: -175,
      ),
      _buildRadialAction(
        action: const _FabMenuAction(
          Icons.kitchen_rounded,
          'Open Fridge',
        ),
        color: const Color(0xFF00B894),
        dx: 78,
        dy: -145,
      ),
      _buildRadialAction(
        action: const _FabMenuAction(
          Icons.shopping_cart_checkout_rounded,
          'Grocery',
        ),
        color: const Color(0xFFFF9F43),
        dx: -68,
        dy: -70,
      ),
      _buildRadialAction(
        action: const _FabMenuAction(
          Icons.restaurant_menu_rounded,
          'Recipes',
        ),
        color: const Color(0xFFFF6B9A),
        dx: 68,
        dy: -70,
      ),
    ];
  }

  Widget _buildRadialAction({
    required _FabMenuAction action,
    required Color color,
    required double dx,
    required double dy,
  }) {
    return Transform.translate(
      offset: Offset(dx, dy),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () => _onQuickActionTap(action.label),
          child: SizedBox(
              width: 68,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withOpacity(0.22)),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.28),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(action.icon, color: color, size: 28),
                ),
                const SizedBox(height: 6),
                Text(
                  action.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onQuickActionTap(String label) async {
    setState(() => _isQuickMenuOpen = false);

    if (label == 'Add Item') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const AddItemScreen(),
        ),
      );
      return;
    }

    if (label == 'Scan' || label == 'Scan Barcode') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barcode scanner will be added soon')),
      );
      return;
    }

    if (label == 'Fridge' || label == 'Open Fridge') {
      final done = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => const OpenFridgeSetupScreen(),
        ),
      );
      if (!mounted) return;
      if (done == true) {
        setState(() => _selectedIndex = 1);
      }
      return;
    }

    if (label == 'Recipes') {
      setState(() => _selectedIndex = 2);
      return;
    }

    if (label == 'Grocery' || label == 'Grocery List') {
      setState(() => _selectedIndex = 3);
      return;
    }

    if (label == 'Inventory') {
      setState(() => _selectedIndex = 1);
    }
  }

  Widget _buildTipWidget(String title, String content, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F6FF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: HomeScreen.frijiBlue.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: HomeScreen.frijiBlue.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(icon, color: HomeScreen.frijiBlue, size: 25),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: HomeScreen.frijiBlue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  content,
                  style: TextStyle(
                    color: HomeScreen.frijiBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onSeeAll) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          TextButton(
            onPressed: onSeeAll,
            child: Row(
              children: [
                Text('See all',
                    style: TextStyle(
                        color: HomeScreen.frijiBlue,
                        fontWeight: FontWeight.bold)),
                const Icon(Icons.chevron_right_rounded,
                    color: HomeScreen.frijiBlue, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final String emoji;
  final bool isActive;

  const _CategoryChip({
    required this.label,
    required this.emoji,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? HomeScreen.pinkSoft : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if (!isActive)
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.black87,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final int count;
  final Color color;
  final Color textColor;
  final IconData icon;
  final bool hasAlert;

  const _StatusCard({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.color,
    required this.textColor,
    required this.icon,
    this.hasAlert = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textColor.withOpacity(0.1)),
      ),
      child: Stack(
        children: [
          if (hasAlert)
            Positioned(
              right: 0,
              top: 0,
              child: Icon(Icons.error_outline_rounded, color: textColor, size: 14),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: textColor.withOpacity(0.8), size: 20),
              const SizedBox(height: 8),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 9, color: Colors.grey[600], fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FabMenuAction {
  final IconData icon;
  final String label;

  const _FabMenuAction(this.icon, this.label);
}

class _InventoryItemTile extends StatelessWidget {
  final FridgeItem item;

  const _InventoryItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final daysLeft = item.daysRemaining();
    final expired = item.isExpired();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_rounded, color: HomeScreen.frijiBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.category.name} • ${item.quantity ?? 'No quantity'}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: expired ? const Color(0xFFFFECEC) : const Color(0xFFEFF7FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              expired ? 'Expired' : '$daysLeft d left',
              style: TextStyle(
                color: expired ? Colors.redAccent : HomeScreen.frijiBlue,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HorizontalItemCard extends StatelessWidget {
  final FridgeItem item;

  const _HorizontalItemCard({required this.item});

  String _getFoodEmoji(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('tomato')) return '🍅';
    if (lowerName.contains('milk')) return '🥛';
    if (lowerName.contains('egg')) return '🥚';
    if (lowerName.contains('cheese')) return '🧀';
    if (lowerName.contains('chicken')) return '🍗';
    if (lowerName.contains('beef') || lowerName.contains('meat')) return '🥩';
    if (lowerName.contains('bread')) return '🍞';
    if (lowerName.contains('apple')) return '🍎';
    if (lowerName.contains('banana')) return '🍌';
    if (lowerName.contains('orange')) return '🍊';
    if (lowerName.contains('carrot')) return '🥕';
    if (lowerName.contains('lettuce')) return '🥬';
    if (lowerName.contains('yogurt')) return '🍦';
    if (lowerName.contains('water') || lowerName.contains('drink')) return '💧';
    if (lowerName.contains('soda') || lowerName.contains('coke')) return '🥤';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final emoji = _getFoodEmoji(item.name);
    final daysLeft = item.daysRemaining();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
                child: Text(emoji.isNotEmpty ? emoji : '📦',
                    style: const TextStyle(fontSize: 30))),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '${item.quantity ?? "100g"} • ${item.category.toString().split('.').last}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, color: Colors.redAccent, size: 14),
                const SizedBox(width: 4),
                Text(
                  '$daysLeft day left',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        ],
      ),
    );
  }
}

class _LowStockCard extends StatelessWidget {
  final FridgeItem item;

  const _LowStockCard({required this.item});

  String _getFoodEmoji(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('tomato')) return '🍅';
    if (lowerName.contains('milk')) return '🥛';
    if (lowerName.contains('egg')) return '🥚';
    if (lowerName.contains('cheese')) return '🧀';
    if (lowerName.contains('chicken')) return '🍗';
    if (lowerName.contains('beef') || lowerName.contains('meat')) return '🥩';
    if (lowerName.contains('bread')) return '🍞';
    if (lowerName.contains('apple')) return '🍎';
    if (lowerName.contains('banana')) return '🍌';
    if (lowerName.contains('orange')) return '🍊';
    if (lowerName.contains('carrot')) return '🥕';
    if (lowerName.contains('lettuce')) return '🥬';
    if (lowerName.contains('yogurt')) return '🍦';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final emoji = _getFoodEmoji(item.name);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(emoji.isNotEmpty ? emoji : '📦',
                    style: const TextStyle(fontSize: 40)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.name,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 45,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.2,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Text('Low',
                  style: TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
