import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:http/http.dart' as http;

import '../config/ai_config.dart';
import '../config/notebook_prompts.dart';
import '../models/ai_models.dart';
import '../models/flashcard_models.dart';
import '../models/study_guide_models.dart';
import 'ai_logic_service.dart';

/// Service dedicated to generating multi-format AI artifacts
/// (Flashcards, Study Guides, Timelines, Briefings, FAQs, Mind Maps, Quizzes)
/// from aggregated notebook source texts.
///
/// Fully supports all three execution modes via [AIConfig.mode]:
/// - [AIExecutionMode.firebaseAI]
/// - [AIExecutionMode.directClientSide]
/// - [AIExecutionMode.pythonBackend]
class AIGenerationService {
  AIGenerationService._();
  static final AIGenerationService instance = AIGenerationService._();
  factory AIGenerationService() => instance;


  // ---------------------------------------------------------------------------
  // Flashcard Generation
  // ---------------------------------------------------------------------------

  Future<FlashcardDeck> generateFlashcards(
    String sourceText, {
    String notebookId = '',
    int count = 15,
    String? difficulty,
  }) async {
    final systemPrompt = NotebookPrompts.flashcardSystemPrompt(
      count: count,
      difficulty: difficulty,
    );

    final rawJson = await _executeGeneration(
      systemPrompt: systemPrompt,
      userPrompt: 'Generate a flashcard deck based on the following source material:\n\n$sourceText',
      backendEndpoint: '/api/v1/generate-flashcards',
      backendPayload: {
        'sourceText': sourceText,
        'count': count,
        'difficulty': ?difficulty,
      },
    );

    final parsed = _decodeJsonMap(rawJson);
    return FlashcardDeck(
      id: 'deck_${DateTime.now().millisecondsSinceEpoch}',
      notebookId: notebookId,
      title: parsed['title'] as String? ?? 'Study Flashcards',
      description: parsed['description'] as String? ?? '',
      cards: (parsed['cards'] as List<dynamic>? ?? [])
          .asMap()
          .entries
          .map((entry) {
            final cardMap = Map<String, dynamic>.from(entry.value as Map);
            if (!cardMap.containsKey('id') || (cardMap['id'] as String).isEmpty) {
              cardMap['id'] = 'card_${entry.key + 1}';
            }
            return Flashcard.fromJson(cardMap);
          })
          .toList(),
      createdAt: DateTime.now(),
    );
  }

  // ---------------------------------------------------------------------------
  // Lesson Generation
  // ---------------------------------------------------------------------------

  Future<AILessonResponse> generateLesson(
    String sourceText, {
    String? customPrompt,
    String notebookId = '',
  }) async {
    final systemPrompt = NotebookPrompts.lessonSystemPrompt(
      customPrompt: customPrompt,
    );

    final rawJson = await _executeGeneration(
      systemPrompt: systemPrompt,
      userPrompt: 'Synthesize the following source documents into an interactive, structured lesson:\n\n$sourceText',
      backendEndpoint: '/api/v1/generate-lesson',
      backendPayload: {
        'sourceText': sourceText,
        'customPrompt': ?customPrompt,
      },
    );

    final parsed = _decodeJsonMap(rawJson);
    return AILessonResponse.fromJson(parsed);
  }

  // ---------------------------------------------------------------------------
  // Quiz & Assessment Generation
  // ---------------------------------------------------------------------------

  Future<AIQuizResponse> generateQuiz(
    String sourceText, {
    int count = 10,
    String? difficulty,
    bool isAssessment = false,
    String? customInstructions,
    QuizGenerationConfig? config,
  }) async {
    if (isAssessment) {
      final systemPrompt = NotebookPrompts.quizSystemPrompt(
        count: count,
        difficulty: difficulty,
        isAssessment: true,
        customInstructions: customInstructions,
      );

      final rawJson = await _executeGeneration(
        systemPrompt: systemPrompt,
        userPrompt: 'Generate a passage-based reading assessment based on the following material:\n\n$sourceText',
        backendEndpoint: '/api/v1/generate-quiz',
        backendPayload: {
          'sourceText': sourceText,
          'count': count,
          'isAssessment': true,
        },
      );

      final parsed = _decodeJsonMap(rawJson);
      return AIQuizResponse.fromJson(parsed);
    }

    // Default practice quiz
    final cfg = config ?? QuizGenerationConfig(
      difficulty: difficulty ?? 'medium',
      customInstructions: customInstructions ?? '',
    );
    return AILogicService.instance.generateQuiz(
      sourceText,
      numQuestions: count,
      config: cfg,
    );
  }

  // ---------------------------------------------------------------------------
  // Study Guide Generation
  // ---------------------------------------------------------------------------

  Future<StudyGuide> generateStudyGuide(String sourceText) async {
    final rawJson = await _executeGeneration(
      systemPrompt: NotebookPrompts.studyGuideSystemPrompt,
      userPrompt: 'Generate a comprehensive study guide from these sources:\n\n$sourceText',
      backendEndpoint: '/api/v1/generate-study-guide',
      backendPayload: {'sourceText': sourceText},
    );

    final parsed = _decodeJsonMap(rawJson);
    return StudyGuide.fromJson(parsed);
  }

  // ---------------------------------------------------------------------------
  // Timeline Generation
  // ---------------------------------------------------------------------------

  Future<Timeline> generateTimeline(String sourceText) async {
    final rawJson = await _executeGeneration(
      systemPrompt: NotebookPrompts.timelineSystemPrompt,
      userPrompt: 'Extract a chronological timeline from these sources:\n\n$sourceText',
      backendEndpoint: '/api/v1/generate-timeline',
      backendPayload: {'sourceText': sourceText},
    );

    final parsed = _decodeJsonMap(rawJson);
    return Timeline.fromJson(parsed);
  }

  // ---------------------------------------------------------------------------
  // Briefing Document Generation
  // ---------------------------------------------------------------------------

  Future<Briefing> generateBriefing(String sourceText) async {
    final rawJson = await _executeGeneration(
      systemPrompt: NotebookPrompts.briefingSystemPrompt,
      userPrompt: 'Generate an executive briefing document from these sources:\n\n$sourceText',
      backendEndpoint: '/api/v1/generate-briefing',
      backendPayload: {'sourceText': sourceText},
    );

    final parsed = _decodeJsonMap(rawJson);
    return Briefing.fromJson(parsed);
  }

  // ---------------------------------------------------------------------------
  // FAQ Generation
  // ---------------------------------------------------------------------------

  Future<FAQ> generateFAQ(String sourceText, {int count = 10}) async {
    final systemPrompt = NotebookPrompts.faqSystemPrompt(count: count);

    final rawJson = await _executeGeneration(
      systemPrompt: systemPrompt,
      userPrompt: 'Generate an FAQ with approximately $count questions from these sources:\n\n$sourceText',
      backendEndpoint: '/api/v1/generate-faq',
      backendPayload: {'sourceText': sourceText, 'count': count},
    );

    final parsed = _decodeJsonMap(rawJson);
    return FAQ.fromJson(parsed);
  }

  // ---------------------------------------------------------------------------
  // Mind Map Generation
  // ---------------------------------------------------------------------------

  Future<MindMap> generateMindMap(String sourceText) async {
    final rawJson = await _executeGeneration(
      systemPrompt: NotebookPrompts.mindMapSystemPrompt,
      userPrompt: 'Construct a conceptual mind map graph from these sources:\n\n$sourceText',
      backendEndpoint: '/api/v1/generate-mind-map',
      backendPayload: {'sourceText': sourceText},
    );

    final parsed = _decodeJsonMap(rawJson);
    return MindMap.fromJson(parsed);
  }

  // ---------------------------------------------------------------------------
  // Internal Multi-Mode Execution Pipeline
  // ---------------------------------------------------------------------------

  Future<String> _executeGeneration({
    required String systemPrompt,
    required String userPrompt,
    required String backendEndpoint,
    required Map<String, dynamic> backendPayload,
  }) async {
    switch (AIConfig.mode) {
      case AIExecutionMode.firebaseAI:
        return _executeFirebase(systemPrompt, userPrompt);
      case AIExecutionMode.directClientSide:
        return _executeDirect(systemPrompt, userPrompt);
      case AIExecutionMode.pythonBackend:
        return _executeBackend(backendEndpoint, backendPayload);
    }
  }

  Future<String> _executeFirebase(String systemPrompt, String userPrompt) async {
    try {
      final model = FirebaseAI.googleAI().generativeModel(
        model: AIConfig.firebaseAIModel,
        systemInstruction: Content.system(systemPrompt),
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.6,
        ),
      );

      final response = await model.generateContent([
        Content.text(userPrompt),
      ]);

      final text = response.text;
      if (text == null || text.trim().isEmpty) {
        throw Exception('Firebase AI returned an empty response.');
      }
      return text.trim();
    } catch (e) {
      debugPrint('Firebase AI generation error: $e, falling back to direct client-side');
      return _executeDirect(systemPrompt, userPrompt);
    }
  }

  Future<String> _executeDirect(String systemPrompt, String userPrompt) async {
    final body = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': systemPrompt}
        ]
      },
      'contents': [
        {
          'parts': [
            {'text': userPrompt}
          ]
        }
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'temperature': 0.6,
      },
    });

    final uri = Uri.parse('${AIConfig.geminiBaseUrl}?key=${AIConfig.geminiApiKey}');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini REST API error (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No candidate returned in Gemini API response.');
    }
    final firstCandidate = candidates.first as Map<String, dynamic>;
    final parts = firstCandidate['content']?['parts'] as List<dynamic>?;
    final text = parts?.first?['text'] as String?;

    if (text == null || text.trim().isEmpty) {
      throw Exception('Gemini candidate had empty text.');
    }
    return text.trim();
  }

  Future<String> _executeBackend(String endpoint, Map<String, dynamic> payload) async {
    final uri = Uri.parse('${AIConfig.pythonBackendUrl}$endpoint');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': AIConfig.pythonApiKey,
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('Python Backend error (${response.statusCode}): ${response.body}');
    }

    return response.body;
  }

  /// Cleans markdown code fences if present and parses raw string to JSON map.
  Map<String, dynamic> _decodeJsonMap(String raw) {
    String cleaned = raw.trim();
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    cleaned = cleaned.trim();

    final dynamic decoded = jsonDecode(cleaned);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    } else if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    throw FormatException('Expected JSON map, but received: ${decoded.runtimeType}');
  }
}
