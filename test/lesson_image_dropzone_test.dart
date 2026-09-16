import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammatica/models/ai_models.dart';
import 'package:grammatica/widgets/lesson_image_dropzone.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 1x1 transparent PNG bytes for testing memory image rendering
  final testImageBytes = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  group('LessonImageDropzone Widget Tests', () {
    testWidgets('Renders empty placeholder state with AI prompt and upload guidance', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LessonImageDropzone(
              imagePrompt: 'Diagram of grammar trees and noun clauses',
              onImageSelected: (bytes, name) async {},
              isDark: false,
            ),
          ),
        ),
      );

      expect(find.text('Drag & drop photo or click to upload'), findsOneWidget);
      expect(find.text('Supports PNG, JPG, JPEG, WEBP, or GIF'), findsOneWidget);
      expect(find.text('Diagram of grammar trees and noun clauses'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
      expect(find.byIcon(Icons.lightbulb_outline_rounded), findsOneWidget);
    });

    testWidgets('Renders uploading indicator and custom status when isUploading is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LessonImageDropzone(
              imagePrompt: 'Sample visual prompt',
              isUploading: true,
              uploadStatus: 'Uploading photo to lesson storage...',
              onImageSelected: (bytes, name) async {},
              isDark: false,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Uploading photo to lesson storage...'), findsOneWidget);
      expect(find.text('Compressing and attaching visual aid to lesson'), findsOneWidget);
    });

    testWidgets('Renders image preview and buttons when pendingBytes is present', (tester) async {
      bool removeTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LessonImageDropzone(
              imagePrompt: 'Parts of speech illustration',
              pendingBytes: testImageBytes,
              onImageSelected: (bytes, name) async {},
              onRemoveImage: () => removeTapped = true,
              isDark: false,
            ),
          ),
        ),
      );

      expect(find.text('Visual Aid Ready'), findsOneWidget);
      expect(find.text('Parts of speech illustration'), findsOneWidget);
      expect(find.text('Change Photo'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);

      await tester.tap(find.text('Remove'));
      await tester.pump();
      expect(removeTapped, isTrue);
    });
  });

  group('AI Models Image Block Serialization Tests', () {
    test('ContentBlock correctly serializes and deserializes imageUrl', () {
      final block = ContentBlock(
        type: ContentBlockType.image,
        data: 'Diagram of adjectives',
        imageUrl: 'https://firebasestorage.googleapis.com/v0/b/grammatica/o/test.png',
      );

      final json = block.toJson();
      expect(json['type'], equals('image'));
      expect(json['data'], equals('Diagram of adjectives'));
      expect(json['imageUrl'], equals('https://firebasestorage.googleapis.com/v0/b/grammatica/o/test.png'));

      final fromJson = ContentBlock.fromJson(json);
      expect(fromJson.type, equals(ContentBlockType.image));
      expect(fromJson.data, equals('Diagram of adjectives'));
      expect(fromJson.imageUrl, equals('https://firebasestorage.googleapis.com/v0/b/grammatica/o/test.png'));
    });

    test('toMarkdownContent writes ![alt](url) when imageUrl is present', () {
      final lessonWithImage = AILessonResponse(
        title: 'Adjectives Lesson',
        content: [
          const ContentBlock(type: ContentBlockType.text, data: 'Introduction to Adjectives'),
          const ContentBlock(
            type: ContentBlockType.image,
            data: 'Adjective chart',
            imageUrl: 'https://firebasestorage.googleapis.com/img123.png',
          ),
        ],
      );

      final md = lessonWithImage.toMarkdownContent();
      expect(md, contains('![Adjective chart](https://firebasestorage.googleapis.com/img123.png)'));
      expect(md, isNot(contains('[Image Placeholder:')));
    });

    test('toMarkdownContent writes placeholder when imageUrl is null', () {
      final lessonWithoutImage = AILessonResponse(
        title: 'Verbs Lesson',
        content: [
          const ContentBlock(
            type: ContentBlockType.image,
            data: 'Verb tenses diagram',
          ),
        ],
      );

      final md = lessonWithoutImage.toMarkdownContent();
      expect(md, contains('[Image Placeholder: Verb tenses diagram]'));
    });
  });
}
