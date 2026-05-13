import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/fridge_provider.dart';
import 'providers/language_provider.dart';
import 'providers/theme_provider.dart';
import 'theme/app_themes.dart';
import 'screens/new_user_dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeProvider = ThemeProvider();
  await themeProvider.load();
  runApp(FridgeApp(themeProvider: themeProvider));
}

class FridgeApp extends StatelessWidget {
  const FridgeApp({super.key, required this.themeProvider});

  final ThemeProvider themeProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider(create: (_) => FridgeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          return MaterialApp(
            title: 'Friji - Fridge Tracker',
            debugShowCheckedModeBanner: false,
            themeMode: theme.themeMode,
            theme: AppThemes.light,
            darkTheme: AppThemes.dark,
            home: const NewUserDashboardScreen(),
          );
        },
      ),
    );
  }
}
