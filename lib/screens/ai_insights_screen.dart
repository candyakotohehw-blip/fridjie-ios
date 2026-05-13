import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/fridge_provider.dart';
import '../providers/language_provider.dart';
import '../models/recipe.dart';
import 'recipe_suggestions_screen.dart';

/// AI Insights hub: live stats from [FridgeProvider] plus ideas for future AI features.
class AiInsightsScreen extends StatelessWidget {
  const AiInsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lp = context.watch<LanguageProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(lp.translate('ai_insights')),
      ),
      body: Consumer<FridgeProvider>(
        builder: (context, fridge, _) {
          final activeItems = fridge.items.where((i) => !i.isConsumed && !i.isExpired()).length;
          final expiring = fridge.expiringItems.length;
          final expired = fridge.expiredItems.length;
          final groceryOpen = fridge.groceryItems.where((g) => !g.isPurchased).length;
          final suggestions = fridge.getSuggestedRecipes();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Text(
                lp.translate('insights_intro'),
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                lp.translate('insights_snapshot'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              _StatRow(
                children: [
                  _InsightStatTile(
                    icon: Icons.inventory_2_outlined,
                    label: lp.translate('insight_active_items'),
                    value: '$activeItems',
                    color: cs.primary,
                  ),
                  _InsightStatTile(
                    icon: Icons.schedule_outlined,
                    label: lp.translate('insight_expiring'),
                    value: '$expiring',
                    color: const Color(0xFFE67E22),
                  ),
                  _InsightStatTile(
                    icon: Icons.warning_amber_rounded,
                    label: lp.translate('insight_expired'),
                    value: '$expired',
                    color: const Color(0xFFE74C3C),
                  ),
                  _InsightStatTile(
                    icon: Icons.shopping_cart_outlined,
                    label: lp.translate('insight_grocery_open'),
                    value: '$groceryOpen',
                    color: const Color(0xFF9B59B6),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      lp.translate('insights_recipes_title'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RecipeSuggestionsScreen()),
                      );
                    },
                    child: Text(lp.translate('insights_open_recipes')),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (suggestions.isEmpty)
                _EmptyHintCard(
                  message: lp.translate('insights_no_recipes'),
                )
              else
                ...suggestions.take(5).map((Recipe r) => _RecipeMatchTile(recipe: r, fridge: fridge)),
              const SizedBox(height: 28),
              Text(
                lp.translate('insights_ideas_title'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                lp.translate('insights_ideas_sub'),
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              _IdeaChip(icon: Icons.trending_down_rounded, text: lp.translate('insights_idea_1')),
              _IdeaChip(icon: Icons.restaurant_rounded, text: lp.translate('insights_idea_2')),
              _IdeaChip(icon: Icons.qr_code_scanner_rounded, text: lp.translate('insights_idea_3')),
              _IdeaChip(icon: Icons.groups_outlined, text: lp.translate('insights_idea_4')),
            ],
          );
        },
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: children
          .map(
            (w) => SizedBox(
              width: (MediaQuery.sizeOf(context).width - 50) / 2,
              child: w,
            ),
          )
          .toList(),
    );
  }
}

class _InsightStatTile extends StatelessWidget {
  const _InsightStatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeMatchTile extends StatelessWidget {
  const _RecipeMatchTile({required this.recipe, required this.fridge});

  final Recipe recipe;
  final FridgeProvider fridge;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final names = fridge.items
        .where((i) => !i.isConsumed && !i.isExpired())
        .map((i) => i.name)
        .toList();
    final pct = recipe.getMatchPercentage(names).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Text(
            recipe.name,
            style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface),
          ),
          subtitle: Text(
            '${pct}% ${context.read<LanguageProvider>().translate('insights_match')}',
            style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600, fontSize: 12),
          ),
          trailing: Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RecipeSuggestionsScreen()),
            );
          },
        ),
      ),
    );
  }
}

class _EmptyHintCard extends StatelessWidget {
  const _EmptyHintCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Text(
        message,
        style: TextStyle(color: cs.onSurfaceVariant, height: 1.35),
      ),
    );
  }
}

class _IdeaChip extends StatelessWidget {
  const _IdeaChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: cs.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
