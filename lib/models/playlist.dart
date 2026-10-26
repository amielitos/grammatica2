import 'package:cloud_firestore/cloud_firestore.dart';

class LessonPlaylist {
  final String id;
  final String title;
  final String description;
  final String createdByUid;
  final String createdByEmail;
  final List<String> lessonIds;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  LessonPlaylist({
    required this.id,
    required this.title,
    required this.description,
    required this.createdByUid,
    required this.createdByEmail,
    required this.lessonIds,
    this.createdAt,
    this.updatedAt,
  });

  factory LessonPlaylist.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return LessonPlaylist(
      id: doc.id,
      title: (data['title'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      createdByUid: (data['createdByUid'] ?? '').toString(),
      createdByEmail: (data['createdByEmail'] ?? '').toString(),
      lessonIds: List<String>.from(data['lessonIds'] ?? []),
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'createdByUid': createdByUid,
      'createdByEmail': createdByEmail,
      'lessonIds': lessonIds,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
