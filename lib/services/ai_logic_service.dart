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

  /// Calls the Python API to convert PDF bytes to Markdown using MarkItDown
  Future<String> convertToMarkdown(List<int> bytes) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/convert/markdown'),
      );

      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: 'lesson.pdf'),
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
