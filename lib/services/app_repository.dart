import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppRepository {
  AppRepository._();
  static final instance = AppRepository._();

  final _fs = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _lastLessons = const [];
  List<Map<String, dynamic>> _lastQuizzes = const [];
  List<Map<String, dynamic>> _lastUsers = const [];

  bool _listEquals(List<Map<String, dynamic>> a, List<Map<String, dynamic>> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final m1 = a[i];
      final m2 = b[i];
      if (m1.length != m2.length) return false;
      for (final k in m1.keys) {
        if (m1[k] != m2[k]) return false;
      }
    }
    return true;
  }

  Stream<List<Map<String, dynamic>>> watchLessons() {
    return _fs
        .collection('lessons')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (q) => q.docs
              .map(
                (d) => {
                  'id': d.id,
                  'title': d.data()['title'],
                  'prompt': d.data()['prompt'],
                  'answer': d.data()['answer'],
                  'createdAt': d.data()['createdAt'],
                  'createdByUid': d.data()['createdByUid'],
                  'createdByEmail': d.data()['createdByEmail'],
                },
              )
              .toList(),
        )
        .transform(
          StreamTransformer.fromHandlers(
            handleData: (data, sink) {
              // sort by id to ensure stable comparison
              data.sort(
                (a, b) => (a['id'] as String).compareTo(b['id'] as String),
              );
              if (!_listEquals(_lastLessons, data)) {
                _lastLessons = List<Map<String, dynamic>>.from(data);
                sink.add(_lastLessons);
              }
            },
          ),
        );
  }

  Stream<List<Map<String, dynamic>>> watchQuizzes() {
    return _fs
        .collection('quizzes')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (q) => q.docs
              .map(
                (d) => {
                  'id': d.id,
                  'title': d.data()['title'],
                  'question': d.data()['question'],
                  'answer': d.data()['answer'],
                  'createdAt': d.data()['createdAt'],
                  'createdByUid': d.data()['createdByUid'],
                  'createdByEmail': d.data()['createdByEmail'],
                  'maxAttempts': d.data()['maxAttempts'],
                },
              )
              .toList(),
        )
        .transform(
          StreamTransformer.fromHandlers(
            handleData: (data, sink) {
              data.sort(
                (a, b) => (a['id'] as String).compareTo(b['id'] as String),
              );
              if (!_listEquals(_lastQuizzes, data)) {
                _lastQuizzes = List<Map<String, dynamic>>.from(data);
                sink.add(_lastQuizzes);
              }
            },
          ),
        );
  }

  Stream<List<Map<String, dynamic>>> watchUsers() {
    return _fs
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((q) => q.docs.map((d) => {'uid': d.id, ...d.data()}).toList())
        .transform(
          StreamTransformer.fromHandlers(
            handleData: (data, sink) {
              data.sort(
                (a, b) => (a['uid'] as String).compareTo(b['uid'] as String),
              );
              if (!_listEquals(_lastUsers, data)) {
                _lastUsers = List<Map<String, dynamic>>.from(data);
                sink.add(_lastUsers);
              }
            },
          ),
        );
  }
}
