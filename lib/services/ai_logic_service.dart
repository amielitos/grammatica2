import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:firebase_ai/firebase_ai.dart';

import '../config/ai_config.dart';
import '../models/ai_models.dart';

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
   - "image": data is a descriptive prompt string describing an image, diagram, or illustration that would help the learner understand the concept. Be very specific about what the image should depict.
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
    final questionTypesStr = config.questionTypes.isNotEmpty
        ? config.questionTypes.map((t) => '"$t"').join(', ')
        : '"multiple_choice", "fill_in_the_blank", "passage"';

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
You are Grammatica AI, an expert quiz creator. Your task is to generate a set of quiz questions based on the provided lesson content.

Difficulty level: ${config.difficulty.toUpperCase()}
$difficultyInstruction

Rules:
1. The JSON must follow this exact structure:
   {
     "title": "<A catchy title for the quiz>",
     "description": "<A short description of the quiz>",
     "questions": [<array of question objects>]
   }
2. Each question object MUST have these exact fields:
   - "questionType": one of $questionTypesStr
   - "question": a string containing the question text or the passage text if type is passage.
   - "options": array of strings (required for multiple_choice; use empty array [] for fill_in_the_blank or passage)
   - "correctAnswer": string with the correct answer (MUST be provided for fill_in_the_blank and multiple_choice; use empty string "" for passage)
$hintLine
$explanationLine
3. Only use the question types listed above. Distribute questions across the allowed types.
4. For true_false questions, options MUST be exactly ["True", "False"].
5. For multiple_choice, provide 3-4 options.
6. Make questions that test comprehension, not just memorization.
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
    switch (AIConfig.mode) {
      case AIExecutionMode.firebaseAI:
        return _generateLessonFirebase(rawText);
      case AIExecutionMode.directClientSide:
        return _generateLessonDirect(rawText);
      case AIExecutionMode.pythonBackend:
        return _generateLessonBackend(rawText);
    }
  }

  Future<AILessonResponse> _generateLessonFirebase(String rawText) async {
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
      throw Exception('Firebase AI returned empty response.');
    }

    final parsed = jsonDecode(text) as Map<String, dynamic>;
    return AILessonResponse.fromJson(parsed);
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

    final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/${AIConfig.geminiModel}:generateContent?key=${AIConfig.geminiApiKey}');

    final response = await http.post(uri,
        headers: {'Content-Type': 'application/json'}, body: body);

    if (response.statusCode != 200) {
      throw Exception(
          'Gemini API error ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final text = _extractGeminiText(json);
    final parsed = jsonDecode(text) as Map<String, dynamic>;
    return AILessonResponse.fromJson(parsed);
  }

  Future<AILessonResponse> _generateLessonBackend(String rawText) async {
    // The `/api/v1/extract-lesson` endpoint only accepts PDFs via multipart.
    // For text-only generation we fall back to the old `/api/v1/generate-lesson`
    // route which accepts a JSON body.
    final response = await http.post(
      Uri.parse('${AIConfig.pythonBackendUrl}/api/v1/generate-lesson'),
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': AIConfig.pythonApiKey,
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

    final request = http.MultipartRequest('POST', uri);
    request.headers['X-API-Key'] = AIConfig.pythonApiKey;
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
    switch (AIConfig.mode) {
      case AIExecutionMode.firebaseAI:
        return _generateQuizFirebase(lessonText, numQuestions, config);
      case AIExecutionMode.directClientSide:
        return _generateQuizDirect(lessonText, numQuestions, config);
      case AIExecutionMode.pythonBackend:
        return _generateQuizBackend(lessonText, numQuestions, config);
    }
  }

  /// Builds the user-facing prompt text for quiz generation.
  String _buildQuizUserPrompt(String lessonText, int numQuestions) {
    return 'Generate $numQuestions quiz questions based on the following lesson '
        'content.\n\n$lessonText';
  }

  Future<AIQuizResponse> _generateQuizFirebase(
      String lessonText, int numQuestions, QuizGenerationConfig config) async {
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
      throw Exception('Firebase AI returned empty response.');
    }

    final parsed = jsonDecode(text) as Map<String, dynamic>;
    return AIQuizResponse.fromJson(parsed);
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

    final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/${AIConfig.geminiModel}:generateContent?key=${AIConfig.geminiApiKey}');

    final response = await http.post(uri,
        headers: {'Content-Type': 'application/json'}, body: body);

    if (response.statusCode != 200) {
      throw Exception(
          'Gemini API error ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final text = _extractGeminiText(json);
    final parsed = jsonDecode(text) as Map<String, dynamic>;
    return AIQuizResponse.fromJson(parsed);
  }

  Future<AIQuizResponse> _generateQuizBackend(
      String lessonText, int numQuestions, QuizGenerationConfig config) async {
    final response = await http.post(
      Uri.parse('${AIConfig.pythonBackendUrl}/api/v1/generate-quiz'),
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': AIConfig.pythonApiKey,
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

    final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/${AIConfig.geminiModel}:generateContent?key=${AIConfig.geminiApiKey}');

    final response = await http.post(uri,
        headers: {'Content-Type': 'application/json'}, body: body);

    if (response.statusCode != 200) {
      throw Exception(
          'Gemini API error ${response.statusCode}: ${response.body}');
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
      throw Exception('Failed to parse Gemini response: $e\nRaw: $json');
    }
  }
}
