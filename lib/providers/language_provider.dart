import 'package:flutter/material.dart';

class LanguageProvider with ChangeNotifier {
  Locale _currentLocale = const Locale('en', 'US');

  Locale get currentLocale => _currentLocale;

  final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'welcome': 'Welcome to Friji! 👋',
      'hero_title_1': "Let's set up your",
      'hero_title_2': "smart fridge.",
      'hero_subtitle': 'Add your fridge to start tracking items and get smart reminders.',
      'setup_btn': 'Set Up Fridge',
      'setup_card_title': 'Set up your first fridge ✨',
      'setup_card_subtitle': 'Add your fridge to start tracking items, getting reminders, and reducing food waste.',
      'upload_photo': 'Upload a Photo',
      'upload_subtitle': "Upload a clear photo of your fridge and we'll detect it.",
      'take_photo': 'Take a Photo',
      'take_photo_subtitle': "Take a photo of your fridge and we'll detect the model for you.",
      'more_ways': 'More ways to add your fridge',
      'settings': 'Settings',
      'profile': 'My Profile',
      'alerts': 'Alerts',
      'ai_insights': 'AI Insights',
      'support': 'Support',
      'sign_out': 'Sign Out',
      'chef_hello': 'Hello, Chef!',
      'kitchen_welcome': 'Welcome to your smart kitchen',
      'ask_ai': 'ASK',
      // Stats Grid
      'total_items': 'Total Items',
      'expiring_soon': 'Expiring Soon',
      'grocery_needed': 'Grocery Needed',
      'fridge_health': 'Fridge Health',
      // Steps Section
      'quick_setup_guide': 'Quick Setup Guide',
      'step_1_title': 'Connect Fridge',
      'step_1_desc': 'Sync your smart fridge via Wi-Fi',
      'step_2_title': 'Scan Items',
      'step_2_desc': 'Take photos of your food items',
      'step_3_title': 'Set Alerts',
      'step_3_desc': 'Get notified before food expires',
      // Tips Section
      'smart_tip': 'SMART TIP',
      'tip_title': 'Keep your fridge organized',
      'tip_desc': 'Proper organization helps in reducing food waste and saves energy.',
      // Radial Menu
      'scan_qr': 'Scan QR',
      'add_item': 'Add Item',
      'fridge': 'Fridge',
      'grocery': 'Grocery',
      'recipes': 'Recipes',
      // Theme & insights
      'appearance': 'Appearance',
      'light_mode': 'Light',
      'dark_mode': 'Dark',
      'insights_intro':
          'Smart summaries from your fridge data. Connect more items for richer AI tips.',
      'insights_snapshot': "Today's snapshot",
      'insight_active_items': 'Active items',
      'insight_expiring': 'Expiring soon',
      'insight_expired': 'Expired',
      'insight_grocery_open': 'Grocery list (open)',
      'insights_recipes_title': 'Recipe match',
      'insights_open_recipes': 'See all',
      'insights_no_recipes': 'Add fridge items or recipes to see AI recipe matches.',
      'insights_match': 'ingredient match',
      'insights_ideas_title': 'What you can add here',
      'insights_ideas_sub':
          'Future AI modules can plug into this screen — examples:',
      'insights_idea_1': 'Weekly waste trend & estimated money saved',
      'insights_idea_2': 'Meal prep ideas built from items about to expire',
      'insights_idea_3': 'Barcode scan → nutrition & allergy hints',
      'insights_idea_4': 'Household sharing & diet goals per profile',
    },
    'tl': {
      'welcome': 'Maligayang pagdating sa Friji! 👋',
      'hero_title_1': "I-set up na natin ang iyong",
      'hero_title_2': "smart fridge.",
      'hero_subtitle': 'Idagdag ang iyong fridge para masimulan ang pag-track ng gamit at makakuha ng reminders.',
      'setup_btn': 'I-set up ang Fridge',
      'setup_card_title': 'I-set up ang iyong unang fridge ✨',
      'setup_card_subtitle': 'Idagdag ang iyong fridge para ma-track ang pagkain, reminders, at maiwasan ang tapon.',
      'upload_photo': 'Mag-upload ng Larawan',
      'upload_subtitle': "Mag-upload ng malinaw na larawan at kami na ang bahala.",
      'take_photo': 'Kumuha ng Larawan',
      'take_photo_subtitle': "Kunan ng litrato ang iyong fridge at de-detect namin ang model nito.",
      'more_ways': 'Iba pang paraan para magdagdag',
      'settings': 'Settings',
      'profile': 'Aking Profile',
      'alerts': 'Mga Babala',
      'ai_insights': 'AI Insights',
      'support': 'Suporta',
      'sign_out': 'Mag-sign Out',
      'chef_hello': 'Kamusta, Chef!',
      'kitchen_welcome': 'Welcome sa iyong smart kitchen',
      'ask_ai': 'MAG-ASK',
      // Stats Grid
      'total_items': 'Lahat ng Gamit',
      'expiring_soon': 'Malapit na Mapasó',
      'grocery_needed': 'Kailangang Bilhin',
      'fridge_health': 'Kalusugan ng Fridge',
      // Steps Section
      'quick_setup_guide': 'Gabay sa Mabilis na Pag-setup',
      'step_1_title': 'I-connect ang Fridge',
      'step_1_desc': 'I-sync ang fridge via Wi-Fi',
      'step_2_title': 'I-scan ang Pagkain',
      'step_2_desc': 'Kunan ng litrato ang mga pagkain',
      'step_3_title': 'Mag-set ng Alerts',
      'step_3_desc': 'Ma-notify bago mapaso ang pagkain',
      // Tips Section
      'smart_tip': 'SMART TIP',
      'tip_title': 'Panatilihing maayos ang fridge',
      'tip_desc': 'Ang maayos na pag-aayos ay nakakatulong para iwas-tapon at makatipid sa kuryente.',
      // Radial Menu
      'scan_qr': 'I-scan ang QR',
      'add_item': 'Magdagdag',
      'fridge': 'Fridge',
      'grocery': 'Grocery',
      'recipes': 'Resipe',
      'appearance': 'Hitsura / Theme',
      'light_mode': 'Light',
      'dark_mode': 'Dark',
      'insights_intro':
          'Mga smart summary mula sa data ng fridge mo. Mas maraming item, mas may insights.',
      'insights_snapshot': 'Snapshot ngayon',
      'insight_active_items': 'Aktibong items',
      'insight_expiring': 'Malapit na mapaso',
      'insight_expired': 'Lumampas na',
      'insight_grocery_open': 'Grocery (hindi pa tapos)',
      'insights_recipes_title': 'Recipe match',
      'insights_open_recipes': 'Tingnan lahat',
      'insights_no_recipes':
          'Magdagdag ng items o recipes para makita ang AI recipe matches.',
      'insights_match': 'match ng ingredients',
      'insights_ideas_title': 'Ano pa pwede ilagay dito',
      'insights_ideas_sub': 'Mga ideya para sa susunod na AI features:',
      'insights_idea_1': 'Lingguhang waste trend at tinatayang savings',
      'insights_idea_2': 'Meal prep mula sa malapit nang mapaso',
      'insights_idea_3': 'Barcode scan → nutrition at allergy hints',
      'insights_idea_4': 'Sharing sa household at diet goals per profile',
    },
    'es': {
      'welcome': '¡Bienvenido a Friji! 👋',
      'chef_hello': '¡Hola, Chef!',
      'settings': 'Configuración',
      'sign_out': 'Cerrar sesión',
      'setup_btn': 'Configurar nevera',
      'ask_ai': 'PREGUNTAR',
    },
    'ja': {
      'welcome': 'Frijiへようこそ！ 👋',
      'chef_hello': 'こんにちは、シェフ！',
      'settings': '設定',
      'sign_out': 'ログアウト',
      'setup_btn': '冷蔵庫をセットアップ',
      'ask_ai': '尋ねる',
    },
    // Add more languages as needed...
  };

  String translate(String key) {
    return _localizedValues[_currentLocale.languageCode]?[key] ?? _localizedValues['en']![key] ?? key;
  }

  void setLanguage(String languageCode) {
    _currentLocale = Locale(languageCode);
    notifyListeners();
  }

  static const List<Map<String, String>> supportedLanguages = [
    {'code': 'en', 'name': 'English', 'flag': '🇺🇸'},
    {'code': 'tl', 'name': 'Tagalog', 'flag': '🇵🇭'},
    {'code': 'es', 'name': 'Español', 'flag': '🇪🇸'},
    {'code': 'fr', 'name': 'Français', 'flag': '🇫🇷'},
    {'code': 'de', 'name': 'Deutsch', 'flag': '🇩🇪'},
    {'code': 'ja', 'name': '日本語', 'flag': '🇯🇵'},
    {'code': 'ko', 'name': '한국어', 'flag': '🇰🇷'},
    {'code': 'zh', 'name': '中文', 'flag': '🇨🇳'},
    {'code': 'ar', 'name': 'العربية', 'flag': '🇸🇦'},
    {'code': 'hi', 'name': 'हिन्दी', 'flag': '🇮🇳'},
  ];
}
