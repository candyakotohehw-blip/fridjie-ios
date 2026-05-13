/// High-quality stock-style food images (not camera crops) for UI polish.
/// Uses Unsplash CDN — stable photo IDs, `w` limits bandwidth.
class ItemIllustration {
  ItemIllustration._();

  static const _q = 'auto=format&fit=crop&w=480&q=85';

  static final Map<String, String> _keyword = {
    'milk': 'https://images.unsplash.com/photo-1563636619-e914064ffa1f?$_q',
    'orange': 'https://images.unsplash.com/photo-1547514701-42782101795e?$_q',
    'apple': 'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?$_q',
    'banana': 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?$_q',
    'egg': 'https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?$_q',
    'cheese': 'https://images.unsplash.com/photo-1486297678162-eb2a19b0a32d?$_q',
    'butter': 'https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?$_q',
    'yogurt': 'https://images.unsplash.com/photo-1488477181946-6428a0291777?$_q',
    'ketchup': 'https://images.unsplash.com/photo-1594221708779-94832f4320d1?$_q',
    'juice': 'https://images.unsplash.com/photo-1600271886742-f049cd451bba?$_q',
    'soda': 'https://images.unsplash.com/photo-1622483767028-3f66f32a67b1?$_q',
    'water': 'https://images.unsplash.com/photo-1548839140-29a749e1cf4d?$_q',
    'bread': 'https://images.unsplash.com/photo-1509440159596-0249088772ff?$_q',
    'strawber': 'https://images.unsplash.com/photo-1464965911861-746a04b4bca6?$_q',
    'blueber': 'https://images.unsplash.com/photo-1498557850523-fd3d118b962e?$_q',
    'tomato': 'https://images.unsplash.com/photo-1546470427-e26264900401?$_q',
    'lettuce': 'https://images.unsplash.com/photo-1622206151226-18ca2c9ab4a1?$_q',
    'chicken': 'https://images.unsplash.com/photo-1604503468506-a8da13d82791?$_q',
    'fish': 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?$_q',
    'pasta': 'https://images.unsplash.com/photo-1621996346565-e3dbc646d9a9?$_q',
    'rice': 'https://images.unsplash.com/photo-1586201375761-83865001e31c?$_q',
    'chocolate': 'https://images.unsplash.com/photo-1511381939415-e44015466834?$_q',
    'coffee': 'https://images.unsplash.com/photo-1497935586351-b67a49e012bf?$_q',
    'wine': 'https://images.unsplash.com/photo-1510812431401-41d2bd2722f3?$_q',
    'beer': 'https://images.unsplash.com/photo-1608270586620-248524c67de9?$_q',
    'carrot': 'https://images.unsplash.com/photo-1598170845058-32b9d6a5da37?$_q',
    'potato': 'https://images.unsplash.com/photo-1518977676601-b53f82aba655?$_q',
    'onion': 'https://images.unsplash.com/photo-1618512496249-a7728e377fbe?$_q',
    'lemon': 'https://images.unsplash.com/photo-1590502593741-5a536f866a6a?$_q',
    'grape': 'https://images.unsplash.com/photo-1599819177626-5a4d5e8e0c4a?$_q',
    'meat': 'https://images.unsplash.com/photo-1603048297172-c92544798d5a?$_q',
    'pizza': 'https://images.unsplash.com/photo-1513104890138-7c749659a591?$_q',
    'ice cream': 'https://images.unsplash.com/photo-1560008581-09826d1de69e?$_q',
    'honey': 'https://images.unsplash.com/photo-1587049352846-4a222e2d8144?$_q',
    'jam': 'https://images.unsplash.com/photo-1587735243475-4fe412a9d1f2?$_q',
  };

  static final Map<String, String> _category = {
    'dairy': 'https://images.unsplash.com/photo-1628088068124-f35829a08019?$_q',
    'produce': 'https://images.unsplash.com/photo-1610832958506-aa563681feac?$_q',
    'beverages': 'https://images.unsplash.com/photo-1437418747212-8d9709afab22?$_q',
    'condiments': 'https://images.unsplash.com/photo-1594221708779-94832f4320d1?$_q',
    'eggs': 'https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?$_q',
    'bakery': 'https://images.unsplash.com/photo-1509440159596-0249088772ff?$_q',
    'frozen': 'https://images.unsplash.com/photo-1560008581-09826d1de69e?$_q',
    'snacks': 'https://images.unsplash.com/photo-1621939514649-280e2ee25f60?$_q',
    'meat': 'https://images.unsplash.com/photo-1603048297172-c92544798d5a?$_q',
    'seafood': 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?$_q',
    'prepared foods': 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?$_q',
    'other': 'https://images.unsplash.com/photo-1542838132-92c53300491e?$_q',
  };

  /// Public URL for list / review thumbnails (not from user scan).
  static String urlFor(String name, String category) {
    final n = name.toLowerCase();
    for (final e in _keyword.entries) {
      if (n.contains(e.key)) return e.value;
    }
    final c = category.toLowerCase().trim();
    return _category[c] ?? _category['other']!;
  }
}
