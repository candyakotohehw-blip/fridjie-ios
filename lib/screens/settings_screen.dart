import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          langProvider.translate('settings'),
          style: const TextStyle(
            color: Color(0xFF1A2B4D),
            fontWeight: FontWeight.w900,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A2B4D)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Language & Region',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black45,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: LanguageProvider.supportedLanguages.map((lang) {
                bool isSelected = langProvider.currentLocale.languageCode == lang['code'];
                return ListTile(
                  onTap: () {
                    langProvider.setLanguage(lang['code']!);
                  },
                  leading: Text(lang['flag']!, style: const TextStyle(fontSize: 24)),
                  title: Text(
                    lang['name']!,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                      color: isSelected ? const Color(0xFF2D7DFF) : const Color(0xFF1A2B4D),
                    ),
                  ),
                  trailing: isSelected 
                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2D7DFF))
                    : null,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
