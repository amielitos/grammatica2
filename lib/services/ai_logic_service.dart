import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';

class AILogicService {
  // Use 10.0.2.2 for Android Emulator, localhost for Web/iOS Simulator/Desktop
  final String _baseUrl = kIsWeb
      ? 'http://localhost:8000'
      : 'http://localhost:8000';

  /// Extracts text from a given PDF file bytes (supports Web).
  Future<String> extractTextFromPdf(List<int> bytes) async {
    try {
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      final String extractedText = PdfTextExtractor(document).extractText();
      document.dispose();
      return extractedText;
    } catch (e) {
      debugPrint('Error extracting text from PDF: $e');
      throw Exception('Failed to read PDF document.');
    }
  }

  /// Calls the Python API to convert raw text to Markdown using the Hugging Face Space
  Future<String> convertTextToMarkdown(String rawText) async {
    final String spaceUrl = "https://amielitos-text-to-markdown-api.hf.space/gradio_api/call/predict";
    try {
      // 1. Send Request
      final response = await http.post(
        Uri.parse(spaceUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"data": [rawText]}),
      );

      if (response.statusCode == 200) {
        final eventId = jsonDecode(response.body)['event_id'];

        // 2. Poll for the stream result
        final streamResponse = await http.get(Uri.parse("$spaceUrl/$eventId"));
        
        // Gradio returns: data: ["The # result"]
        String body = streamResponse.body;
        if (body.contains('data: ["')) {
          String rawMd = body.split('data: ["')[1].split('"]').first;
          // Unescape the string
          return rawMd.replaceAll(r'\n', '\n').replaceAll(r'\"', '"');
        }
      }
      return "Check if Space is awake...";
    } catch (e) {
      debugPrint('HTTP Error: $e');
      return "Connection Error";
    }
  }

  /// Calls the Python API to generate a lesson from text
  Future<String> generateLessonFromText(String rawText) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/generate/lesson'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'rawText': rawText}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['markdown'] as String;
      } else {
        debugPrint('API Error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to generate lesson from API.');
      }
    } catch (e) {
      debugPrint('HTTP Error: $e');
      // Fallback for simple testing if API is off
      return '# API Connection Failed\nPlease ensure the Python API is running at $_baseUrl\\n\\nError: $e';
    }
  }

  /// Calls the Python API to generate quiz questions from text
  Future<List<Map<String, dynamic>>> generateQuizFromText(
    String rawText,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/generate/quiz'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'rawText': rawText}),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        // Cast the list of dicts to the expected Flutter maps format
        return data.map((q) => Map<String, dynamic>.from(q)).toList();
      } else {
        debugPrint('API Error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to generate quiz from API.');
      }
    } catch (e) {
      debugPrint('HTTP Error: $e');
      throw Exception('Failed to connect to Python backend. Is it running?');
    }
  }
}
