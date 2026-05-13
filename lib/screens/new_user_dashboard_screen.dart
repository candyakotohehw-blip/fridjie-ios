import 'package:flutter/material.dart';
import 'dart:async';
import 'open_fridge_setup_screen.dart';
import 'add_item_screen.dart';
import 'recipe_suggestions_screen.dart';
import 'fridge_inventory_tab_screen.dart';
import 'grocery_list_screen.dart';
import 'settings_screen.dart'; // Add this
import 'ai_insights_screen.dart';
import '../providers/theme_provider.dart';
import '../services/ai_assistant_service.dart';
import '../widgets/ai_assistant_overlay.dart';
import '../widgets/siri_waveform_overlay.dart';
import 'package:provider/provider.dart';
import '../services/fridge_analysis_service.dart';
import '../providers/language_provider.dart'; // Add this

class NewUserDashboardScreen extends StatefulWidget {
  const NewUserDashboardScreen({
    super.key,
    this.initialNavigationIndex = 0,
  });

  final int initialNavigationIndex;

  @override
  State<NewUserDashboardScreen> createState() => _NewUserDashboardScreenState();
}

class _NewUserDashboardScreenState extends State<NewUserDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>(); // Add this
  int _currentNavigationIndex = 0;
  late AiAssistantService _aiService;
  bool _isAiServiceInitialized = false;
  bool _isAiAssistantOpen = false;
  bool _showAskFab = false;
  bool _isVoiceActive = false;
  bool _isVoiceProcessing = false; // Add this
  String? _voiceRecognizedText;
  String? _pendingAiResponse; // Add this
  bool _showAskHint = true;
  late final PageController _tipsController;
  Timer? _tipsAutoTimer;
  Timer? _askHintTimer;
  int _tipsPage = 0;

  @override
  void initState() {
    super.initState();
    _currentNavigationIndex = widget.initialNavigationIndex.clamp(0, 3);
    _tipsController = PageController();
    _tipsAutoTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_tipsController.hasClients) return;
      _tipsPage = (_tipsPage + 1) % 2;
      _tipsController.animateToPage(
        _tipsPage,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOut,
      );
    });
    _showAskHint = false;
    _initAiService();
  }

  @override
  void dispose() {
    _tipsAutoTimer?.cancel();
    _askHintTimer?.cancel();
    _tipsController.dispose();
    super.dispose();
  }

  void _initAiService() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isAiServiceInitialized) return;
      try {
        final analysisService = Provider.of<FridgeAnalysisService>(context, listen: false);
        final String key = analysisService.apiKey;
        print("Initializing AI Service with Gemini 2.5 Flash...");
        setState(() {
          _aiService = AiAssistantService(apiKey: key);
          _isAiServiceInitialized = true;
        });
      } catch (e) {
        print("Provider failed, using fallback key for AI Service");
        setState(() {
          _aiService = AiAssistantService(apiKey: "AIzaSyDDasFFkt7WbS2wUDS711wy8Br208lzIho");
          _isAiServiceInitialized = true;
        });
      }
    });
  }

  void _startVoiceCommand() async {
    if (!_isAiServiceInitialized) return;
    
    bool available = await _aiService.initSpeech();
    if (available) {
      setState(() {
        _isVoiceActive = true;
        _isVoiceProcessing = false;
        _voiceRecognizedText = "";
      });
      
      await _aiService.startListening((text, isFinal) async {
        setState(() => _voiceRecognizedText = text);
        
        if (isFinal) {
          setState(() => _isVoiceProcessing = true);
          
          // Get AI Intent/Response
          final response = await _aiService.sendMessage(text);
          setState(() => _pendingAiResponse = response);
        }
      });
    }
  }

  void _confirmVoiceAction() async {
    if (_pendingAiResponse == null) return;
    
    final response = _pendingAiResponse!;
    
    // Universal Navigation Logic
    if (response.contains('[ACTION:SETUP_FRIDGE]')) {
      setState(() {
        _isVoiceActive = false;
        _isVoiceProcessing = false;
        _voiceRecognizedText = null;
        _pendingAiResponse = null;
      });
      final done = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const OpenFridgeSetupScreen()),
      );
      if (!mounted) return;
      if (done == true) {
        setState(() => _currentNavigationIndex = 1);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Scan complete! Your items are now in Inventory.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    
    Widget? nextScreen;
    if (response.contains('[ACTION:GROCERY_LIST]')) {
      nextScreen = const GroceryListScreen();
    } else if (response.contains('[ACTION:RECIPES]')) {
      nextScreen = const RecipeSuggestionsScreen();
    } else if (response.contains('[ACTION:ADD_ITEM]')) {
      nextScreen = const AddItemScreen();
    }
    
    if (nextScreen != null) {
      setState(() {
        _isVoiceActive = false;
        _isVoiceProcessing = false;
        _voiceRecognizedText = null;
        _pendingAiResponse = null;
      });
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => nextScreen!),
      );
    } else {
      // Normal Chat response (no navigation)
      await _aiService.speak(response);
      await Future.delayed(const Duration(seconds: 3));
      setState(() {
        _isVoiceActive = false;
        _isVoiceProcessing = false;
        _voiceRecognizedText = null;
        _pendingAiResponse = null;
      });
    }
  }

  void _cancelVoiceAction() {
    setState(() {
      _isVoiceActive = false;
      _isVoiceProcessing = false;
      _voiceRecognizedText = null;
      _pendingAiResponse = null;
    });
    _aiService.stopListening();
  }

  Future<void> _openFridgeSetup() async {
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const OpenFridgeSetupScreen()),
    );
    if (!mounted) return;
    if (done == true) {
      setState(() => _currentNavigationIndex = 1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scan complete! Your items are now in Inventory.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showAiChat() {
    if (!_isAiServiceInitialized) return;
    final rootContext = context;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: AiAssistantOverlay(
          service: _aiService,
          onSetupFridge: () {
            Navigator.of(sheetContext).pop();
            Future.microtask(() async {
              if (!mounted) return;
              final done = await Navigator.of(rootContext).push<bool>(
                MaterialPageRoute(builder: (_) => const OpenFridgeSetupScreen()),
              );
              if (!mounted) return;
              if (done == true) {
                setState(() => _currentNavigationIndex = 1);
                ScaffoldMessenger.of(rootContext).showSnackBar(
                  const SnackBar(
                    content: Text('Scan complete! Your items are now in Inventory.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            });
          },
        ),
      ),
    );
  }

  BoxDecoration modernCardDecoration(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: cs.outlineVariant.withOpacity(isDark ? 0.35 : 0.65),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.35 : 0.04),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 380;
    final langProvider = Provider.of<LanguageProvider>(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: cs.surface,
      drawer: _buildSidebar(langProvider),
      resizeToAvoidBottomInset: false,
      appBar: _buildAppBar(langProvider),
      body: Stack(
        children: [
          IndexedStack(
            index: _currentNavigationIndex,
            children: [
              SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 8),
                  child: Container(
                    color: cs.surface,
                    child: Column(
                      children: [
                        _buildHeroSection(isSmallScreen, langProvider),
                        const SizedBox(height: 8),
                        _buildSetupCard(langProvider),
                        const SizedBox(height: 8),
                        _buildStatsGrid(),
                        const SizedBox(height: 8),
                        _buildStepsSection(),
                        const SizedBox(height: 8),
                        _buildTipCard(),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ),
              const FridgeInventoryTabScreen(),
              SafeArea(
                child: RecipeSuggestionsScreen(),
              ),
              SafeArea(
                child: const GroceryListScreen(),
              ),
            ],
          ),
          // Siri-like Voice Overlay
          if (_isVoiceActive)
            SiriWaveformOverlay(
              isListening: !_isVoiceProcessing,
              isProcessing: _isVoiceProcessing,
              recognizedText: _voiceRecognizedText,
              onConfirm: _confirmVoiceAction,
              onCancel: _cancelVoiceAction,
            ),
          // Floating AI Assistant Button (Consolidated)
          if (_showAskFab)
            Positioned(
              right: 16,
              bottom: 220,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_isAiAssistantOpen) ...[
                    _buildAssistantOption(
                      icon: Icons.auto_awesome_rounded,
                      color: const Color(0xFF2D7DFF),
                      label: 'AI Chat',
                      onTap: () {
                        setState(() => _isAiAssistantOpen = false);
                        _showAiChat();
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildAssistantOption(
                      icon: Icons.mic_rounded,
                      color: const Color(0xFF00B894),
                      label: 'Voice',
                      onTap: () {
                        setState(() => _isAiAssistantOpen = false);
                        _startVoiceCommand();
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  GestureDetector(
                    onTap: () {
                      setState(() => _isAiAssistantOpen = !_isAiAssistantOpen);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2D7DFF), Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.surface, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2D7DFF).withOpacity(0.25),
                            blurRadius: 12,
                            spreadRadius: 1,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          AnimatedRotation(
                            duration: const Duration(milliseconds: 300),
                            turns: _isAiAssistantOpen ? 0.125 : 0,
                            child: Icon(
                              _isAiAssistantOpen ? Icons.close_rounded : Icons.auto_awesome_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!_isAiAssistantOpen && _showAskHint)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 280),
                        opacity: _showAskHint ? 1 : 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF2D7DFF).withOpacity(0.8),
                                const Color(0xFF6366F1).withOpacity(0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 6),
                              const SizedBox(width: 3),
                              Text(
                                langProvider.translate('ask_ai'),
                                style: const TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  bool _isQuickMenuOpen = false;

  void _showQuickMenu(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.1),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
      transitionBuilder: (context, anim1, anim2, child) {
        final curve = Curves.easeOutBack.transform(anim1.value);
        return Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Radial Menu Actions
            _buildRadialAction(
              icon: Icons.qr_code_scanner_rounded,
              label: langProvider.translate('scan_qr'),
              color: const Color(0xFF7A5CFA),
              dx: -110 * curve,
              dy: -100 * curve,
              onTap: () {
                Navigator.pop(context);
              },
            ),
            _buildRadialAction(
              icon: Icons.playlist_add_circle_rounded,
              label: langProvider.translate('add_item'),
              color: const Color(0xFF4A90E2),
              dx: -65 * curve,
              dy: -180 * curve,
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddItemScreen()));
              },
            ),
            _buildRadialAction(
              icon: Icons.kitchen_rounded,
              label: langProvider.translate('fridge'),
              color: const Color(0xFF00B894),
              dx: 65 * curve,
              dy: -180 * curve,
              onTap: () {
                Navigator.pop(context);
                _openFridgeSetup();
              },
            ),
            _buildRadialAction(
              icon: Icons.shopping_cart_checkout_rounded,
              label: langProvider.translate('grocery'),
              color: const Color(0xFFFF9F43),
              dx: 110 * curve,
              dy: -100 * curve,
              onTap: () {
                Navigator.pop(context);
                // Navigate to Grocery List if available
              },
            ),
            _buildRadialAction(
              icon: Icons.restaurant_menu_rounded,
              label: langProvider.translate('recipes'),
              color: const Color(0xFFFF6B9A),
              dx: 0,
              dy: -230 * curve,
              onTap: () {
                Navigator.pop(context);
                // Navigate to Recipes
              },
            ),
          ],
        );
      },
    ).then((_) => setState(() => _isQuickMenuOpen = false));
  }

  Widget _buildRadialAction({
    required IconData icon,
    required String label,
    required Color color,
    required double dx,
    required double dy,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Transform.translate(
      offset: Offset(dx, dy),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: onTap,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.28),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant.withOpacity(0.45)),
          borderRadius: BorderRadius.circular(16),
          color: cs.surfaceContainerHighest.withOpacity(0.4),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: cs.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant.withOpacity(0.65)),
          ],
        ),
      ),
    );
  }

  Widget _buildAssistantOption({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar(LanguageProvider lp) {
    final cs = Theme.of(context).colorScheme;
    return AppBar(
      backgroundColor: cs.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 50,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GestureDetector(
          onTap: () => _scaffoldKey.currentState?.openDrawer(),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.45)),
            ),
            child: Icon(Icons.menu_rounded, color: cs.primary, size: 20),
          ),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/img.png', height: 29),
          const SizedBox(width: 6),
          Text(
            'Friji',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: cs.primary,
              letterSpacing: -0.5,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        // Notification Icon - More compact
        Stack(
          children: [
            IconButton(
              icon: Icon(Icons.notifications_none_rounded, color: cs.onSurfaceVariant, size: 20),
              onPressed: () {},
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            Positioned(
              right: 6,
              top: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 12,
                  minHeight: 12,
                ),
                child: const Text(
                  '3',
                  style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
        // Profile Avatar - Smaller and cleaner
        Padding(
          padding: const EdgeInsets.only(right: 16, left: 4),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: cs.outlineVariant.withOpacity(0.55), width: 1.5),
            ),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: cs.primaryContainer.withOpacity(0.35),
              backgroundImage: const NetworkImage('https://i.pravatar.cc/150?img=32'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSidebar(LanguageProvider lp) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.8,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 70, 24, 36),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [cs.surfaceContainerHighest, cs.surface]
                    : [const Color(0xFFF8FAFF), cs.surface],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(40),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
                        boxShadow: [
                          BoxShadow(
                            color: cs.primary.withOpacity(0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Image.asset(
                            'assets/img.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Friji Smart',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: cs.onSurface,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  lp.translate('kitchen_welcome'),
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Consumer<ThemeProvider>(
              builder: (context, theme, _) {
                final tcs = Theme.of(context).colorScheme;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lp.translate('appearance'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: tcs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _ThemeModeOption(
                            icon: Icons.light_mode_rounded,
                            label: lp.translate('light_mode'),
                            selected: theme.themeMode == ThemeMode.light,
                            onTap: () => theme.setLight(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ThemeModeOption(
                            icon: Icons.dark_mode_rounded,
                            label: lp.translate('dark_mode'),
                            selected: theme.themeMode == ThemeMode.dark,
                            onTap: () => theme.setDark(),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              physics: const BouncingScrollPhysics(),
              children: [
                _buildSidebarItem(
                  context,
                  icon: Icons.settings_rounded,
                  label: lp.translate('settings'),
                  subtitle: 'App preferences & account',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                  },
                ),
                _buildSidebarItem(
                  context,
                  icon: Icons.person_rounded,
                  label: lp.translate('profile'),
                  subtitle: 'Manage your information',
                  onTap: () => Navigator.pop(context),
                ),
                _buildSidebarItem(
                  context,
                  icon: Icons.notifications_active_rounded,
                  label: lp.translate('alerts'),
                  subtitle: 'Expiration & grocery reminders',
                  onTap: () => Navigator.pop(context),
                ),
                _buildSidebarItem(
                  context,
                  icon: Icons.auto_awesome_rounded,
                  label: lp.translate('ai_insights'),
                  subtitle: 'View fridge analytics',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AiInsightsScreen()),
                    );
                  },
                ),
                _buildSidebarItem(
                  context,
                  icon: Icons.help_center_rounded,
                  label: lp.translate('support'),
                  subtitle: 'Get help or send feedback',
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Divider(indent: 30, endIndent: 30, color: cs.outlineVariant.withOpacity(0.45)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
            child: _buildSidebarItem(
              context,
              icon: Icons.logout_rounded,
              label: lp.translate('sign_out'),
              subtitle: 'Exit your current session',
              accent: cs.error,
              onTap: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    Color? accent,
  }) {
    final cs = Theme.of(context).colorScheme;
    final Color base = accent ?? cs.onSurface;
    final Color iconBg = accent != null ? accent.withOpacity(0.12) : cs.primary.withOpacity(0.10);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        visualDensity: VisualDensity.compact,
        tileColor: cs.surfaceContainerHigh.withOpacity(0.5),
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: base, size: 18),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: base,
            letterSpacing: -0.2,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 10,
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.outlineVariant.withOpacity(0.28)),
        ),
        hoverColor: cs.surfaceContainerHighest.withOpacity(0.85),
      ),
    );
  }

  Widget _buildHeroSection(bool isSmallScreen, LanguageProvider lp) {
    final cs = Theme.of(context).colorScheme;
    final double heroImg = isSmallScreen ? 192 : 224;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 5),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 54,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Welcome to Friji!',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('👋', style: TextStyle(fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 4),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Let's set up your",
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        color: cs.onSurface,
                        height: 1.1,
                        letterSpacing: -0.75,
                      ),
                    ),
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [cs.primary, cs.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: const Text(
                        'smart fridge.',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.1,
                          letterSpacing: -0.75,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  lp.translate('hero_subtitle'),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: cs.onSurfaceVariant,
                    height: 1.38,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 38,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        colors: [cs.primary, cs.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withOpacity(0.28),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      onPressed: _openFridgeSetup,
                      icon: const Icon(Icons.add_rounded, size: 19),
                      label: Text(
                        lp.translate('setup_btn'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 46,
            child: Transform.translate(
              offset: const Offset(-4, 4),
              child: Image.asset(
                'assets/img.png',
                height: heroImg,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupCard(LanguageProvider lp) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 13, 13, 11),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: cs.outlineVariant.withOpacity(isDark ? 0.35 : 0.55)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.35 : 0.05),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Set up your first fridge',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: cs.onSurface),
                ),
                const SizedBox(width: 4),
                const Text('✨', style: TextStyle(fontSize: 13)),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              'Add your fridge to start tracking items and getting smart reminders.',
              style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant, height: 1.3),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildActionTile(
                    icon: Icons.cloud_upload_outlined,
                    title: 'Upload photo',
                    subtitle: 'Upload fridge photo...',
                    showAi: true,
                    onTap: _openFridgeSetup,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _buildActionTile(
                    icon: Icons.camera_alt_outlined,
                    title: 'Take photo',
                    subtitle: 'Scan fridge now...',
                    showAi: true,
                    onTap: _openFridgeSetup,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: InkWell(
                onTap: () {},
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'More ways to add',
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.keyboard_arrow_down_rounded, color: cs.onSurfaceVariant, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    bool showAi = false,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.45), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: cs.primary, size: 16),
                ),
                Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant.withOpacity(0.7), size: 14),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: cs.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (showAi) ...[
                  const SizedBox(width: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text('AI', style: TextStyle(color: cs.primary, fontSize: 6, fontWeight: FontWeight.w900)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 8.5, color: cs.onSurfaceVariant, height: 1.2),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _buildVerticalStat(
                Icons.calendar_today_outlined,
                '0',
                'Expiring Soon',
                'Add items to see expiring food',
                const Color(0xFFE74C3C),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _buildVerticalStat(
                Icons.access_time_outlined,
                '0',
                'Use Soon',
                'Add items to see what to use',
                const Color(0xFFF1C40F),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _buildVerticalStat(
                Icons.eco_outlined,
                '0',
                'Fresh',
                'Your fresh items will appear here',
                const Color(0xFF2ECC71),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _buildVerticalStat(
                Icons.shopping_bag_outlined,
                '0',
                'Low Stock',
                'Add items to get low stock alerts',
                const Color(0xFF9B59B6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalStat(IconData icon, String value, String title, String subtitle, Color color) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.28), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.07),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 12),
              const SizedBox(width: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: TextStyle(
              fontSize: 8.7,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
              height: 1.1,
            ),
          ),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 7,
              color: cs.onSurfaceVariant,
              height: 1.1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String count, String label, String subLabel, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                count,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF1A2B4D)),
          ),
          const SizedBox(height: 2),
          Text(
            subLabel,
            style: TextStyle(fontSize: 7, color: Colors.black.withOpacity(0.4), height: 1.2),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStepsSection() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              'Get started in 3 simple steps ✨',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: cs.onSurface),
            ),
          ),
          const SizedBox(height: 11),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStepCircle(context, '1', Icons.kitchen_outlined, 'Add Your Fridge'),
              _buildStepSmallArrow(context),
              _buildStepCircle(context, '2', Icons.shopping_cart_outlined, 'Add Items'),
              _buildStepSmallArrow(context),
              _buildStepCircle(context, '3', Icons.lightbulb_outline_rounded, 'Get Smarter'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepCircle(BuildContext context, String number, IconData icon, String title) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 82,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.topRight,
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: cs.primary, size: 24),
              ),
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(4.5),
                  decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                  child: Text(
                    number,
                    style: const TextStyle(color: Colors.white, fontSize: 7.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(fontSize: 10.2, fontWeight: FontWeight.w800, color: cs.onSurface, height: 1.16),
          ),
        ],
      ),
    );
  }

  Widget _buildStepSmallArrow(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Icon(
        Icons.chevron_right_rounded,
        color: cs.primary.withOpacity(0.35),
        size: 18,
      ),
    );
  }

  Widget _buildStepArrow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Icon(
        Icons.chevron_right_rounded,
        color: const Color(0xFF2D7DFF).withOpacity(0.3),
        size: 20,
      ),
    );
  }

  Widget _buildStepItem(String number, IconData icon, String title, String subtitle, bool isActive) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF2D7DFF).withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? const Color(0xFF2D7DFF).withOpacity(0.2) : const Color(0xFFF1F5F9),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF2D7DFF) : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: isActive ? Colors.white : const Color(0xFF64748B),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A2B4D),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black.withOpacity(0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            icon,
            color: isActive ? const Color(0xFF2D7DFF) : const Color(0xFFCBD5E1),
            size: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: modernCardDecoration(context),
        child: SizedBox(
          height: 44,
          child: PageView(
            controller: _tipsController,
            children: [
              _tipSlide(
                icon: Icons.lightbulb_outline_rounded,
                title: 'Tip of the day',
                subtitle: 'Setting up fridge takes < 2 mins and saves time!',
              ),
              _tipSlide(
                icon: Icons.auto_awesome_rounded,
                title: 'Featured: Ask Friji',
                subtitle: 'Try voice or AI chat for smart grocery suggestions.',
                onTap: _revealAskFab,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tipSlide({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: cs.primary, size: 16),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  color: cs.onSurfaceVariant,
                  height: 1.22,
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: cs.primary, size: 18),
      ],
    ));
  }

  void _revealAskFab() {
    _askHintTimer?.cancel();
    setState(() {
      _showAskFab = true;
      _showAskHint = true;
    });
    _askHintTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() => _showAskHint = false);
    });
  }

  Widget _buildBottomNav() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(top: BorderSide(color: cs.outlineVariant.withOpacity(0.45))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomAppBar(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        elevation: 0,
        color: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Expanded(child: _buildNavItem(Icons.home_rounded, 'Home', 0)),
            Expanded(child: _buildNavItem(Icons.inventory_2_outlined, 'Inventory', 1)),
            Expanded(child: _buildCenterAddNavButton()),
            Expanded(child: _buildNavItem(Icons.restaurant_outlined, 'Recipes', 2)),
            Expanded(child: _buildNavItem(Icons.shopping_cart_outlined, 'Grocery', 3)),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final cs = Theme.of(context).colorScheme;
    bool isSelected = _currentNavigationIndex == index;
    final muted = cs.onSurfaceVariant.withOpacity(0.65);
    return GestureDetector(
      onTap: () {
        setState(() => _currentNavigationIndex = index);
        _handleNavigation(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? cs.primary.withOpacity(0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? cs.primary : muted, size: 19),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 8,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? cs.primary : muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterAddNavButton() {
    return Center(
      child: GestureDetector(
        onTap: () {
          setState(() => _isQuickMenuOpen = !_isQuickMenuOpen);
          _showQuickMenu(context);
        },
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF2D7DFF), Color(0xFF0055FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2D7DFF).withOpacity(0.28),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
        ),
      ),
    );
  }

  void _handleNavigation(int index) {
    if (index == 2) {
      // Recipes tab uses embedded [RecipeSuggestionsScreen].
    } else if (index == 3) {
      // Grocery tab is embedded as [GroceryListScreen].
    }
  }
}

class _ThemeModeOption extends StatelessWidget {
  const _ThemeModeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? cs.primaryContainer : cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? cs.primary : cs.outlineVariant.withOpacity(0.5),
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? cs.primary : cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? cs.onPrimaryContainer : cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
