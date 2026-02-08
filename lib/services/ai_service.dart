import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/spelling_word.dart';

class AIService {
  static final AIService _instance = AIService._internal();
  static AIService get instance => _instance;
  AIService._internal();

  GenerativeModel? _model;

  // Initialize with API Key (should be loaded from secure storage/env)
  void init() {
    // For now, we'll assume the API key is in .env or compile-time const
    // In a real app, use flutter_dotenv or similar
    final apiKey =
        dotenv.env['GEMINI_API_KEY'] ??
        const String.fromEnvironment('GEMINI_API_KEY');
    if (apiKey.isEmpty) {
      print('Warning: GEMINI_API_KEY is not set');
      return;
    }
    _model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
  }

  Future<List<SpellingWord>> generateWords({
    required int count,
    required SpellingDifficulty difficulty,
    String? topic,
  }) async {
    if (_model == null) {
      init();
      if (_model == null) {
        throw Exception(
          'Gemini API Key not found. Please configure GEMINI_API_KEY in .env',
        );
      }
    }

    final diffStr = '${difficulty.name} difficulty';

    final topicStr = topic != null && topic.isNotEmpty
        ? 'related to "$topic"'
        : '';

    final prompt =
        '''
    Generate a JSON array of $count spelling words of $diffStr $topicStr.
    Do NOT generate sentences or phrases. Only single words.
    Each object in the array must have:
    - "word": The word itself (string, single word only)
    - "difficulty": One of "easy", "medium", "hard" (string)
    
    Example output:
    [
      {"word": "cat", "difficulty": "easy"},
      {"word": "photosynthesis", "difficulty": "hard"}
    ]
    ''';

    try {
      final response = await _model!.generateContent([Content.text(prompt)]);

      if (response.text == null) {
        throw Exception('Empty response from AI');
      }

      // Clean the response if it contains markdown formatting
      String jsonStr = response.text!;
      if (jsonStr.startsWith('```json')) {
        jsonStr = jsonStr.replaceAll('```json', '').replaceAll('```', '');
      }

      final List<dynamic> jsonList = jsonDecode(jsonStr);

      return jsonList.map((json) {
        return SpellingWord(
          id: DateTime.now().microsecondsSinceEpoch.toString(), // Temporary ID
          word: json['word'],
          difficulty: _parseDifficulty(json['difficulty']),
          createdAt: Timestamp.now(),
          createdByUid: 'ai_generated', // Marker for AI words
          audioUrl: null, // AI words won't have audio initially
        );
      }).toList();
    } on GenerativeAIException catch (e) {
      if (e.message.contains('429') ||
          e.message.contains('ResourceExhausted')) {
        throw Exception(
          'Daily AI generation limit reached. Please try again tomorrow to keep this service free.',
        );
      }
      rethrow;
    } catch (e) {
      throw Exception('Failed to generate words: $e');
    }
  }

  SpellingDifficulty _parseDifficulty(String? diff) {
    switch (diff?.toLowerCase()) {
      case 'easy':
      case 'novice':
        return SpellingDifficulty.novice;
      case 'medium':
      case 'amateur':
        return SpellingDifficulty.amateur;
      case 'hard':
      case 'professional':
        return SpellingDifficulty.professional;
      default:
        return SpellingDifficulty.amateur;
    }
  }
}
