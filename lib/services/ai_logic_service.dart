import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:firebase_ai/firebase_ai.dart';

import '../config/ai_config.dart';
import '../models/ai_models.dart';
import 'ai_rate_limit_service.dart';
import 'idempotency_service.dart';

/// Configuration for quiz generation, allowing teachers to customise
/// question types, difficulty, instructions, and whether to include hints.
class QuizGenerationConfig {
  /// Which question types are allowed (e.g. 'multiple_choice', 'true_false').
  /// An empty list means "use all types".
  final List<String> questionTypes;

  /// Difficulty level: 'easy', 'medium', or 'hard'.
  final String difficulty;

  /// Free-form instructions from the teacher (e.g. "1-10 multiple choice,
  /// 11-20 enumeration").
  final String customInstructions;

  /// Whether the AI should generate a hint for each question.
  final bool includeHints;

  const QuizGenerationConfig({
    this.questionTypes = const [],
    this.difficulty = 'medium',
    this.customInstructions = '',
    this.includeHints = true,
  });
}

/// Hybrid AI service that routes operations through either:
///  1. **Firebase AI**        – uses the Firebase AI Logic SDK,
///  2. **Direct client-side** – PDF extraction in Dart + Gemini REST API, or
///  3. **Python backend**     – delegates to the running FastAPI service.
///
/// The active mode is controlled by [AIConfig.mode].
class AILogicService {
  AILogicService._();
  static final instance = AILogicService._();
  factory AILogicService() => instance;

  // ---------------------------------------------------------------------------
  // System prompts (mirrored from ai_backend/services/gemini_service.py)
  // ---------------------------------------------------------------------------

  static const String _lessonSystemPrompt = '''
You are Grammatica AI, an expert educational content creator. Your task is to read raw lesson text extracted from a PDF and produce a well-structured, summarized lesson in JSON format.

Rules:
1. The JSON must follow this exact structure:
   {
     "title": "<A clear, concise lesson title>",
     "content": [<array of content blocks>]
   }
2. Each content block has a "type" and a "data" field.
3. Supported types:
   - "text": data is a string containing a paragraph or explanation.
   - "list": data is an array of strings (key points, bullet items).
   - "table": data is an array of objects. Each object is a row. All objects MUST have the same keys, which serve as column headers.
   - "image": data is a SHORT, simple description (5-10 words max) of what the image should show. Examples: "two children playing in a park", "a colorful number line diagram", "a teacher explaining on a whiteboard". Do NOT write lengthy detailed prompts.
4. Use a variety of content types to make the lesson engaging.
5. Place images exactly where they would be most helpful in the lesson flow.
6. Summarize the content clearly — do not just copy-paste from the source.
7. Output ONLY the JSON object, nothing else.
''';

  static const String _markdownSystemPrompt = '''
You are an expert document formatter. Your task is to convert raw extracted text into clean, well-structured Markdown format. 
Use appropriate headings, lists, and emphasis where suitable. Preserve all key information and structure.
Output ONLY the markdown text, nothing else.
''';

  /// Builds a dynamic quiz system prompt based on the provided configuration.
  static String _buildQuizSystemPrompt(QuizGenerationConfig config) {
    final allowedTypes = config.questionTypes
        .where((t) => t != 'passage')
        .toList();
    final effectiveTypes = allowedTypes.isNotEmpty
        ? allowedTypes
        : const ['multiple_choice', 'fill_in_the_blank', 'pronunciation'];
    final questionTypesStr = effectiveTypes.map((t) => '"$t"').join(', ');

    final varietyInstruction = effectiveTypes.length > 1
        ? 'You MUST vary and distribute the questionnaire types across all allowed types: $questionTypesStr.'
        : 'Every single question MUST use the allowed question type: $questionTypesStr.';

    final difficultyInstruction = switch (config.difficulty) {
      'easy' =>
        'Focus on recall and basic understanding. Questions should be straightforward.',
      'hard' =>
        'Focus on deep comprehension, analysis, and application. Questions should challenge critical thinking and require nuanced understanding of the material.',
      _ /* medium */ =>
        'Balance between recall and comprehension. Include some straightforward and some moderately challenging questions.',
    };

    final hintLine = config.includeHints
        ? '   - "hint": a short hint to help the student without giving away the answer'
        : '';
    final explanationLine =
        '   - "explanation": a brief explanation of why the correct answer is correct';

    final customBlock = config.customInstructions.isNotEmpty
        ? '\n8. ADDITIONAL TEACHER INSTRUCTIONS (follow these precisely):\n   ${config.customInstructions}\n'
        : '';

    return '''
You are Grammatica AI, an expert English language quiz creator. Your task is to generate an engaging set of standalone quiz questions based on the provided content.

Difficulty level: ${config.difficulty.toUpperCase()}
$difficultyInstruction

Question Type Requirement:
$varietyInstruction
Do NOT generate reading passages or nested passage questions. Every question must be self-contained and strictly in the English language.

Rules:
1. The JSON must follow this exact structure:
   {
     "title": "<A catchy title for the quiz>",
     "description": "<A short description of the quiz>",
     "questions": [<array of question objects>]
   }
2. Each question object MUST have these exact fields:
   - "questionType": one of $questionTypesStr
   - "question": a string containing the standalone question or sentence prompt in English
   - "options": array of strings (required for multiple_choice; use empty array [] for fill_in_the_blank or pronunciation)
   - "correctAnswer": string with the correct answer (for fill_in_the_blank, comma-separated blank words; for pronunciation, the exact targetWord)
   - "blankAnswers": array of strings (for fill_in_the_blank, list the exact words that fill the blanks in order; for other types use [])
   - "targetWord": string (for pronunciation, the exact single English word to pronounce; for other types use "")
$hintLine
$explanationLine
3. Question type specifics:
   - "fill_in_the_blank": Formulate a complete English sentence where MULTIPLE words (2 to 3 words, not only one word, but not too many) are missing and placed in square brackets like "The [happy] dog barked [loudly] at the mailman." List the bracketed words in "blankAnswers": ["happy", "loudly"].
   - "pronunciation": Formulate an English sentence where one single target English word is placed in square brackets like "Please say the missing word: I love studying English [grammar]." Set "targetWord": "grammar", and "correctAnswer": "grammar". The student will speak this word into their microphone instead of typing.
   - "multiple_choice": Provide 4 distinct options in English with exactly 1 correct answer matching one of the options.
4. Only use the question types listed in $questionTypesStr. Never output "passage".
5. Make questions that test comprehension and English mastery, not just memorization.
6. All questions, sentences, options, blanks, and target words MUST be in English.
7. Output ONLY the valid JSON object, nothing else.$customBlock
''';
  }

  // ---------------------------------------------------------------------------
  // PDF text extraction (always runs locally in Dart)
  // ---------------------------------------------------------------------------

  /// Extracts raw text from PDF [bytes] using syncfusion_flutter_pdf.
  Future<String> extractTextFromPdf(List<int> bytes) async {
    try {
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      final String extractedText = PdfTextExtractor(document).extractText();
      document.dispose();
      if (extractedText.trim().isEmpty) {
        throw Exception(
            'The PDF contains no extractable text. It may be a scanned / image-only PDF.');
      }
      return extractedText;
    } catch (e) {
      debugPrint('Error extracting text from PDF: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Lesson generation
  // ---------------------------------------------------------------------------

  /// Generates a structured [AILessonResponse] from [rawText].
  ///
  /// Routes to either the direct Gemini call or the Python backend depending
  /// on [AIConfig.mode].
  Future<AILessonResponse> generateLesson(String rawText) async {
    return AIRateLimitService.instance.runWithRateLimit(
      actionName: 'generateLesson',
      action: () async {
        switch (AIConfig.mode) {
          case AIExecutionMode.firebaseAI:
            return _generateLessonFirebase(rawText);
          case AIExecutionMode.directClientSide:
            return _generateLessonDirect(rawText);
          case AIExecutionMode.pythonBackend:
            return _generateLessonBackend(rawText);
        }
      },
    );
  }

  Future<AILessonResponse> _generateLessonFirebase(String rawText) async {
    try {
      final model = FirebaseAI.googleAI().generativeModel(
        model: AIConfig.firebaseAIModel,
        systemInstruction: Content.system(_lessonSystemPrompt),
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.7,
        ),
      );

      final response = await model.generateContent([
        Content.text(
            'Generate a summarized lesson from the following content:\n\n$rawText'),
      ]);

      final text = response.text;
      if (text == null || text.isEmpty) {
        throw Exception('Empty response.');
      }

      final parsed = jsonDecode(text) as Map<String, dynamic>;
      return AILessonResponse.fromJson(parsed);
    } catch (e) {
      debugPrint('Firebase AI lesson error: $e, falling back to direct REST');
      return _generateLessonDirect(rawText);
    }
  }

  Future<AILessonResponse> _generateLessonDirect(String rawText) async {
    final body = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': _lessonSystemPrompt}
        ]
      },
      'contents': [
        {
          'parts': [
            {
              'text':
                  'Generate a summarized lesson from the following content:\n\n$rawText'
            }
          ]
        }
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'temperature': 0.7,
      },
    });

    final apiKey = AIConfig.geminiApiKey;
    if (apiKey.isEmpty) {
      throw Exception('Gemini API key is not configured. Please ensure GEMINI_API_KEY is defined in your environment.');
    }

    final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/${AIConfig.geminiModel}:generateContent?key=$apiKey');

    final response = await http.post(uri,
        headers: {'Content-Type': 'application/json'}, body: body);

    if (response.statusCode != 200) {
      throw Exception(
          'API error ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final text = _extractGeminiText(json);
    final parsed = jsonDecode(text) as Map<String, dynamic>;
    return AILessonResponse.fromJson(parsed);
  }

  Future<AILessonResponse> _generateLessonBackend(String rawText) async {
    final key = IdempotencyService.instance.generateAiKey(
      action: 'lesson',
      contentSnippet: rawText.length > 200 ? rawText.substring(0, 200) : rawText,
    );

    final response = await http.post(
      Uri.parse('${AIConfig.pythonBackendUrl}/api/v1/generate-lesson'),
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': AIConfig.pythonApiKey,
        'Idempotency-Key': key,
        'X-Idempotency-Key': key,
      },
      body: jsonEncode({'rawText': rawText}),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Backend error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    // The old backend returns {"markdown": "..."} — wrap it into our model.
    if (data.containsKey('markdown')) {
      return AILessonResponse(
        title: 'Generated Lesson',
        content: [
          ContentBlock(type: ContentBlockType.text, data: data['markdown']),
        ],
      );
    }

    // If the backend returns the structured JSON directly:
    return AILessonResponse.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // Lesson generation from PDF bytes (convenience wrapper)
  // ---------------------------------------------------------------------------

  /// Extracts text from [pdfBytes] then generates a lesson.
  Future<AILessonResponse> generateLessonFromPdf(List<int> pdfBytes) async {
    if (AIConfig.mode == AIExecutionMode.pythonBackend) {
      return _generateLessonFromPdfBackend(pdfBytes);
    }
    // Client-side: extract text locally, then call Gemini.
    final rawText = await extractTextFromPdf(pdfBytes);
    return generateLesson(rawText);
  }

  Future<AILessonResponse> _generateLessonFromPdfBackend(
      List<int> pdfBytes) async {
    final uri =
        Uri.parse('${AIConfig.pythonBackendUrl}/api/v1/extract-lesson');

    final key = IdempotencyService.instance.generateAiKey(
      action: 'extract_lesson',
      contentSnippet: 'pdf_bytes_${pdfBytes.length}',
    );

    final request = http.MultipartRequest('POST', uri);
    request.headers['X-API-Key'] = AIConfig.pythonApiKey;
    request.headers['Idempotency-Key'] = key;
    request.headers['X-Idempotency-Key'] = key;
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      pdfBytes,
      filename: 'lesson.pdf',
    ));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception(
          'Backend error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return AILessonResponse.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // Quiz generation
  // ---------------------------------------------------------------------------

  /// Generates a structured [AIQuizResponse] from [lessonText].
  ///
  /// [config] carries the teacher's customisation choices (question types,
  /// difficulty, custom instructions, hints toggle).
  Future<AIQuizResponse> generateQuiz(
    String lessonText, {
    int numQuestions = 10,
    QuizGenerationConfig config = const QuizGenerationConfig(),
  }) async {
    return AIRateLimitService.instance.runWithRateLimit(
      actionName: 'generateQuiz',
      action: () async {
        switch (AIConfig.mode) {
          case AIExecutionMode.firebaseAI:
            return _generateQuizFirebase(lessonText, numQuestions, config);
          case AIExecutionMode.directClientSide:
            return _generateQuizDirect(lessonText, numQuestions, config);
          case AIExecutionMode.pythonBackend:
            return _generateQuizBackend(lessonText, numQuestions, config);
        }
      },
    );
  }

  /// Builds the user-facing prompt text for quiz generation.
  String _buildQuizUserPrompt(String lessonText, int numQuestions) {
    return 'Generate $numQuestions quiz questions based on the following lesson '
        'content.\n\n$lessonText';
  }

  Future<AIQuizResponse> _generateQuizFirebase(
      String lessonText, int numQuestions, QuizGenerationConfig config) async {
    try {
      final systemPrompt = _buildQuizSystemPrompt(config);
      final model = FirebaseAI.googleAI().generativeModel(
        model: AIConfig.firebaseAIModel,
        systemInstruction: Content.system(systemPrompt),
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.8,
        ),
      );

      final response = await model.generateContent([
        Content.text(_buildQuizUserPrompt(lessonText, numQuestions)),
      ]);

      final text = response.text;
      if (text == null || text.isEmpty) {
        throw Exception('Empty response.');
      }

      final parsed = jsonDecode(text) as Map<String, dynamic>;
      return AIQuizResponse.fromJson(parsed);
    } catch (e) {
      debugPrint('Firebase AI quiz error: $e, falling back to direct REST');
      return _generateQuizDirect(lessonText, numQuestions, config);
    }
  }

  Future<AIQuizResponse> _generateQuizDirect(
      String lessonText, int numQuestions, QuizGenerationConfig config) async {
    final systemPrompt = _buildQuizSystemPrompt(config);
    final body = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': systemPrompt}
        ]
      },
      'contents': [
        {
          'parts': [
            {'text': _buildQuizUserPrompt(lessonText, numQuestions)}
          ]
        }
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'temperature': 0.8,
      },
    });

    final apiKey = AIConfig.geminiApiKey;
    if (apiKey.isEmpty) {
      throw Exception('Gemini API key is not configured. Please ensure GEMINI_API_KEY is defined in your environment.');
    }

    final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/${AIConfig.geminiModel}:generateContent?key=$apiKey');

    final response = await http.post(uri,
        headers: {'Content-Type': 'application/json'}, body: body);

    if (response.statusCode != 200) {
      throw Exception(
          'API error ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final text = _extractGeminiText(json);
    final parsed = jsonDecode(text) as Map<String, dynamic>;
    return AIQuizResponse.fromJson(parsed);
  }

  Future<AIQuizResponse> _generateQuizBackend(
      String lessonText, int numQuestions, QuizGenerationConfig config) async {
    final key = IdempotencyService.instance.generateAiKey(
      action: 'quiz',
      contentSnippet: '${lessonText.length}_${numQuestions}_${config.difficulty}',
    );

    final response = await http.post(
      Uri.parse('${AIConfig.pythonBackendUrl}/api/v1/generate-quiz'),
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': AIConfig.pythonApiKey,
        'Idempotency-Key': key,
        'X-Idempotency-Key': key,
      },
      body: jsonEncode({
        'lessonText': lessonText,
        'numQuestions': numQuestions,
        'difficulty': config.difficulty,
        'questionTypes': config.questionTypes,
        'customInstructions': config.customInstructions,
        'includeHints': config.includeHints,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Backend error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return AIQuizResponse.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // Markdown conversion
  // ---------------------------------------------------------------------------

  /// Converts PDF bytes to formatted Markdown.
  Future<String> convertToMarkdown(List<int> bytes) async {
    return AIRateLimitService.instance.runWithRateLimit(
      actionName: 'convertToMarkdown',
      action: () async {
        if (AIConfig.mode == AIExecutionMode.pythonBackend) {
          return _convertToMarkdownBackend(bytes);
        }

        // Client-side: extract text locally, then call Gemini to format as markdown.
        final rawText = await extractTextFromPdf(bytes);

        switch (AIConfig.mode) {
          case AIExecutionMode.firebaseAI:
            return _convertMarkdownFirebase(rawText);
          case AIExecutionMode.directClientSide:
            return _convertMarkdownDirect(rawText);
          case AIExecutionMode.pythonBackend:
            // Handled above
            throw UnimplementedError();
        }
      },
    );
  }

  Future<String> _convertMarkdownFirebase(String rawText) async {
    final model = FirebaseAI.googleAI().generativeModel(
      model: AIConfig.firebaseAIModel,
      systemInstruction: Content.system(_markdownSystemPrompt),
      generationConfig: GenerationConfig(
        temperature: 0.2,
      ),
    );

    final response = await model.generateContent([
      Content.text('Format the following text into Markdown:\n\n$rawText'),
    ]);

    return response.text ?? '';
  }

  Future<String> _convertMarkdownDirect(String rawText) async {
    final body = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': _markdownSystemPrompt}
        ]
      },
      'contents': [
        {
          'parts': [
            {'text': 'Format the following text into Markdown:\n\n$rawText'}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.2,
      },
    });

    final apiKey = AIConfig.geminiApiKey;
    if (apiKey.isEmpty) {
      throw Exception('Gemini API key is not configured. Please ensure GEMINI_API_KEY is defined in your environment.');
    }

    final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/${AIConfig.geminiModel}:generateContent?key=$apiKey');

    final response = await http.post(uri,
        headers: {'Content-Type': 'application/json'}, body: body);

    if (response.statusCode != 200) {
      throw Exception(
          'API error ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return _extractGeminiText(json);
  }

  Future<String> _convertToMarkdownBackend(List<int> bytes) async {
    final baseUrl = AIConfig.pythonBackendUrl;
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/convert/markdown'),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: 'lesson.pdf',
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['markdown'] as String;
      } else {
        debugPrint('API Error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to convert PDF to Markdown.');
      }
    } catch (e) {
      debugPrint('HTTP Error: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Backward-compatible API (used by existing admin tabs)
  // ---------------------------------------------------------------------------

  /// Legacy method used by admin_lessons_tab.dart.
  /// Calls the Python backend's `/generate/lesson` or Gemini directly and
  /// returns the lesson content as a markdown string.
  Future<String> generateLessonFromText(String rawText) async {
    try {
      final lesson = await generateLesson(rawText);
      // Flatten content blocks into markdown-ish text for the old UI.
      final buffer = StringBuffer('# ${lesson.title}\n\n');
      for (final block in lesson.content) {
        switch (block.type) {
          case ContentBlockType.text:
            buffer.writeln('${block.data}\n');
            break;
          case ContentBlockType.list:
            for (final item in (block.data as List)) {
              buffer.writeln('- $item');
            }
            buffer.writeln();
            break;
          case ContentBlockType.table:
            final rows = block.data as List;
            if (rows.isNotEmpty) {
              final headers =
                  (rows.first as Map<String, dynamic>).keys.toList();
              buffer.writeln('| ${headers.join(' | ')} |');
              buffer.writeln('| ${headers.map((_) => '---').join(' | ')} |');
              for (final row in rows) {
                final r = row as Map<String, dynamic>;
                buffer.writeln(
                    '| ${headers.map((h) => r[h]?.toString() ?? '').join(' | ')} |');
              }
              buffer.writeln();
            }
            break;
          case ContentBlockType.image:
            buffer.writeln('![${block.data}]()\n');
            break;
        }
      }
      return buffer.toString();
    } catch (e) {
      debugPrint('generateLessonFromText error: $e');
      return '# AI Generation Failed\n\nError: $e';
    }
  }

  /// Legacy method used by admin_quizzes_tab.dart and admin_assessments_tab.dart.
  /// Returns a list of maps with keys: question, options, correctAnswer.
  Future<List<Map<String, dynamic>>> generateQuizFromText(
      String rawText) async {
    try {
      final quiz = await generateQuiz(rawText);
      return quiz.questions.map((q) {
        // Build a text representation of the question from content blocks.
        final questionText = q.content
            .where((b) => b.type == ContentBlockType.text)
            .map((b) => b.data.toString())
            .join('\n');
        return <String, dynamic>{
          'question': questionText,
          'options': q.options,
          'correctAnswer': q.correctAnswer,
        };
      }).toList();
    } catch (e) {
      debugPrint('generateQuizFromText error: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Health check
  // ---------------------------------------------------------------------------

  /// Pings the Python backend `/health` endpoint.
  /// Returns `true` if the service is healthy.
  Future<bool> checkBackendHealth() async {
    if (AIConfig.mode != AIExecutionMode.pythonBackend) {
      return true; // We don't use the python backend in client-side modes.
    }
    try {
      final response = await http
          .get(Uri.parse('${AIConfig.pythonBackendUrl}/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Generates an image using the free Pollinations AI API.
  Future<Uint8List> generateImageFromPrompt(String prompt) async {
    try {
      final encodedPrompt = Uri.encodeComponent(prompt);
      final uri = Uri.parse('https://image.pollinations.ai/prompt/$encodedPrompt?nologo=true');
      
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'},
      );

      if (response.statusCode != 200) {
        throw Exception('Image API error ${response.statusCode}: ${response.body}');
      }
      
      return response.bodyBytes;
    } catch (e) {
      debugPrint('generateImageFromPrompt error: $e');
      rethrow;
    }
  }

  /// Extracts the text payload from a Gemini REST API response.
  String _extractGeminiText(Map<String, dynamic> json) {
    try {
      final candidates = json['candidates'] as List<dynamic>;
      final firstCandidate = candidates.first as Map<String, dynamic>;
      final contentMap = firstCandidate['content'] as Map<String, dynamic>;
      final parts = contentMap['parts'] as List<dynamic>;
      final firstPart = parts.first as Map<String, dynamic>;
      return firstPart['text'] as String;
    } catch (e) {
      throw Exception('Failed to parse response: $e\nRaw: $json');
    }
  }

  Future<List<Map<String, String>>> generatePracticeWords(String difficulty, int count) async {
    return AIRateLimitService.instance.runWithRateLimit(
      actionName: 'generatePracticeWords',
      action: () async {
        final systemPrompt = '''
You are an expert English teacher.
Output a valid JSON array of exactly $count objects, each with a "word" (an English word appropriate for the $difficulty difficulty level) and a "description" (a brief, simple meaning or definition — 5 to 12 words max. Do NOT include the word itself or its root form in the description).
Example format:
[
  {"word": "ephemeral", "description": "Lasting for a very short time"},
  {"word": "benevolent", "description": "Well-meaning and kindly; showing goodwill"}
]
''';

        List<Map<String, String>> parseWordList(String rawText) {
          final parsedList = jsonDecode(rawText) as List<dynamic>;
          return parsedList.map((e) {
            final map = Map<String, dynamic>.from(e as Map);
            return {
              'word': (map['word'] ?? '').toString(),
              'description': (map['description'] ?? '').toString(),
            };
          }).toList();
        }

        if (AIConfig.mode == AIExecutionMode.directClientSide) {
          final body = jsonEncode({
            'system_instruction': {
              'parts': [{'text': systemPrompt}]
            },
            'contents': [
              {'parts': [{'text': 'Generate $count words for $difficulty difficulty.'}]}
            ],
            'generationConfig': {
              'responseMimeType': 'application/json',
              'temperature': 0.9,
            }
          });

          final apiKey = AIConfig.geminiApiKey;
          if (apiKey.isEmpty) {
            throw Exception('Gemini API key is not configured. Please ensure GEMINI_API_KEY is defined in your environment.');
          }

          final res = await http.post(
            Uri.parse('${AIConfig.geminiBaseUrl}?key=$apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          );

          if (res.statusCode != 200) {
            throw Exception('API error ${res.statusCode}: ${res.body}');
          }

          final data = jsonDecode(res.body);
          final textResponse = data['candidates'][0]['content']['parts'][0]['text'] as String;
          return parseWordList(textResponse);
        }

        try {
          final model = FirebaseAI.googleAI().generativeModel(
            model: AIConfig.firebaseAIModel,
            systemInstruction: Content.system(systemPrompt),
            generationConfig: GenerationConfig(
              responseMimeType: 'application/json',
              temperature: 0.9,
            ),
          );

          final response = await model.generateContent([
            Content.text('Generate $count words for $difficulty difficulty.'),
          ]);

          final text = response.text;
          if (text == null || text.isEmpty) {
            throw Exception('Firebase AI returned empty response.');
          }

          return parseWordList(text);
        } catch (e) {
          debugPrint('Error in generatePracticeWords (Firebase): $e');
          final body = jsonEncode({
            'system_instruction': {
              'parts': [{'text': systemPrompt}]
            },
            'contents': [
              {'parts': [{'text': 'Generate $count words for $difficulty difficulty.'}]}
            ],
            'generationConfig': {
              'responseMimeType': 'application/json',
              'temperature': 0.9,
            }
          });

          final apiKey = AIConfig.geminiApiKey;
          if (apiKey.isEmpty) {
            throw Exception('Gemini API key is not configured. Please ensure GEMINI_API_KEY is defined in your environment.');
          }

          final res = await http.post(
            Uri.parse('${AIConfig.geminiBaseUrl}?key=$apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          );

          if (res.statusCode != 200) {
            throw Exception('API error ${res.statusCode}: ${res.body}');
          }

          final data = jsonDecode(res.body);
          final textResponse = data['candidates'][0]['content']['parts'][0]['text'] as String;
          return parseWordList(textResponse);
        }
      },
    );
  }
}
