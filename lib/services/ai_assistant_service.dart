import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:convert';

class AiAssistantService {
  final String apiKey;
  late GenerativeModel _model;
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  
  ChatSession? _chatSession;

  AiAssistantService({required this.apiKey}) {
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 1024,
      ),
      systemInstruction: Content.system(
        "You are Friji AI, a highly professional smart refrigerator assistant. "
        "Your expertise includes food management, creative recipe generation, and fridge maintenance. "
        "You are polyglot and can communicate fluently in ANY language the user uses. "
        "ALWAYS respond in the same language the user uses. "
        "Keep your responses professional, friendly, and very concise (maximum 3 sentences). "
        "You can navigate the user to different parts of the app by including these tags at the end of your response:\n"
        "- Setup Fridge: [ACTION:SETUP_FRIDGE]\n"
        "- Grocery List: [ACTION:GROCERY_LIST]\n"
        "- Recipe Suggestions: [ACTION:RECIPES]\n"
        "- Inventory/Fridge Content: [ACTION:INVENTORY]\n"
        "- Add New Item: [ACTION:ADD_ITEM]\n"
        "Example: If the user says 'I want to see my groceries', respond professionally and add [ACTION:GROCERY_LIST]."
      ),
    );
    _chatSession = _model.startChat();
  }

  // --- Chat Logic ---
  Future<String> sendMessage(String message) async {
    try {
      final response = await _chatSession!.sendMessage(Content.text(message));
      return response.text ?? "I'm sorry, I couldn't process that.";
    } catch (e) {
      return "Error: $e";
    }
  }

  // --- Voice Logic ---
  Future<bool> initSpeech() async {
    return await _speech.initialize();
  }

  Future<void> startListening(Function(String, bool) onResult) async {
    await _speech.listen(
      onResult: (result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      listenMode: ListenMode.confirmation,
      cancelOnError: true,
      partialResults: true,
    );
  }

  Future<void> stopListening() async {
    await _speech.stop();
  }

  bool get isListening => _speech.isListening;

  // --- TTS Logic ---
  Future<void> speak(String text) async {
    // Clean text from tags before speaking
    String cleanText = text.replaceAll(RegExp(r'\[ACTION:.*?\]'), '').trim();
    await _tts.setLanguage("en-US");
    await _tts.setPitch(1.0);
    await _tts.speak(cleanText);
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
  }
}
