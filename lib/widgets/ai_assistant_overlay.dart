import 'package:flutter/material.dart';
import 'package:avatar_glow/avatar_glow.dart';
import '../services/ai_assistant_service.dart';

class AiAssistantOverlay extends StatefulWidget {
  final AiAssistantService service;
  final VoidCallback onSetupFridge;
  final bool startWithVoice;

  const AiAssistantOverlay({
    super.key,
    required this.service,
    required this.onSetupFridge,
    this.startWithVoice = false,
  });

  @override
  State<AiAssistantOverlay> createState() => _AiAssistantOverlayState();
}

class _AiAssistantOverlayState extends State<AiAssistantOverlay> {
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _messages.add({
      'text': 'Hi! I\'m Friji AI. How can I help you with your fridge today? 🐧',
      'isUser': false,
    });

    if (widget.startWithVoice) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _toggleListening();
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleMessage(String text) async {
    if (text.trim().isEmpty) return;

    print("Sending message to AI: $text");
    setState(() {
      _messages.add({'text': text, 'isUser': true});
      _isTyping = true;
    });
    _textController.clear();
    _scrollToBottom();

    try {
      final response = await widget.service.sendMessage(text);
      print("AI Response: $response");

      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add({'text': response, 'isUser': false});
        });

        if (response.contains('[ACTION:SETUP_FRIDGE]')) {
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              Navigator.pop(context);
              widget.onSetupFridge();
            }
          });
        }

        _scrollToBottom();
        await widget.service.speak(response);
      }
    } catch (e) {
      print("Chat Error: $e");
      if (mounted) {
        setState(() => _isTyping = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  void _toggleListening() async {
    if (_isListening) {
      await widget.service.stopListening();
      if (mounted) setState(() => _isListening = false);
    } else {
      print("Starting voice listening...");
      bool available = await widget.service.initSpeech();
      if (available) {
        setState(() => _isListening = true);
        await widget.service.startListening((text, isFinal) {
          if (isFinal) {
            setState(() => _isListening = false);
            _handleMessage(text);
          } else {
            // Optional: Update UI with partial text if desired
            setState(() => _textController.text = text);
          }
        });
      } else {
        print("Speech recognition not available");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Speech recognition not available on this device")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Premium Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 12, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2D7DFF), Color(0xFF6366F1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Friji AI Chat',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'Universal Language Support',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.black45,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 24),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Messages List
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                physics: const BouncingScrollPhysics(),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return _buildMessageBubble(msg['text'], msg['isUser']);
                },
              ),
            ),

            if (_isTyping)
              Padding(
                padding: const EdgeInsets.only(left: 24, bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 8,
                          height: 8,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Color(0xFF2D7DFF))),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Friji is typing...',
                          style: TextStyle(
                            fontSize: 9,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Enhanced Input Area
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        controller: _textController,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        textInputAction: TextInputAction.send,
                        decoration: const InputDecoration(
                          hintText: 'Ask anything...',
                          border: InputBorder.none,
                          hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                        onSubmitted: _handleMessage,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _handleMessage(_textController.text),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2D7DFF), Color(0xFF0055FF)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2D7DFF).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isUser) {
    String displayChatText = text.replaceAll(RegExp(r'\[ACTION:.*?\]'), '').trim();
    if (displayChatText.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser)
                Container(
                  margin: const EdgeInsets.only(right: 8, bottom: 2),
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: const Color(0xFF2D7DFF).withOpacity(0.1),
                    child: const Icon(Icons.auto_awesome_rounded, size: 12, color: Color(0xFF2D7DFF)),
                  ),
                ),
              Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: isUser ? const Color(0xFF2D7DFF) : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(22),
                    topRight: const Radius.circular(22),
                    bottomLeft: Radius.circular(isUser ? 22 : 6),
                    bottomRight: Radius.circular(isUser ? 6 : 22),
                  ),
                  boxShadow: [
                    if (!isUser)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: Text(
                  displayChatText,
                  style: TextStyle(
                    color: isUser ? Colors.white : const Color(0xFF1E293B),
                    fontSize: 14.5,
                    fontWeight: isUser ? FontWeight.w600 : FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isUser ? 'Sent' : 'Friji AI',
            style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8), fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
