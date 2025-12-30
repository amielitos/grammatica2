import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Lesson {
  final String id;
  final String title;
  final String prompt;
  final String answer;

  Lesson({required this.id, required this.title, required this.prompt, required this.answer});

  factory Lesson.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Lesson(
      id: doc.id,
      title: (data['title'] ?? '').toString(),
      prompt: (data['prompt'] ?? '').toString(),
      answer: (data['answer'] ?? '').toString(),
    );
  }
}

class DatabaseService {
  DatabaseService._();
  static final instance = DatabaseService._();

  final _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _lessons => _firestore.collection('lessons');
  CollectionReference<Map<String, dynamic>> _userProgress(String uid) => _firestore.collection('users').doc(uid).collection('progress');

  // Admin CRUD
  Future<String> createLesson({required String title, required String prompt, required String answer}) async {
    final doc = await _lessons.add({
      'title': title,
      'prompt': prompt,
      'answer': answer,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> updateLesson({required String id, String? title, String? prompt, String? answer}) async {
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
    final snapshot = await _lessons.orderBy('createdAt', descending: false).get();
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

  Future<void> markLessonCompleted({required User user, required String lessonId}) async {
    await _userProgress(user.uid).doc(lessonId).set({'completed': true, 'completedAt': FieldValue.serverTimestamp()});
  }
}
