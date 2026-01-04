import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ImageUpload {
  final String id;
  final String userId;
  final String imageUrl;
  final String fileName;
  final Timestamp? uploadedAt;
  final String? description;

  ImageUpload({
    required this.id,
    required this.userId,
    required this.imageUrl,
    required this.fileName,
    this.uploadedAt,
    this.description,
  });

  factory ImageUpload.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ImageUpload(
      id: doc.id,
      userId: (data['userId'] ?? '').toString(),
      imageUrl: (data['imageUrl'] ?? '').toString(),
      fileName: (data['fileName'] ?? '').toString(),
      uploadedAt: data['uploadedAt'] as Timestamp?,
      description: (data['description'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'imageUrl': imageUrl,
      'fileName': fileName,
      'uploadedAt': uploadedAt ?? FieldValue.serverTimestamp(),
      'description': description,
    };
  }
}

class Lesson {
  final String id;
  final String title;
  final String prompt;
  final String answer;
  final Timestamp? createdAt;
  final String? createdByUid;
  final String? createdByEmail;

  Lesson({
    required this.id,
    required this.title,
    required this.prompt,
    required this.answer,
    this.createdAt,
    this.createdByUid,
    this.createdByEmail,
  });

  factory Lesson.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Lesson(
      id: doc.id,
      title: (data['title'] ?? '').toString(),
      prompt: (data['prompt'] ?? '').toString(),
      answer: (data['answer'] ?? '').toString(),
      createdAt: data['createdAt'] as Timestamp?,
      createdByUid: (data['createdByUid'] ?? '') == ''
          ? null
          : (data['createdByUid'] as String?),
      createdByEmail: (data['createdByEmail'] ?? '') == ''
          ? null
          : (data['createdByEmail'] as String?),
    );
  }
}

class Quiz {
  final String id;
  final String title;
  final String question; // markdown-supported
  final String answer; // expected answer (plain text compare or normalized)
  final Timestamp? createdAt;
  final String? createdByUid;
  final String? createdByEmail;
  Quiz({
    required this.id,
    required this.title,
    required this.question,
    required this.answer,
    this.createdAt,
    this.createdByUid,
    this.createdByEmail,
  });
  factory Quiz.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Quiz(
      id: doc.id,
      title: (d['title'] ?? '').toString(),
      question: (d['question'] ?? '').toString(),
      answer: (d['answer'] ?? '').toString(),
      createdAt: d['createdAt'] as Timestamp?,
      createdByUid: (d['createdByUid'] ?? '') == ''
          ? null
          : (d['createdByUid'] as String?),
      createdByEmail: (d['createdByEmail'] ?? '') == ''
          ? null
          : (d['createdByEmail'] as String?),
    );
  }
}

class DatabaseService {
  DatabaseService._();
  static final instance = DatabaseService._();

  final _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _lessons =>
      _firestore.collection('lessons');
  CollectionReference<Map<String, dynamic>> get _quizzes =>
      _firestore.collection('quizzes');
  CollectionReference<Map<String, dynamic>> _userProgress(String uid) =>
      _firestore.collection('users').doc(uid).collection('progress');
  CollectionReference<Map<String, dynamic>> _userQuizProgress(String uid) =>
      _firestore.collection('users').doc(uid).collection('quizProgress');

  // Admin CRUD - Lessons
  Future<String> createLesson({
    required String title,
    required String prompt,
    required String answer,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final doc = await _lessons.add({
      'title': title,
      'prompt': prompt,
      'answer': answer,
      'createdAt': FieldValue.serverTimestamp(),
      'createdByUid': user?.uid,
      'createdByEmail': user?.email,
    });
    return doc.id;
  }

  Future<void> updateLesson({
    required String id,
    String? title,
    String? prompt,
    String? answer,
  }) async {
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (prompt != null) data['prompt'] = prompt;
    if (answer != null) data['answer'] = answer;
    if (data.isNotEmpty) {
      await _lessons.doc(id).update(data);
    }
  }

  Future<void> deleteLesson(String id) async {
    await _lessons.doc(id).delete();
  }

  Future<Lesson?> getLessonById(String id) async {
    final doc = await _lessons.doc(id).get();
    if (!doc.exists) return null;
    return Lesson.fromDoc(doc);
  }

  Future<void> _seedPlaceholderIfEmpty() async {
    final count = await _lessons.limit(1).get();
    if (count.size == 0) {
      await _lessons.add({
        'title': 'Sample: Articles',
        'prompt': 'Fill in: __ apple a day keeps __ doctor away.',
        'answer': 'An the',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<List<Lesson>> fetchLessons() async {
    await _seedPlaceholderIfEmpty();
    final snapshot = await _lessons
        .orderBy('createdAt', descending: false)
        .get();
    return snapshot.docs.map(Lesson.fromDoc).toList();
  }

  Stream<Map<String, bool>> progressStream(User user) {
    return _userProgress(user.uid).snapshots().map((q) {
      final map = <String, bool>{};
      for (final d in q.docs) {
        map[d.id] = (d.data()['completed'] == true);
      }
      return map;
    });
  }

  Future<void> markLessonCompleted({
    required User user,
    required String lessonId,
  }) async {
    await _userProgress(user.uid).doc(lessonId).set({
      'completed': true,
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  // Quizzes API
  /* stray duplicated body removed */
  /*
      'title': title,
      'question': question,
      'answer': answer,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
 */

  Future<String> createQuiz({
    required String title,
    required String question,
    required String answer,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final doc = await _quizzes.add({
      'title': title,
      'question': question,
      'answer': answer,
      'createdAt': FieldValue.serverTimestamp(),
      'createdByUid': user?.uid,
      'createdByEmail': user?.email,
    });
    return doc.id;
  }

  Future<void> updateQuiz({
    required String id,
    String? title,
    String? question,
    String? answer,
  }) async {
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (question != null) data['question'] = question;
    if (answer != null) data['answer'] = answer;
    if (data.isNotEmpty) {
      await _quizzes.doc(id).update(data);
    }
  }

  Future<void> deleteQuiz(String id) async {
    await _quizzes.doc(id).delete();
  }

  Future<List<Quiz>> fetchQuizzes() async {
    final snap = await _quizzes.orderBy('createdAt', descending: false).get();
    return snap.docs.map(Quiz.fromDoc).toList();
  }

  Future<void> markQuizCompleted({
    required User user,
    required String quizId,
    String? answer,
  }) async {
    await _userQuizProgress(user.uid).doc(quizId).set({
      'completed': true,
      'answer': answer,
      'completedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<Map<String, bool>> quizProgressStream(User user) {
    return _userQuizProgress(user.uid).snapshots().map((q) {
      final map = <String, bool>{};
      for (final d in q.docs) {
        map[d.id] = (d.data()['completed'] == true);
      }
      return map;
    });
  }

  // Image Upload API
  CollectionReference<Map<String, dynamic>> get _images =>
      _firestore.collection('images');

  Future<String> uploadImage({
    required String userId,
    required Uint8List imageBytes,
    required String fileName,
    String? description,
  }) async {
    try {
      // Upload image to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('user_images')
          .child(userId)
          .child(fileName);

      final uploadTask = storageRef.putData(
        imageBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final snapshot = await uploadTask.whenComplete(() => null);
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Save image metadata to Firestore
      final imageDoc = await _images.add({
        'userId': userId,
        'imageUrl': downloadUrl,
        'fileName': fileName,
        'uploadedAt': FieldValue.serverTimestamp(),
        'description': description ?? '',
      });

      return imageDoc.id;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  Future<List<ImageUpload>> fetchUserImages(String userId) async {
    final snapshot = await _images
        .where('userId', isEqualTo: userId)
        .orderBy('uploadedAt', descending: true)
        .get();
    return snapshot.docs.map(ImageUpload.fromDoc).toList();
  }

  Future<void> deleteImage(String imageId, String imageUrl) async {
    try {
      // Delete from Firestore
      await _images.doc(imageId).delete();

      // Extract file path from URL and delete from Storage
      final RegExp regExp = RegExp(r'/(.+)/o/(.+)\?');
      final Match? match = regExp.firstMatch(imageUrl);
      if (match != null) {
        final filePath = match.group(2);
        if (filePath != null) {
          final storageRef = FirebaseStorage.instance.ref().child(filePath);
          await storageRef.delete();
        }
      }
    } catch (e) {
      throw Exception('Failed to delete image: $e');
    }
  }
}
