import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

import '../config/ai_config.dart';
import '../config/notebook_prompts.dart';
import '../models/notebook_models.dart';
import 'ai_logic_service.dart';

/// Handles extracting text and metadata from varied source formats
/// (PDF, plain text, web URLs, audio recordings, video clips)
/// and uploading assets to Firebase Storage.
class SourceIngestionService {
  SourceIngestionService._();
  static final SourceIngestionService instance = SourceIngestionService._();
  factory SourceIngestionService() => instance;

  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ---------------------------------------------------------------------------
  // PDF Ingestion
  // ---------------------------------------------------------------------------

  /// Ingests a PDF document by extracting its text content via [AILogicService]
  /// and optionally archiving the binary file to Firebase Storage.
  Future<NotebookSource> ingestPdf({
    required String notebookId,
    required String title,
    required List<int> bytes,
    String? filename,
  }) async {
    final cleanTitle = title.isNotEmpty ? title : (filename ?? 'PDF Document');
    String storageUrl = '';

    try {
      if (filename != null && filename.isNotEmpty) {
        storageUrl = await uploadSourceFile(
          notebookId: notebookId,
          bytes: bytes,
          filename: filename,
          contentType: 'application/pdf',
        );
      }
    } catch (e) {
      debugPrint('Warning: PDF upload to storage failed, continuing with extracted text: $e');
    }

    try {
      final extractedText = await AILogicService.instance.extractTextFromPdf(bytes);
      final wordCount = extractedText.trim().split(RegExp(r'\s+')).length;

      return NotebookSource(
        id: '',
        notebookId: notebookId,
        type: SourceType.pdf,
        title: cleanTitle,
        rawContent: extractedText,
        storageUrl: storageUrl.isNotEmpty ? storageUrl : null,
        metadata: {
          'byteLength': bytes.length,
          'wordCount': wordCount,
          'filename': filename,
        },
        createdAt: DateTime.now(),
        processingStatus: SourceProcessingStatus.ready,
      );
    } catch (e) {
      return NotebookSource(
        id: '',
        notebookId: notebookId,
        type: SourceType.pdf,
        title: cleanTitle,
        rawContent: '',
        storageUrl: storageUrl.isNotEmpty ? storageUrl : null,
        metadata: {'byteLength': bytes.length},
        createdAt: DateTime.now(),
        processingStatus: SourceProcessingStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Plain Text Ingestion
  // ---------------------------------------------------------------------------

  /// Ingests raw text or markdown content directly.
  Future<NotebookSource> ingestText({
    required String notebookId,
    required String title,
    required String text,
  }) async {
    final cleanTitle = title.trim().isNotEmpty ? title.trim() : 'Pasted Text Note';
    final sanitizedText = text.trim();
    final wordCount = sanitizedText.split(RegExp(r'\s+')).length;

    return NotebookSource(
      id: '',
      notebookId: notebookId,
      type: SourceType.text,
      title: cleanTitle,
      rawContent: sanitizedText,
      metadata: {
        'characterCount': sanitizedText.length,
        'wordCount': wordCount,
      },
      createdAt: DateTime.now(),
      processingStatus: SourceProcessingStatus.ready,
    );
  }

  // ---------------------------------------------------------------------------
  // Web URL Ingestion
  // ---------------------------------------------------------------------------

  /// Ingests a web page by fetching its HTML and extracting readable text content.
  Future<NotebookSource> ingestUrl({
    required String notebookId,
    required String url,
    String? customTitle,
  }) async {
    try {
      final uri = Uri.parse(url);
      final response = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Grammatica/1.0',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      });

      if (response.statusCode != 200) {
        throw Exception('HTTP error ${response.statusCode}: Failed to fetch URL');
      }

      final document = html_parser.parse(response.body);

      // Remove non-content elements
      document.querySelectorAll('script, style, noscript, nav, footer, header, aside, iframe, svg').forEach((el) {
        el.remove();
      });

      final pageTitle = customTitle?.trim().isNotEmpty == true
          ? customTitle!
          : (document.querySelector('title')?.text.trim() ?? uri.host);

      // Extract text from article, main, or body
      final mainContent = document.querySelector('article') ??
          document.querySelector('main') ??
          document.body;

      final extractedText = (mainContent?.text ?? '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      if (extractedText.isEmpty) {
        throw Exception('No readable text could be extracted from this webpage.');
      }

      final wordCount = extractedText.split(RegExp(r'\s+')).length;

      return NotebookSource(
        id: '',
        notebookId: notebookId,
        type: SourceType.url,
        title: pageTitle,
        rawContent: extractedText,
        originalUrl: url,
        metadata: {
          'host': uri.host,
          'wordCount': wordCount,
        },
        createdAt: DateTime.now(),
        processingStatus: SourceProcessingStatus.ready,
      );
    } catch (e) {
      debugPrint('Error ingesting URL: $e');
      return NotebookSource(
        id: '',
        notebookId: notebookId,
        type: SourceType.url,
        title: customTitle ?? url,
        rawContent: '',
        originalUrl: url,
        createdAt: DateTime.now(),
        processingStatus: SourceProcessingStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Audio Ingestion & Transcription
  // ---------------------------------------------------------------------------

  /// Transcribes audio data into text using Gemini multimodal capabilities,
  /// routing through [AIConfig.mode].
  Future<NotebookSource> ingestAudio({
    required String notebookId,
    required String title,
    required List<int> bytes,
    required String mimeType, // e.g. 'audio/mp3', 'audio/wav', 'audio/m4a'
    String? filename,
  }) async {
    final cleanTitle = title.isNotEmpty ? title : (filename ?? 'Audio Recording');
    String storageUrl = '';

    try {
      if (filename != null && filename.isNotEmpty) {
        storageUrl = await uploadSourceFile(
          notebookId: notebookId,
          bytes: bytes,
          filename: filename,
          contentType: mimeType,
        );
      }
    } catch (e) {
      debugPrint('Warning: Audio upload to storage failed: $e');
    }

    try {
      final transcription = await _transcribeMedia(bytes, mimeType);
      final wordCount = transcription.trim().split(RegExp(r'\s+')).length;

      return NotebookSource(
        id: '',
        notebookId: notebookId,
        type: SourceType.audio,
        title: cleanTitle,
        rawContent: transcription,
        storageUrl: storageUrl.isNotEmpty ? storageUrl : null,
        metadata: {
          'byteLength': bytes.length,
          'mimeType': mimeType,
          'wordCount': wordCount,
        },
        createdAt: DateTime.now(),
        processingStatus: SourceProcessingStatus.ready,
      );
    } catch (e) {
      debugPrint('Error transcribing audio: $e');
      return NotebookSource(
        id: '',
        notebookId: notebookId,
        type: SourceType.audio,
        title: cleanTitle,
        rawContent: '',
        storageUrl: storageUrl.isNotEmpty ? storageUrl : null,
        metadata: {'byteLength': bytes.length, 'mimeType': mimeType},
        createdAt: DateTime.now(),
        processingStatus: SourceProcessingStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Video Ingestion
  // ---------------------------------------------------------------------------

  /// Ingests video by transcribing audio / extracting dialogue and descriptions.
  Future<NotebookSource> ingestVideo({
    required String notebookId,
    required String title,
    required List<int> bytes,
    required String mimeType, // e.g. 'video/mp4'
    String? filename,
  }) async {
    final cleanTitle = title.isNotEmpty ? title : (filename ?? 'Video Clip');
    String storageUrl = '';

    try {
      if (filename != null && filename.isNotEmpty) {
        storageUrl = await uploadSourceFile(
          notebookId: notebookId,
          bytes: bytes,
          filename: filename,
          contentType: mimeType,
        );
      }
    } catch (e) {
      debugPrint('Warning: Video upload to storage failed: $e');
    }

    try {
      final summary = await _transcribeMedia(bytes, mimeType);
      final wordCount = summary.trim().split(RegExp(r'\s+')).length;

      return NotebookSource(
        id: '',
        notebookId: notebookId,
        type: SourceType.video,
        title: cleanTitle,
        rawContent: summary,
        storageUrl: storageUrl.isNotEmpty ? storageUrl : null,
        metadata: {
          'byteLength': bytes.length,
          'mimeType': mimeType,
          'wordCount': wordCount,
        },
        createdAt: DateTime.now(),
        processingStatus: SourceProcessingStatus.ready,
      );
    } catch (e) {
      debugPrint('Error transcribing video: $e');
      return NotebookSource(
        id: '',
        notebookId: notebookId,
        type: SourceType.video,
        title: cleanTitle,
        rawContent: '',
        storageUrl: storageUrl.isNotEmpty ? storageUrl : null,
        metadata: {'byteLength': bytes.length, 'mimeType': mimeType},
        createdAt: DateTime.now(),
        processingStatus: SourceProcessingStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Multimodal Media Transcription (Audio & Video)
  // ---------------------------------------------------------------------------

  Future<String> _transcribeMedia(List<int> bytes, String mimeType) async {
    switch (AIConfig.mode) {
      case AIExecutionMode.firebaseAI:
        return _transcribeMediaFirebase(bytes, mimeType);
      case AIExecutionMode.directClientSide:
        return _transcribeMediaDirect(bytes, mimeType);
      case AIExecutionMode.pythonBackend:
        return _transcribeMediaBackend(bytes, mimeType);
    }
  }

  Future<String> _transcribeMediaFirebase(List<int> bytes, String mimeType) async {
    final model = FirebaseAI.googleAI().generativeModel(
      model: AIConfig.firebaseAIModel,
      systemInstruction: Content.system(NotebookPrompts.audioTranscriptionPrompt),
    );

    final response = await model.generateContent([
      Content.multi([
        TextPart('Transcribe this recording completely and accurately. Provide the transcript text:'),
        InlineDataPart(mimeType, Uint8List.fromList(bytes)),
      ]),
    ]);

    final text = response.text;
    if (text == null || text.trim().isEmpty) {
      throw Exception('Firebase AI returned an empty transcription.');
    }
    return text.trim();
  }

  Future<String> _transcribeMediaDirect(List<int> bytes, String mimeType) async {
    final base64Media = base64Encode(bytes);

    final body = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': NotebookPrompts.audioTranscriptionPrompt}
        ]
      },
      'contents': [
        {
          'parts': [
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Media,
              }
            },
            {
              'text': 'Transcribe this recording completely and accurately. Provide the transcript text:'
            }
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.2,
      },
    });

    final uri = Uri.parse('${AIConfig.geminiBaseUrl}?key=${AIConfig.geminiApiKey}');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini REST transcription failed (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No candidate response from Gemini transcription.');
    }
    final first = candidates.first as Map<String, dynamic>;
    final parts = first['content']?['parts'] as List<dynamic>?;
    final text = parts?.first?['text'] as String?;
    return text?.trim() ?? '';
  }

  Future<String> _transcribeMediaBackend(List<int> bytes, String mimeType) async {
    final uri = Uri.parse('${AIConfig.pythonBackendUrl}/api/v1/transcribe');
    final request = http.MultipartRequest('POST', uri);
    request.headers['X-API-Key'] = AIConfig.pythonApiKey;
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: 'recording.${mimeType.split('/').last}',
    ));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception('Backend error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['transcription'] as String? ?? '';
  }

  // ---------------------------------------------------------------------------
  // Firebase Storage Helper
  // ---------------------------------------------------------------------------

  /// Uploads binary files to Firebase Storage in `notebooks/{notebookId}/sources/{filename}`.
  Future<String> uploadSourceFile({
    required String notebookId,
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final ref = _storage.ref().child('notebooks/$notebookId/sources/${timestamp}_$safeName');

    final uploadTask = ref.putData(
      Uint8List.fromList(bytes),
      SettableMetadata(contentType: contentType),
    );

    final snapshot = await uploadTask;
    return snapshot.ref.getDownloadURL();
  }
}
