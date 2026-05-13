import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/fridge_item.dart';
import '../providers/fridge_provider.dart';
import '../utils/item_illustration.dart';

/// Shelf-style inventory (Friji mock): grouped by shelf, stock image thumbnails.
class FridgeInventoryTabScreen extends StatefulWidget {
  const FridgeInventoryTabScreen({super.key});

  @override
  State<FridgeInventoryTabScreen> createState() =>
      _FridgeInventoryTabScreenState();
}

class _FridgeInventoryTabScreenState extends State<FridgeInventoryTabScreen> {
  bool _shelfView = false;
  bool _landscapeRows = false;
  final Map<String, bool> _expandedShelf = {};

  static const _primaryBlue = Color(0xFF2D7DFF);

  String _scanCategoryLabel(ItemCategory c) {
    switch (c) {
      case ItemCategory.dairy:
        return 'Dairy';
      case ItemCategory.vegetables:
        return 'Produce';
      case ItemCategory.fruits:
        return 'Produce';
      case ItemCategory.beverages:
        return 'Beverages';
      case ItemCategory.condiments:
        return 'Condiments';
      case ItemCategory.bakery:
        return 'Bakery';
      case ItemCategory.frozen:
        return 'Frozen';
      case ItemCategory.meat:
        return 'Meat';
      case ItemCategory.pantry:
        return 'Pantry';
      case ItemCategory.other:
        return 'Other';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer<FridgeProvider>(
      builder: (context, fridge, _) {
        final active = fridge.items.where((e) => !e.isConsumed).toList();
        final byShelf = <String, List<FridgeItem>>{};
        for (final it in active) {
          final key = (it.shelf?.trim().isNotEmpty ?? false)
              ? it.shelf!.trim()
              : 'Rest of fridge';
          byShelf.putIfAbsent(key, () => []).add(it);
        }
        final shelfNames = <String>[
          ...fridge.configuredShelves,
          ...byShelf.keys.where((name) => !fridge.configuredShelves.contains(name)),
        ];

        if (shelfNames.isNotEmpty) {
          _expandedShelf.putIfAbsent(shelfNames.first, () => true);
        }

        return ColoredBox(
          color: isDark ? cs.surface : const Color(0xFFF4F7FC),
          child: SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Items',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: isDark ? cs.onSurface : const Color(0xFF1A2B4D),
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          "All the items in your fridge and more.",
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: isDark ? cs.onSurfaceVariant : Colors.black.withOpacity(0.45),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 76,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _storageChip(
                                selected: true,
                                icon: Icons.kitchen_outlined,
                                title: 'Primary Fridge',
                                count: active.length,
                              ),
                              _storageChip(
                                selected: false,
                                icon: Icons.kitchen_outlined,
                                title: 'Second Fridge',
                                count: 0,
                              ),
                              _storageChip(
                                selected: false,
                                icon: Icons.storefront_outlined,
                                title: 'Pantry',
                                count: 0,
                              ),
                              _storageChip(
                                selected: false,
                                icon: Icons.ac_unit_rounded,
                                title: 'Freezer',
                                count: 0,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: isDark ? cs.surfaceContainer : const Color(0xFFEEF2F8),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _viewToggleChip(
                                        label: 'List view',
                                        selected: !_shelfView,
                                        onTap: () =>
                                            setState(() => _shelfView = false),
                                      ),
                                    ),
                                    Expanded(
                                      child: _viewToggleChip(
                                        label: 'Shelf view',
                                        selected: _shelfView,
                                        onTap: () =>
                                            setState(() => _shelfView = true),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.sort_rounded, size: 18),
                              label: const Text('Sort'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isDark ? cs.onSurface : const Color(0xFF1A2B4D),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (!_shelfView)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: isDark ? cs.surfaceContainer : const Color(0xFFEEF2F8),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _modeChip(
                                    label: 'Portrait',
                                    selected: !_landscapeRows,
                                    onTap: () => setState(() => _landscapeRows = false),
                                  ),
                                  _modeChip(
                                    label: 'Landscape',
                                    selected: _landscapeRows,
                                    onTap: () => setState(() => _landscapeRows = true),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
                if (!_shelfView && shelfNames.isEmpty && active.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
                    sliver: SliverToBoxAdapter(child: _emptyState()),
                  )
                else if (!_shelfView)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    sliver: SliverList.separated(
                      itemCount: shelfNames.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final name = shelfNames[i];
                        final list = byShelf[name] ?? const <FridgeItem>[];
                        return _expandableShelfListSection(
                          shelfName: name,
                          list: list,
                        );
                      },
                    ),
                  )
                else if (shelfNames.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 20, 14, 24),
                    sliver: SliverToBoxAdapter(
                      child: _emptyState(),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 100),
                    sliver: SliverList.separated(
                      itemCount: shelfNames.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final name = shelfNames[i];
                        final list = byShelf[name] ?? const <FridgeItem>[];
                        return _shelfCard(name, list);
                      },
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 100),
                  sliver: SliverToBoxAdapter(
                    child: _addMissingCard(),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _viewToggleChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? _primaryBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: selected
                  ? Colors.white
                  : (Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.onSurface
                      : const Color(0xFF1A2B4D)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? _primaryBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _storageChip({
    required bool selected,
    required IconData icon,
    required String title,
    required int count,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Container(
        width: 124,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: isDark ? cs.surfaceContainerHigh : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? _primaryBlue
                : (isDark
                    ? cs.outlineVariant.withOpacity(0.55)
                    : Colors.black.withOpacity(0.08)),
            width: selected ? 1.8 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? _primaryBlue : Colors.black38,
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: selected ? _primaryBlue : const Color(0xFF1A2B4D),
                height: 1.15,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$count items',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark ? cs.onSurfaceVariant : Colors.black.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listRow(FridgeItem it, String url) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? cs.surfaceContainerHigh : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 52,
            height: 46,
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => ColoredBox(
                color: isDark ? cs.surfaceContainer : const Color(0xFFF4F7FC),
                child: Icon(Icons.inventory_2_outlined,
                    color: Colors.blue.shade200),
              ),
            ),
          ),
        ),
        title: Text(
          it.name,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: isDark ? cs.onSurface : const Color(0xFF1A2B4D),
          ),
        ),
        subtitle: Text(
          (it.quantity?.trim().isNotEmpty ?? false)
              ? it.quantity!.trim()
              : _scanCategoryLabel(it.category).toLowerCase(),
          style: TextStyle(
            fontSize: 12,
            color: isDark ? cs.onSurfaceVariant : Colors.black.withOpacity(0.45),
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Icon(Icons.more_vert_rounded, color: cs.onSurfaceVariant),
      ),
    );
  }

  Widget _expandableShelfListSection({
    required String shelfName,
    required List<FridgeItem> list,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final expanded = _expandedShelf[shelfName] ?? false;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? cs.outlineVariant.withOpacity(0.6)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              setState(() => _expandedShelf[shelfName] = !expanded);
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      shelfName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isDark ? cs.onSurface : const Color(0xFF1A2B4D),
                      ),
                    ),
                  ),
                  Text(
                    '${list.length} items',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: list.isEmpty
                  ? _emptyShelfInner()
                  : (_landscapeRows
                      ? SizedBox(
                          height: 118,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: list.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              final it = list[i];
                              final url = it.imageUrl ??
                                  ItemIllustration.urlFor(
                                    it.name,
                                    _scanCategoryLabel(it.category),
                                  );
                              return _shelfItemTile(it.name, url);
                            },
                          ),
                        )
                      : Column(
                          children: [
                            for (int i = 0; i < list.length; i++) ...[
                              _listRow(
                                list[i],
                                list[i].imageUrl ??
                                    ItemIllustration.urlFor(
                                      list[i].name,
                                      _scanCategoryLabel(list[i].category),
                                    ),
                              ),
                              if (i < list.length - 1)
                                const SizedBox(height: 4),
                            ],
                          ],
                        )),
            ),
        ],
      ),
    );
  }

  Widget _shelfCard(String shelfName, List<FridgeItem> list) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    shelfName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isDark ? cs.onSurface : const Color(0xFF1A2B4D),
                    ),
                  ),
                ),
                Text(
                  '${list.length} items',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? cs.onSurfaceVariant : Colors.black.withOpacity(0.4),
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: Colors.black.withOpacity(0.25)),
              ],
            ),
            const SizedBox(height: 8),
            if (list.isEmpty)
              _emptyShelfInner()
            else
              SizedBox(
                height: 118,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final it = list[i];
                    final url = it.imageUrl ??
                        ItemIllustration.urlFor(
                          it.name,
                          _scanCategoryLabel(it.category),
                        );
                    return _shelfItemTile(it.name, url);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _shelfItemTile(String name, String url) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 88,
      child: Column(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.inventory_2_outlined,
                  size: 40,
                  color: Colors.blue.shade100,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? cs.surfaceContainer : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? cs.outlineVariant.withOpacity(0.55)
                    : Colors.black.withOpacity(0.06),
              ),
            ),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isDark ? cs.onSurfaceVariant : Colors.black.withOpacity(0.52),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyShelfInner() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainer : const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? cs.outlineVariant.withOpacity(0.55)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Text(
        'This shelf is empty',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: isDark ? cs.onSurfaceVariant : Colors.black.withOpacity(0.35),
        ),
      ),
    );
  }

  Widget _emptyState() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? cs.outlineVariant.withOpacity(0.55)
              : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.kitchen_outlined, size: 48, color: Colors.blue.shade100),
          const SizedBox(height: 12),
          Text(
            'No items yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: isDark ? cs.onSurface : const Color(0xFF1A2B4D),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Finish fridge setup or add items to see them here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: isDark ? cs.onSurfaceVariant : Colors.black.withOpacity(0.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addMissingCard() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : const Color(0xFFF2F4FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? cs.outlineVariant.withOpacity(0.6)
              : Colors.black.withOpacity(0.04),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isDark ? cs.surfaceContainer : Colors.white,
            child: Icon(Icons.add_rounded, color: cs.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add missing items',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: isDark ? cs.onSurface : const Color(0xFF1A2B4D),
                  ),
                ),
                Text(
                  "Can't find something? Add it manually.",
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
        ],
      ),
    );
  }
}
