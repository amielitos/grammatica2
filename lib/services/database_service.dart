import 'package:flutter/foundation.dart';
import 'package:grammatica/services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import '../models/notification.dart';
import 'email_sender_service.dart';
import 'role_service.dart';
import 'notebook_service.dart';
import '../models/spelling_word.dart';
import '../models/notebook_models.dart';
import '../models/published_content_item.dart';
import '../models/playlist.dart';
import '../utils/image_utils.dart';
import 'idempotency_service.dart';
import 'badge_service.dart';

/// Result of an idempotent payment recording transaction.
class PaymentRecordResult {
  final bool isSuccess;
  final bool isDuplicate;
  final String paymentId;
  final String message;

  const PaymentRecordResult({
    required this.isSuccess,
    required this.isDuplicate,
    required this.paymentId,
    required this.message,
  });
}

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

class EducatorApplication {
  final String id;
  final String applicantUid;
  final String applicantEmail;
  final String cvUrl;
  final List<String> certificateUrls;
  final String videoUrl;
  final String syllabusUrl;
  final String status; // 'pending', 'approved', 'rejected'
  final String applicationType; // 'educator', 'validator'
  final Timestamp? appliedAt;
  final Timestamp? rejectedAt;
  final Timestamp? reviewedAt;
  final String? rejectionReason;
  final String? rejectionDescription;
  final String? cvFileName;
  final List<String>? certificateFileNames;
  final String? videoFileName;
  final String? syllabusFileName;

  EducatorApplication({
    required this.id,
    required this.applicantUid,
    required this.applicantEmail,
    required this.cvUrl,
    required this.certificateUrls,
    required this.videoUrl,
    required this.syllabusUrl,
    required this.status,
    required this.applicationType,
    required this.appliedAt,
    this.rejectedAt,
    this.reviewedAt,
    this.rejectionReason,
    this.rejectionDescription,
    this.cvFileName,
    this.certificateFileNames,
    this.videoFileName,
    this.syllabusFileName,
  });

  factory EducatorApplication.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return EducatorApplication(
      id: doc.id,
      applicantUid: data['applicantUid'] ?? '',
      applicantEmail: data['applicantEmail'] ?? '',
      cvUrl: data['cvUrl'] ?? '',
      certificateUrls: (data['certificateUrls'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? 
                       (data['certificateUrl'] != null && data['certificateUrl'].toString().isNotEmpty 
                           ? [data['certificateUrl'].toString()] 
                           : <String>[]),
      videoUrl: data['videoUrl'] ?? '',
      syllabusUrl: data['syllabusUrl'] ?? '',
      status: data['status'] ?? 'pending',
      applicationType: data['applicationType'] ?? 'educator',
      appliedAt: data['appliedAt'] as Timestamp?,
      rejectedAt: (data['rejectedAt'] as Timestamp?) ?? (data['reviewedAt'] as Timestamp?),
      reviewedAt: (data['reviewedAt'] as Timestamp?) ?? (data['approvedAt'] as Timestamp?),
      rejectionReason: (data['rejectionReason'] as String?)?.isNotEmpty == true ? data['rejectionReason'] as String? : null,
      rejectionDescription: (data['rejectionDescription'] as String?)?.isNotEmpty == true ? data['rejectionDescription'] as String? : null,
      cvFileName: data['cvFileName'] as String?,
      certificateFileNames: (data['certificateFileNames'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      videoFileName: data['videoFileName'] as String?,
      syllabusFileName: data['syllabusFileName'] as String?,
    );
  }

  bool get isSexualMisconductRejection {
    final reason = (rejectionReason ?? '').toLowerCase();
    final desc = (rejectionDescription ?? '').toLowerCase();
    return reason.contains('sexual') || desc.contains('sexual misconduct');
  }

  DateTime? get reapplyAvailableAt {
    if (status != 'rejected' || isSexualMisconductRejection) return null;
    final baseDate = (rejectedAt ?? appliedAt)?.toDate();
    if (baseDate == null) return null;
    return baseDate.add(const Duration(days: 7));
  }

  bool get canReapplyNow {
    if (status != 'rejected') return false;
    if (isSexualMisconductRejection) return false;
    final availableAt = reapplyAvailableAt;
    if (availableAt == null) return true;
    return !DateTime.now().isBefore(availableAt);
  }

  int get daysUntilReapply {
    final availableAt = reapplyAvailableAt;
    if (availableAt == null) return 0;
    final diff = availableAt.difference(DateTime.now());
    if (diff.isNegative || diff.inSeconds <= 0) return 0;
    final days = (diff.inHours / 24).ceil();
    return days < 1 ? 1 : days;
  }

  String get prcUrl => certificateUrls.isNotEmpty ? certificateUrls.first : '';
  String? get prcFileName => certificateFileNames?.isNotEmpty == true ? certificateFileNames!.first : null;

  Map<String, dynamic> toMap() {
    return {
      'applicantUid': applicantUid,
      'applicantEmail': applicantEmail,
      'cvUrl': cvUrl,
      'certificateUrls': certificateUrls,
      'videoUrl': videoUrl,
      'syllabusUrl': syllabusUrl,
      'status': status,
      'applicationType': applicationType,
      'appliedAt': appliedAt ?? FieldValue.serverTimestamp(),
      if (cvFileName != null) 'cvFileName': cvFileName,
      if (certificateFileNames != null) 'certificateFileNames': certificateFileNames,
      if (videoFileName != null) 'videoFileName': videoFileName,
      if (syllabusFileName != null) 'syllabusFileName': syllabusFileName,
    };
  }
}

class Lesson {
  final String id;
  final String title;
  final String prompt;
  final String answer;
  final Timestamp? createdAt;
  final Timestamp? reviewedAt;
  final String? createdByUid;
  final String? createdByEmail;
  final String? attachmentUrl;
  final String? attachmentName;
  final String validationStatus; // 'approved', 'awaiting_approval', 'rejected'
  final bool isVisible;
  final List<String> visibleTo;
  final bool isMembersOnly;
  final bool isGrammaticaLesson;
  final String? quizId;
  final String? imageUrl;
  final String? notebookId;
  final String? rejectionReason;
  final String? rejectionDescription;
  final bool isArchived;
  final Timestamp? archivedAt;
  final Timestamp? purgeAt;
  final bool isUpdate;

  /// Semantic alias for [notebookId] to identify the unified content bundle.
  String? get bundleId => notebookId;

  /// Semantic alias for the lesson's rich markdown text stored in [answer].
  String get markdown => answer;

  Lesson({
    required this.id,
    required this.title,
    required this.prompt,
    required this.answer,
    this.createdAt,
    this.reviewedAt,
    this.createdByUid,
    this.createdByEmail,
    this.attachmentUrl,
    this.attachmentName,
    this.validationStatus = 'approved',
    this.isVisible = true,
    this.visibleTo = const [],
    this.isMembersOnly = false,
    this.isGrammaticaLesson = false,
    this.quizId,
    this.imageUrl,
    this.notebookId,
    this.rejectionReason,
    this.rejectionDescription,
    this.isArchived = false,
    this.archivedAt,
    this.purgeAt,
    this.isUpdate = false,
  });

  factory Lesson.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Lesson(
      id: doc.id,
      title: (data['title'] ?? '').toString(),
      prompt: (data['prompt'] ?? '').toString(),
      answer: (data['answer'] ?? '').toString(),
      createdAt: data['createdAt'] as Timestamp?,
      reviewedAt: (data['reviewedAt'] as Timestamp?) ?? (data['approvedAt'] as Timestamp?),
      createdByUid: (data['createdByUid'] ?? '') == ''
          ? null
          : (data['createdByUid'] as String?),
      createdByEmail: (data['createdByEmail'] ?? '') == ''
          ? null
          : (data['createdByEmail'] as String?),
      attachmentUrl: (data['attachmentUrl'] ?? '').toString(),
      attachmentName: (data['attachmentName'] ?? '').toString(),
      validationStatus: (data['validationStatus'] ?? 'approved').toString(),
      isVisible: data['isVisible'] ?? true,
      visibleTo: List<String>.from(data['visibleTo'] ?? []),
      isMembersOnly: data['isMembersOnly'] ?? false,
      isGrammaticaLesson: data['isGrammaticaLesson'] ?? false,
      quizId: (data['quizId'] ?? '') == '' ? null : (data['quizId'] as String?),
      imageUrl: (data['imageUrl'] ?? '').toString() == '' ? null : (data['imageUrl'] as String?),
      notebookId: (data['notebookId'] ?? '') == '' ? null : (data['notebookId'] as String?),
      rejectionReason: (data['rejectionReason'] as String?)?.isNotEmpty == true ? data['rejectionReason'] as String? : null,
      rejectionDescription: (data['rejectionDescription'] as String?)?.isNotEmpty == true ? data['rejectionDescription'] as String? : null,
      isArchived: (data['isArchived'] as bool?) ?? false,
      archivedAt: data['archivedAt'] as Timestamp?,
      purgeAt: data['purgeAt'] as Timestamp?,
      isUpdate: (data['isUpdate'] as bool?) ?? false,
    );
  }
}

/// Represents an aggregated bundle of companion learning materials generated
/// together from the same AI notebook (e.g. Lesson, Quiz, Flashcard Deck, Mind Map).
class LinkedContentBundle {
  final String? notebookId;
  final Lesson? lesson;
  final Quiz? quiz;
  final List<PublishedContentItem> publishedItems;

  const LinkedContentBundle({
    this.notebookId,
    this.lesson,
    this.quiz,
    this.publishedItems = const [],
  });

  bool get hasMultipleItems => totalCount > 1;

  int get totalCount =>
      (lesson != null ? 1 : 0) +
      (quiz != null ? 1 : 0) +
      publishedItems.length;

  bool get isEmpty => totalCount == 0;
}

class QuizQuestion {
  final String question;
  final String answer;
  final String type; // 'text', 'multiple_choice', 'image', 'fill_in_the_blank', 'pronunciation'
  final List<String>? options;
  final String? hint;
  final String? explanation;
  final String? imageUrl;
  final String? imageDescription;
  final List<String>? blankAnswers;
  final String? targetWord;

  QuizQuestion({
    required this.question,
    required this.answer,
    this.type = 'text',
    this.options,
    this.hint,
    this.explanation,
    this.imageUrl,
    this.imageDescription,
    this.blankAnswers,
    this.targetWord,
  });

  factory QuizQuestion.fromMap(Map<String, dynamic> map) {
    return QuizQuestion(
      question: (map['question'] ?? '').toString(),
      answer: (map['answer'] ?? '').toString(),
      type: (map['type'] ?? 'text').toString(),
      options: map['options'] != null
          ? List<String>.from(map['options'])
          : null,
      hint: map['hint'] as String?,
      explanation: map['explanation'] as String?,
      imageUrl: map['imageUrl'] as String?,
      imageDescription: map['imageDescription'] as String?,
      blankAnswers: map['blankAnswers'] != null
          ? List<String>.from(map['blankAnswers'])
          : null,
      targetWord: map['targetWord'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'answer': answer,
      'type': type,
      'options': options,
      if (hint != null) 'hint': hint,
      if (explanation != null) 'explanation': explanation,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (imageDescription != null) 'imageDescription': imageDescription,
      if (blankAnswers != null) 'blankAnswers': blankAnswers,
      if (targetWord != null) 'targetWord': targetWord,
    };
  }
}

class Quiz {
  final String id;
  final String title;
  final String description;
  final List<QuizQuestion> questions;
  final int duration; // in minutes
  final int maxAttempts;
  final Timestamp? createdAt;
  final String? createdByUid;
  final String? createdByEmail;
  final String? attachmentUrl;
  final String? attachmentName;
  final String validationStatus; // 'approved', 'awaiting_approval', 'rejected'
  final bool isVisible;
  final List<String> visibleTo;
  final bool isMembersOnly;
  final bool isGrammaticaQuiz;
  final bool isAssessment;
  final String? notebookId;
  final String? rejectionReason;
  final bool isArchived;
  final Timestamp? archivedAt;
  final Timestamp? purgeAt;
  final bool requiresLessonCompleted;
  final String? requiredLessonId;
  final String? requiredLessonTitle;

  /// Semantic alias for [notebookId] to identify the unified content bundle.
  String? get bundleId => notebookId;

  Quiz({
    required this.id,
    required this.title,
    required this.description,
    required this.questions,
    this.duration = 0,
    this.maxAttempts = 1,
    this.createdAt,
    this.createdByUid,
    this.createdByEmail,
    this.attachmentUrl,
    this.attachmentName,
    this.validationStatus = 'approved',
    this.isVisible = true,
    this.visibleTo = const [],
    this.isMembersOnly = false,
    this.isGrammaticaQuiz = false,
    this.isAssessment = false,
    this.notebookId,
    this.rejectionReason,
    this.isArchived = false,
    this.archivedAt,
    this.purgeAt,
    this.requiresLessonCompleted = false,
    this.requiredLessonId,
    this.requiredLessonTitle,
  });

  factory Quiz.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final questionsData = (d['questions'] as List?) ?? [];
    final flatQuestions = <QuizQuestion>[];
    for (final raw in questionsData) {
      final map = Map<String, dynamic>.from(raw as Map);
      if ((map['type'] ?? '').toString() == 'passage') {
        final nested = map['nestedQuestions'] as List?;
        if (nested != null) {
          for (final n in nested) {
            final nMap = Map<String, dynamic>.from(n as Map);
            if ((nMap['type'] ?? '').toString() != 'passage') {
              flatQuestions.add(QuizQuestion.fromMap(nMap));
            }
          }
        }
        continue;
      }
      flatQuestions.add(QuizQuestion.fromMap(map));
    }
    return Quiz(
      id: doc.id,
      title: (d['title'] ?? '').toString(),
      description: (d['description'] ?? '').toString(),
      questions: flatQuestions,
      duration: (d['duration'] as num?)?.toInt() ?? 0,
      maxAttempts: (d['maxAttempts'] as num?)?.toInt() ?? 1,
      createdAt: d['createdAt'] as Timestamp?,
      createdByUid: (d['createdByUid'] ?? '') == ''
          ? null
          : (d['createdByUid'] as String?),
      createdByEmail: (d['createdByEmail'] ?? '') == ''
          ? null
          : (d['createdByEmail'] as String?),
      attachmentUrl: (d['attachmentUrl'] ?? '').toString(),
      attachmentName: (d['attachmentName'] ?? '').toString(),
      validationStatus: (d['validationStatus'] ?? 'approved').toString(),
      isVisible: d['isVisible'] ?? true,
      visibleTo: List<String>.from(d['visibleTo'] ?? []),
      isMembersOnly: d['isMembersOnly'] ?? false,
      isGrammaticaQuiz: d['isGrammaticaQuiz'] ?? false,
      isAssessment: d['isAssessment'] ?? false,
      notebookId: (d['notebookId'] ?? '') == '' ? null : (d['notebookId'] as String?),
      rejectionReason: (d['rejectionReason'] as String?)?.isNotEmpty == true ? d['rejectionReason'] as String? : null,
      isArchived: (d['isArchived'] as bool?) ?? false,
      archivedAt: d['archivedAt'] as Timestamp?,
      purgeAt: d['purgeAt'] as Timestamp?,
      requiresLessonCompleted: (d['requiresLessonCompleted'] as bool?) ?? false,
      requiredLessonId: (d['requiredLessonId'] as String?)?.isNotEmpty == true ? d['requiredLessonId'] as String? : null,
      requiredLessonTitle: (d['requiredLessonTitle'] as String?)?.isNotEmpty == true ? d['requiredLessonTitle'] as String? : null,
    );
  }
}

class Review {
  final String id;
  final String reviewerUid;
  final String reviewerName;
  final double rating;
  final String comment;
  final Timestamp? createdAt;

  Review({
    required this.id,
    required this.reviewerUid,
    required this.reviewerName,
    required this.rating,
    required this.comment,
    this.createdAt,
  });

  factory Review.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Review(
      id: doc.id,
      reviewerUid: data['reviewerUid'] ?? '',
      reviewerName: data['reviewerName'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      comment: data['comment'] ?? '',
      createdAt: data['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reviewerUid': reviewerUid,
      'reviewerName': reviewerName,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}

class DatabaseService {
  DatabaseService._();
  static final instance = DatabaseService._();

  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  Future<Map<String, dynamic>?> getUserDoc(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return {...doc.data()!, 'uid': doc.id};
  }

  // Caching for streams to avoid rapid recreation issues on web
  final Map<String, Stream<Map<String, Map<String, dynamic>>>>
  _quizProgressCache = {};
  final Map<String, Stream<Map<String, Map<String, dynamic>>>>
  _lessonProgressCache = {};
  final Map<String, Stream<EducatorApplication?>> _userApplicationCache = {};

  Future<void> _deleteFileFromUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    
    // Safety check: Only attempt to delete if it's a Firebase Storage URL.
    // External URLs (like Google Photo URLs: lh3.googleusercontent.com) will crash refFromURL.
    if (!url.contains('firebasestorage.googleapis.com')) {
      debugPrint('Skipping deletion for non-Firebase Storage URL: $url');
      return;
    }

    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      debugPrint('Error deleting file from storage ($url): $e');
      // We don't rethrow here to allow Firestore deletion to proceed
    }
  }

  CollectionReference<Map<String, dynamic>> get _lessons =>
      _firestore.collection('lessons');
  CollectionReference<Map<String, dynamic>> get _quizzes =>
      _firestore.collection('quizzes');
  CollectionReference<Map<String, dynamic>> get _publishedContent =>
      _firestore.collection('published_content');
  CollectionReference<Map<String, dynamic>> get _playlists =>
      _firestore.collection('playlists');

  Future<String> createPlaylist({
    required String title,
    required String description,
    required String createdByUid,
    required String createdByEmail,
    required List<String> lessonIds,
  }) async {
    final doc = await _playlists.add({
      'title': title,
      'description': description,
      'createdByUid': createdByUid,
      'createdByEmail': createdByEmail,
      'lessonIds': lessonIds,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> updatePlaylist({
    required String id,
    String? title,
    String? description,
    List<String>? lessonIds,
  }) async {
    final data = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
    if (title != null) data['title'] = title;
    if (description != null) data['description'] = description;
    if (lessonIds != null) data['lessonIds'] = lessonIds;
    await _playlists.doc(id).update(data);
  }

  Future<void> deletePlaylist(String id) async {
    await _playlists.doc(id).delete();
  }

  Stream<List<LessonPlaylist>> streamPlaylistsByCreator(String uid, {String? email}) {
    return _playlists.snapshots().map((snap) {
      final list = snap.docs
          .map(LessonPlaylist.fromDoc)
          .where((p) {
            final matchesUid = p.createdByUid.isNotEmpty && p.createdByUid == uid;
            final matchesEmail = email != null &&
                email.isNotEmpty &&
                p.createdByEmail.toLowerCase() == email.toLowerCase();
            return matchesUid || matchesEmail;
          })
          .toList();
      list.sort((a, b) {
        final tA = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final tB = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return tB.compareTo(tA);
      });
      return list;
    });
  }

  Stream<List<LessonPlaylist>> streamAllPlaylists() {
    return _playlists
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(LessonPlaylist.fromDoc).toList());
  }

  Future<LessonPlaylist?> getPlaylist(String id) async {
    final doc = await _playlists.doc(id).get();
    if (!doc.exists) return null;
    return LessonPlaylist.fromDoc(doc);
  }

  Future<Lesson?> getLesson(String id) async {
    final doc = await _lessons.doc(id).get();
    if (!doc.exists) return null;
    return Lesson.fromDoc(doc);
  }
  CollectionReference<Map<String, dynamic>> _userProgress(String uid) =>
      _firestore.collection('users').doc(uid).collection('progress');
  CollectionReference<Map<String, dynamic>> _userQuizProgress(String uid) =>
      _firestore.collection('users').doc(uid).collection('quizProgress');
  DocumentReference<Map<String, dynamic>> _userStatsSummaryDoc(String uid) =>
      _firestore.collection('users').doc(uid).collection('stats').doc('summary');
  final Map<String, Stream<Map<String, dynamic>>> _userStatsSummaryCache = {};
  CollectionReference<Map<String, dynamic>> get _spellingWords =>
      _firestore.collection('spelling_words');

  CollectionReference<Map<String, dynamic>> get _educatorApplications =>
      _firestore.collection('educator_applications');

  Future<Map<String, dynamic>?> getUserData(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  Future<void> updateUserField(String uid, String field, dynamic value) async {
    await _firestore.collection('users').doc(uid).update({field: value});
  }

  Future<String?> uploadProfilePhotoWithBytes(User user, Uint8List bytes, String originalName) async {
    try {
      if (bytes.lengthInBytes > 5 * 1024 * 1024) {
        throw Exception('Image exceeds 5MB limit');
      }

      final ext = originalName.toLowerCase().split('.').last;
      final path = 'users/${user.uid}/profile_pic.$ext';
      final ref = _storage.ref().child(path);

      String contentType = 'image/jpeg';
      if (ext == 'png') {
        contentType = 'image/png';
      } else if (ext == 'webp') {
        contentType = 'image/webp';
      }

      final metadata = SettableMetadata(contentType: contentType);
      final snapshot = await ref.putData(bytes, metadata);
      final url = await snapshot.ref.getDownloadURL();

      await user.updatePhotoURL(url);
      await _firestore.collection('users').doc(user.uid).set(
        {'photoUrl': url},
        SetOptions(merge: true),
      );

      return url;
    } catch (e) {
      debugPrint('Error uploading profile photo bytes: $e');
      rethrow;
    }
  }

  Future<void> submitEducatorApplication({
    required String uid,
    required String email,
    required String cvUrl,
    required List<String> certificateUrls,
    required String videoUrl,
    required String syllabusUrl,
    required String applicationType,
    String? cvFileName,
    List<String>? certificateFileNames,
    String? videoFileName,
    String? syllabusFileName,
  }) async {
    // Delete any existing application files for this user to avoid storage bloat
    final existingApps = await _educatorApplications.where('applicantUid', isEqualTo: uid).get();
    for (final doc in existingApps.docs) {
      final app = EducatorApplication.fromDoc(doc);
      if (app.cvUrl != cvUrl) await _deleteFileFromUrl(app.cvUrl);
      for (final url in app.certificateUrls) {
        if (!certificateUrls.contains(url)) await _deleteFileFromUrl(url);
      }
      if (app.videoUrl != videoUrl) await _deleteFileFromUrl(app.videoUrl);
      if (app.syllabusUrl != syllabusUrl) await _deleteFileFromUrl(app.syllabusUrl);
      await _educatorApplications.doc(doc.id).delete();
    }

    await _educatorApplications.add({
      'applicantUid': uid,
      'applicantEmail': email,
      'cvUrl': cvUrl,
      'certificateUrls': certificateUrls,
      'videoUrl': videoUrl,
      'syllabusUrl': syllabusUrl,
      'status': 'pending',
      'applicationType': applicationType,
      'appliedAt': FieldValue.serverTimestamp(),
      'cvFileName': ?cvFileName,
      'certificateFileNames': ?certificateFileNames,
      'videoFileName': ?videoFileName,
      'syllabusFileName': ?syllabusFileName,
    });
  }

  Future<void> submitValidatorApplication({
    required String uid,
    required String email,
    required String prcUrl,
    required String prcFileName,
  }) async {
    final existingApps = await _educatorApplications.where('applicantUid', isEqualTo: uid).get();
    for (final doc in existingApps.docs) {
      final app = EducatorApplication.fromDoc(doc);
      for (final url in app.certificateUrls) {
        if (url != prcUrl) await _deleteFileFromUrl(url);
      }
      await _educatorApplications.doc(doc.id).delete();
    }

    await _educatorApplications.add({
      'applicantUid': uid,
      'applicantEmail': email,
      'cvUrl': '',
      'certificateUrls': [prcUrl],
      'prcUrl': prcUrl,
      'videoUrl': '',
      'syllabusUrl': '',
      'status': 'pending',
      'applicationType': 'validator',
      'appliedAt': FieldValue.serverTimestamp(),
      'certificateFileNames': [prcFileName],
      'prcFileName': prcFileName,
    });

    await _firestore.collection('users').doc(uid).set({
      'role': 'VALIDATOR',
      'status': 'Validator in Review',
      'isVerified': false,
      'prc_url': prcUrl,
      'prcUrl': prcUrl,
      'prc_file_name': prcFileName,
      'prcFileName': prcFileName,
    }, SetOptions(merge: true));
  }

  Future<void> deleteValidatorApplication(String uid) async {
    final existingApps = await _educatorApplications.where('applicantUid', isEqualTo: uid).get();
    for (final doc in existingApps.docs) {
      final app = EducatorApplication.fromDoc(doc);
      if (app.applicationType == 'validator') {
        for (final url in app.certificateUrls) {
          await _deleteFileFromUrl(url);
        }
        await _educatorApplications.doc(doc.id).delete();
      }
    }

    await _firestore.collection('users').doc(uid).set({
      'prc_url': FieldValue.delete(),
      'prcUrl': FieldValue.delete(),
      'prc_file_name': FieldValue.delete(),
      'prcFileName': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  Future<void> validateValidatorApplication({
    required String uid,
    String? reviewerEmail,
  }) async {
    // 1. Update user document
    await _firestore.collection('users').doc(uid).set({
      'role': 'VALIDATOR',
      'status': 'ACTIVE',
      'isVerified': true,
      'verifiedAt': FieldValue.serverTimestamp(),
      if (reviewerEmail != null && reviewerEmail.isNotEmpty)
        'verifiedBy': reviewerEmail,
    }, SetOptions(merge: true));

    // 2. Update educatorApplications
    final existingApps = await _educatorApplications.where('applicantUid', isEqualTo: uid).get();
    for (final doc in existingApps.docs) {
      final app = EducatorApplication.fromDoc(doc);
      if (app.applicationType == 'validator' || app.status == 'pending') {
        await _educatorApplications.doc(doc.id).update({
          'status': 'approved',
          'reviewedAt': FieldValue.serverTimestamp(),
          if (reviewerEmail != null && reviewerEmail.isNotEmpty)
            'reviewedBy': reviewerEmail,
        });
      }
    }

    // 3. Send in-app notification
    try {
      await NotificationService.instance.sendNotification(
        uid: uid,
        title: 'Validator Application Approved!',
        message: 'Congratulations! Your validator accreditation has been verified and approved by the Super Admin.',
        type: NotificationType.appApproved,
      );
    } catch (_) {}
  }

  Future<void> rejectValidatorApplication({
    required String uid,
    required String reason,
    required String description,
    String? reviewerEmail,
  }) async {
    // 1. Update user document
    await _firestore.collection('users').doc(uid).set({
      'status': 'REJECTED',
      'isVerified': false,
      'rejectedAt': FieldValue.serverTimestamp(),
      'rejectionReason': reason,
      'rejectionDescription': description,
      if (reviewerEmail != null && reviewerEmail.isNotEmpty)
        'reviewedBy': reviewerEmail,
    }, SetOptions(merge: true));

    // 2. Reject in educatorApplications
    final existingApps = await _educatorApplications.where('applicantUid', isEqualTo: uid).get();
    for (final doc in existingApps.docs) {
      final app = EducatorApplication.fromDoc(doc);
      if (app.applicationType == 'validator' || app.status == 'pending') {
        await rejectEducatorApplication(
          app,
          reason: reason,
          description: description,
        );
      }
    }

    // 3. Send notification
    try {
      await NotificationService.instance.sendRejectionNotification(
        uid: uid,
        reason: reason,
        description: description,
      );
    } catch (_) {}
  }

  Stream<List<EducatorApplication>> streamEducatorApplications({String? type}) {
    // Basic query on status first
    Query<Map<String, dynamic>> query = _educatorApplications;
    
    // We filter status in Dart if needed, or keep it minimal in query
    return query.snapshots().map((snapshot) {
      var apps = snapshot.docs.map(EducatorApplication.fromDoc).toList();
      
      // Filter for pending status
      apps = apps.where((a) => a.status == 'pending').toList();
      
      // Filter by type if provided
      if (type != null) {
        apps = apps.where((a) => a.applicationType == type).toList();
      }
      
      return apps;
    });
  }

  Stream<EducatorApplication?> streamUserApplication(String uid) {
    if (_userApplicationCache.containsKey(uid)) {
      return _userApplicationCache[uid]!;
    }
    final stream = _educatorApplications
        .where('applicantUid', isEqualTo: uid)
        .orderBy('appliedAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return EducatorApplication.fromDoc(snapshot.docs.first);
        })
        .asBroadcastStream();
    _userApplicationCache[uid] = stream;
    return stream;
  }

  Future<void> updateApplicationStatus(String id, String status) async {
    await _educatorApplications.doc(id).update({
      'status': status,
      'reviewedAt': FieldValue.serverTimestamp(),
      if (status == 'approved') 'approvedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<EducatorApplication>> streamApprovedEducatorApplications({String? type}) {
    return _educatorApplications.snapshots().map((snapshot) {
      var apps = snapshot.docs
          .map(EducatorApplication.fromDoc)
          .where((a) => a.status == 'approved')
          .toList();
      if (type != null) {
        apps = apps.where((a) => a.applicationType == type).toList();
      }
      apps.sort((a, b) {
        final tsA = a.reviewedAt ?? a.appliedAt;
        final tsB = b.reviewedAt ?? b.appliedAt;
        if (tsA == null && tsB == null) return 0;
        if (tsA == null) return 1;
        if (tsB == null) return -1;
        return tsB.compareTo(tsA);
      });
      return apps;
    });
  }

  Stream<List<Lesson>> streamApprovedLessons() {
    return _lessons.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map(Lesson.fromDoc)
          .where((l) => !l.isArchived && l.validationStatus == 'approved')
          .toList();
      list.sort((a, b) {
        final tsA = a.reviewedAt ?? a.createdAt;
        final tsB = b.reviewedAt ?? b.createdAt;
        if (tsA == null && tsB == null) return 0;
        if (tsA == null) return 1;
        if (tsB == null) return -1;
        return tsB.compareTo(tsA);
      });
      return list;
    });
  }

  Future<void> createMentorshipSession({
    required String educatorId,
    required String studentId,
    required String studentName,
    required DateTime startTime,
    required DateTime endTime,
    String meetingLink = '',
    String conferenceApp = 'meet',
    String meetingTitle = '',
    String? idempotencyKey,
  }) async {
    if (startTime.isBefore(DateTime.now())) {
      throw Exception('Cannot schedule a mentorship session in the past.');
    }

    // Prevent same time or overlapping sessions for this educator
    final existingSessions = await _firestore
        .collection('mentorship_sessions')
        .where('educatorId', isEqualTo: educatorId)
        .get();

    for (final doc in existingSessions.docs) {
      final data = doc.data();
      if (data['status'] == 'cancelled') continue;
      final existStart = (data['startTime'] as Timestamp?)?.toDate();
      final existEnd = (data['endTime'] as Timestamp?)?.toDate() ??
          existStart?.add(const Duration(minutes: 90));

      if (existStart != null && existEnd != null) {
        final bool isSameTime = startTime.isAtSameMomentAs(existStart);
        final bool isOverlap = startTime.isBefore(existEnd) && endTime.isAfter(existStart);
        if (isSameTime || isOverlap) {
          final conflictTitle = data['meetingTitle']?.toString().isNotEmpty == true
              ? data['meetingTitle']
              : (data['studentName'] ?? 'Existing session');
          final conflictFmt = DateFormat('EEE, MMM d @ h:mm a').format(existStart);
          final conflictEndFmt = DateFormat('h:mm a').format(existEnd);
          throw Exception(
              'You cannot schedule mentorship at the same or overlapping time ($conflictFmt - $conflictEndFmt). Session "$conflictTitle" is already scheduled.');
        }
      }
    }

    // Prevent same time or overlapping sessions for this student
    final studentSessions = await _firestore
        .collection('mentorship_sessions')
        .where('studentId', isEqualTo: studentId)
        .get();

    for (final doc in studentSessions.docs) {
      final data = doc.data();
      if (data['status'] == 'cancelled') continue;
      final existStart = (data['startTime'] as Timestamp?)?.toDate();
      final existEnd = (data['endTime'] as Timestamp?)?.toDate() ??
          existStart?.add(const Duration(minutes: 90));

      if (existStart != null && existEnd != null) {
        final bool isSameTime = startTime.isAtSameMomentAs(existStart);
        final bool isOverlap = startTime.isBefore(existEnd) && endTime.isAfter(existStart);
        if (isSameTime || isOverlap) {
          final conflictFmt = DateFormat('EEE, MMM d @ h:mm a').format(existStart);
          throw Exception(
              'Cannot schedule mentorship: The student already has a session at $conflictFmt.');
        }
      }
    }

    // Prevent same time or overlapping availability slots for this educator
    final existingSlots = await _firestore
        .collection('mentorship_availability')
        .where('educatorId', isEqualTo: educatorId)
        .get();

    for (final doc in existingSlots.docs) {
      final data = doc.data();
      final existStart = (data['startTime'] as Timestamp?)?.toDate();
      final existEnd = (data['endTime'] as Timestamp?)?.toDate() ??
          existStart?.add(const Duration(minutes: 90));

      if (existStart != null && existEnd != null) {
        final bool isSameTime = startTime.isAtSameMomentAs(existStart);
        final bool isOverlap = startTime.isBefore(existEnd) && endTime.isAfter(existStart);
        if (isSameTime || isOverlap) {
          final conflictFmt = DateFormat('EEE, MMM d @ h:mm a').format(existStart);
          throw Exception(
              'Cannot schedule mentorship: You already have an availability slot at $conflictFmt.');
        }
      }
    }

    final effectiveKey = idempotencyKey ??
        IdempotencyService.instance.generateMentorshipKey(
          educatorUid: educatorId,
          studentUid: studentId,
          startTime: startTime,
        );

    final sessionId = effectiveKey.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

    await IdempotencyService.instance.executeDeduplicated<void>(
      key: 'mentorship_$sessionId',
      action: () async {
        final docRef =
            _firestore.collection('mentorship_sessions').doc(sessionId);

        // Check if session already exists
        final existing = await docRef.get();
        if (existing.exists) {
          debugPrint(
              '[MentorshipIdempotency] Session $sessionId already exists. Skipping duplicate creation.');
          return;
        }

        // Set the Agora channel name to a deterministic, safe string based on doc ID
        final channelName = sessionId.length > 32
            ? sessionId.substring(0, 32)
            : sessionId;

        await docRef.set({
          'educatorId': educatorId,
          'studentId': studentId,
          'studentName': studentName,
          'startTime': Timestamp.fromDate(startTime),
          'endTime': Timestamp.fromDate(endTime),
          'meetingLink': meetingLink,
          'conferenceApp': conferenceApp,
          'meetingTitle': meetingTitle,
          'status': 'scheduled',
          'agoraChannel': channelName,
          'idempotencyKey': effectiveKey,
          'createdAt': FieldValue.serverTimestamp(),
        });

    try {
      final educatorDoc = await getUserDoc(educatorId);
      final studentDoc = await getUserDoc(studentId);
      final educatorName = educatorDoc?['username'] ?? 'Your Educator';
      final sName = studentDoc?['username'] ?? studentName;
      final studentEmail = studentDoc?['email'] as String?;
      final dateStr = DateFormat('EEE, MMM d, yyyy @ h:mm a').format(startTime);
      final titleStr = meetingTitle.isNotEmpty ? meetingTitle : 'Mentorship Session';

      // 1. Send In-App Notification (Bell Icon)
      await NotificationService.instance.sendNotification(
        uid: studentId,
        title: 'Mentorship Session Scheduled!',
        message: '$educatorName scheduled "$titleStr" for $dateStr.',
        type: NotificationType.mentorship,
        educatorId: educatorId,
      );

      // 2. Send Email Notification
      if (studentEmail != null && studentEmail.isNotEmpty) {
        await EmailSenderService.sendMentorshipNotificationEmail(
          recipientEmail: studentEmail,
          recipientName: sName,
          educatorName: educatorName,
          meetingTitle: titleStr,
          timeStr: dateStr,
          conferenceApp: 'agora',
          meetingLink: '',
        );
      }
    } catch (e) {
      debugPrint('Error sending mentorship notification/email: $e');
    }
      },
    );
  }

  Future<void> cancelMentorshipSession(String sessionId) async {
    await _firestore.collection('mentorship_sessions').doc(sessionId).delete();
  }

  Future<void> deleteMentorshipSession(String sessionId) async {
    await _firestore.collection('mentorship_sessions').doc(sessionId).delete();
  }

  Future<void> completeMentorshipSession(String sessionId) async {
    await _firestore.collection('mentorship_sessions').doc(sessionId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateMentorshipSession({
    required String sessionId,
    required String studentId,
    required String studentName,
    required DateTime startTime,
    required DateTime endTime,
    String meetingLink = '',
    String conferenceApp = 'meet',
    String meetingTitle = '',
  }) async {
    final docSnap = await _firestore.collection('mentorship_sessions').doc(sessionId).get();
    if (docSnap.exists) {
      final data = docSnap.data()!;
      final sTime = (data['startTime'] as Timestamp?)?.toDate();
      final eTime = (data['endTime'] as Timestamp?)?.toDate();
      final now = DateTime.now();
      if (sTime != null && eTime != null) {
        if (now.isAfter(sTime) && now.isBefore(eTime)) {
          throw 'Cannot edit mentorship session while it is ongoing.';
        }
        if (now.isAfter(eTime)) {
          throw 'Cannot edit a past mentorship session.';
        }
      }
    }

    // Only update meetingTitle (date and time cannot be modified once saved in calendar)
    await _firestore.collection('mentorship_sessions').doc(sessionId).update({
      'meetingTitle': meetingTitle,
      'meetingLink': meetingLink,
      'conferenceApp': conferenceApp,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> streamEducatorMentorshipSessions(String educatorId) {
    return _firestore.collection('mentorship_sessions')
        .where('educatorId', isEqualTo: educatorId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {
          ...doc.data(),
          'id': doc.id,
        }).toList());
  }

  Stream<List<Map<String, dynamic>>> streamStudentMentorshipSessions(String studentId) {
    return _firestore.collection('mentorship_sessions')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {
          ...doc.data(),
          'id': doc.id,
        }).toList());
  }

  /// Create educator availability slot.
  /// Mentorship session duration is STRICTLY 1 hour and 30 minutes (90 minutes).
  Future<void> createMentorshipAvailabilitySlot({
    required String educatorId,
    required String educatorName,
    required DateTime startTime,
    String title = '1-on-1 Mentorship',
  }) async {
    // 1. Prevent setting availability in the past
    if (startTime.isBefore(DateTime.now())) {
      throw Exception('Cannot schedule an availability slot in the past. Please select a future time.');
    }

    final endTime = startTime.add(const Duration(minutes: 90));

    // 2. Prevent overlapping mentorship availability slots for this educator
    final existingSlots = await _firestore
        .collection('mentorship_availability')
        .where('educatorId', isEqualTo: educatorId)
        .get();

    for (final doc in existingSlots.docs) {
      final data = doc.data();
      final existStart = (data['startTime'] as Timestamp?)?.toDate();
      final existEnd = (data['endTime'] as Timestamp?)?.toDate() ??
          existStart?.add(const Duration(minutes: 90));

      if (existStart != null && existEnd != null) {
        final bool isSameTime = startTime.isAtSameMomentAs(existStart);
        final bool isOverlap = startTime.isBefore(existEnd) && endTime.isAfter(existStart);
        if (isSameTime || isOverlap) {
          final conflictFmt = DateFormat('EEE, MMM d @ h:mm a').format(existStart);
          throw Exception(
              'Mentorship slots cannot have the same time or overlap. You already have a slot at $conflictFmt.');
        }
      }
    }

    // 3. Prevent overlapping active sessions for this educator
    final existingSessions = await _firestore
        .collection('mentorship_sessions')
        .where('educatorId', isEqualTo: educatorId)
        .get();

    for (final doc in existingSessions.docs) {
      final data = doc.data();
      if (data['status'] == 'cancelled') continue;
      final existStart = (data['startTime'] as Timestamp?)?.toDate();
      final existEnd = (data['endTime'] as Timestamp?)?.toDate() ??
          existStart?.add(const Duration(minutes: 90));

      if (existStart != null && existEnd != null) {
        final bool isSameTime = startTime.isAtSameMomentAs(existStart);
        final bool isOverlap = startTime.isBefore(existEnd) && endTime.isAfter(existStart);
        if (isSameTime || isOverlap) {
          final conflictFmt = DateFormat('EEE, MMM d @ h:mm a').format(existStart);
          throw Exception(
              'Mentorship slots cannot have the same time or overlap. You already have a booked session at $conflictFmt.');
        }
      }
    }

    final slotId = '${educatorId}_${startTime.millisecondsSinceEpoch}';

    await _firestore.collection('mentorship_availability').doc(slotId).set({
      'educatorId': educatorId,
      'educatorName': educatorName,
      'title': title.trim().isEmpty ? '1-on-1 Mentorship' : title.trim(),
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'durationMinutes': 90,
      'isBooked': false,
      'bookedByUid': null,
      'bookedByName': null,
      'bookedByEmail': null,
      'bookedAt': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete an unbooked availability slot.
  Future<void> deleteMentorshipAvailabilitySlot(String slotId) async {
    await _firestore.collection('mentorship_availability').doc(slotId).delete();
  }

  /// Real-time stream of availability slots for an educator.
  Stream<List<Map<String, dynamic>>> streamEducatorAvailability(String educatorId) {
    return _firestore
        .collection('mentorship_availability')
        .where('educatorId', isEqualTo: educatorId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {
              ...doc.data(),
              'id': doc.id,
            }).toList());
  }

  /// Atomically reserve an availability slot to prevent double booking.
  /// Limits duration to strictly 1 hour 30 minutes and automatically writes to mentorship_sessions.
  Future<void> reserveMentorshipSlot({
    required String slotId,
    required User learner,
    required String educatorId,
    required String educatorName,
    String? meetingTitle,
  }) async {
    final slotRef = _firestore.collection('mentorship_availability').doc(slotId);

    // Pre-check learner overlapping sessions before starting reservation
    final learnerSessions = await _firestore
        .collection('mentorship_sessions')
        .where('studentId', isEqualTo: learner.uid)
        .get();

    final slotSnapshot = await slotRef.get();
    if (!slotSnapshot.exists) {
      throw Exception('This availability slot no longer exists.');
    }
    final slotData = slotSnapshot.data()!;
    final slotStart = (slotData['startTime'] as Timestamp).toDate();
    final slotEnd = (slotData['endTime'] as Timestamp?)?.toDate() ??
        slotStart.add(const Duration(minutes: 90));

    for (final doc in learnerSessions.docs) {
      final data = doc.data();
      if (data['status'] == 'cancelled') continue;
      final existStart = (data['startTime'] as Timestamp?)?.toDate();
      final existEnd = (data['endTime'] as Timestamp?)?.toDate() ??
          existStart?.add(const Duration(minutes: 90));

      if (existStart != null && existEnd != null) {
        final bool isSameTime = slotStart.isAtSameMomentAs(existStart);
        final bool isOverlap = slotStart.isBefore(existEnd) && slotEnd.isAfter(existStart);
        if (isSameTime || isOverlap) {
          final conflictFmt = DateFormat('EEE, MMM d @ h:mm a').format(existStart);
          throw Exception(
              'Mentorship sessions cannot have the same time or overlap. You already have another session scheduled at $conflictFmt.');
        }
      }
    }

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(slotRef);
      if (!snapshot.exists) {
        throw Exception('This availability slot no longer exists.');
      }

      final data = snapshot.data()!;
      final bool isBooked = data['isBooked'] == true;
      if (isBooked) {
        throw Exception('This slot has already been booked by another learner.');
      }

      final startTime = (data['startTime'] as Timestamp).toDate();
      // Strict 90-minute limit
      final endTime = (data['endTime'] as Timestamp?)?.toDate() ??
          startTime.add(const Duration(minutes: 90));

      final learnerName = learner.displayName ??
          (learner.email?.split('@').first ?? 'Learner');
      final channelName = 'mentor_${educatorId.length > 8 ? educatorId.substring(0, 8) : educatorId}_${startTime.millisecondsSinceEpoch}';
      final sessionId = 'session_$slotId';
      final sessionRef = _firestore.collection('mentorship_sessions').doc(sessionId);

      transaction.update(slotRef, {
        'isBooked': true,
        'bookedByUid': learner.uid,
        'bookedByName': learnerName,
        'bookedByEmail': learner.email,
        'bookedAt': FieldValue.serverTimestamp(),
        'agoraChannel': channelName,
        'sessionId': sessionId,
      });

      transaction.set(sessionRef, {
        'educatorId': educatorId,
        'educatorName': educatorName,
        'studentId': learner.uid,
        'studentName': learnerName,
        'studentEmail': learner.email,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'durationMinutes': 90,
        'meetingTitle': (meetingTitle != null && meetingTitle.isNotEmpty)
            ? meetingTitle
            : (data['title'] ?? '1-on-1 Mentorship Session'),
        'status': 'scheduled',
        'agoraChannel': channelName,
        'conferenceApp': 'agora',
        'slotId': slotId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    try {
      final titleStr = meetingTitle != null && meetingTitle.isNotEmpty
          ? meetingTitle
          : '1-on-1 Mentorship Session';

      await NotificationService.instance.sendNotification(
        uid: educatorId,
        title: 'New Mentorship Booking!',
        message: '${learner.displayName ?? learner.email ?? "A subscriber"} reserved your slot for "$titleStr".',
        type: NotificationType.mentorship,
        educatorId: educatorId,
      );

      await NotificationService.instance.sendNotification(
        uid: learner.uid,
        title: 'Mentorship Confirmed!',
        message: 'You reserved a 90-min mentorship session with $educatorName.',
        type: NotificationType.mentorship,
        educatorId: educatorId,
      );
    } catch (e) {
      debugPrint('Notification sending error after slot reservation: $e');
    }
  }



  Future<void> rejectEducatorApplication(
    EducatorApplication app, {
    String? reason,
    String? description,
  }) async {
    // Delete files from storage
    if (app.cvUrl.isNotEmpty) {
      await _deleteFileFromUrl(app.cvUrl);
    }
    for (String url in app.certificateUrls) {
      if (url.isNotEmpty) {
        await _deleteFileFromUrl(url);
      }
    }
    if (app.videoUrl.isNotEmpty) {
      await _deleteFileFromUrl(app.videoUrl);
    }
    if (app.syllabusUrl.isNotEmpty) {
      await _deleteFileFromUrl(app.syllabusUrl);
    }
    // Update status and clear URLs in Firestore
    await _educatorApplications.doc(app.id).update({
      'status': 'rejected',
      'cvUrl': '',
      'certificateUrls': [],
      'videoUrl': '', // Clear URLs to indicate files are gone
      'syllabusUrl': '',
      'rejectionReason': reason,
      'rejectionDescription': description,
      'rejectedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> uploadApplicationFile({
    required String uid,
    required Uint8List fileBytes,
    required String fileName,
    required String contentType,
  }) async {
    try {
      final finalBytes = contentType.startsWith('image/')
          ? await compressImageBytes(fileBytes)
          : fileBytes;

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('educator_applications')
          .child(uid)
          .child('${DateTime.now().millisecondsSinceEpoch}_$fileName');

      final uploadTask = storageRef.putData(
        finalBytes,
        SettableMetadata(contentType: contentType),
      );

      final snapshot = await uploadTask.whenComplete(() => null);
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload application file: $e');
    }
  }

  Future<String> createLesson({
    required String title,
    required String prompt,
    required String answer,
    String? attachmentUrl,
    String? attachmentName,
    bool isVisible = true,
    List<String> visibleTo = const [],
    bool isMembersOnly = false,
    bool isGrammaticaLesson = false,
    String? quizId,
    String? imageUrl,
    String? notebookId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    UserRole userRole = UserRole.learner;
    if (user != null) {
      userRole = await RoleService.instance.getRole(user.uid);
    }
    final isAdmin = userRole == UserRole.admin || userRole == UserRole.superadmin;

    // Admin content is permanently Grammatica Official (educators are not)
    final effectiveIsGrammatica = isAdmin;

    // ALL newly uploaded content must go through validation process
    const String status = 'awaiting_approval';

    final doc = await _lessons.add({
      'title': title,
      'prompt': prompt,
      'answer': answer,
      'createdAt': FieldValue.serverTimestamp(),
      'createdByUid': user?.uid,
      'createdByEmail': user?.email,
      'validationStatus': status,
      'attachmentUrl': attachmentUrl,
      'attachmentName': attachmentName,
      'isVisible': isVisible,
      'visibleTo': visibleTo,
      'isMembersOnly': isMembersOnly,
      'isGrammaticaLesson': effectiveIsGrammatica,
      'quizId': quizId,
      'imageUrl': imageUrl,
      'notebookId': notebookId,
    });

    // Notify validators in real-time when new lesson is submitted for validation
    final authorName = user?.displayName ?? user?.email ?? 'An educator';
    NotificationService.instance.notifyValidatorsOfNewLesson(
      authorName: authorName,
      lessonTitle: title,
    ).catchError((e) => debugPrint('Error notifying validators of new lesson: $e'));

    // Notify subscribers in real-time ONLY when an already-approved members-only lesson is created.
    // Pending lessons notify subscribers after validator approval.
    if (user != null && isMembersOnly && status == 'approved') {
      NotificationService.instance.notifySubscribersOfLesson(
        educatorUid: user.uid,
        lessonTitle: title,
        lessonId: doc.id,
      ).catchError((e) => debugPrint('Error notifying subscribers of lesson: $e'));
    }

    return doc.id;
  }

  Set<String> _extractImageUrlsFromPrompt(String prompt) {
    final urls = <String>{};
    final imgRegex = RegExp(r'!\[[\s\S]*?\]\((https?://[^\s)]+|\S+?)\)');
    for (final match in imgRegex.allMatches(prompt)) {
      var url = match.group(2) ?? '';
      if (url.endsWith(')')) url = url.substring(0, url.length - 1);
      if (url.contains('firebasestorage.googleapis.com')) {
        urls.add(url);
      }
    }
    return urls;
  }

  Future<void> updateLesson({
    required String id,
    String? title,
    String? prompt,
    String? answer,
    String? attachmentUrl,
    String? attachmentName,
    bool? isVisible,
    List<String>? visibleTo,
    bool? isMembersOnly,
    bool? isGrammaticaLesson,
    String? quizId,
    String? imageUrl,
    String? validationStatus,
    String? notebookId,
    bool? isUpdate,
  }) async {
    final existingDoc = await _lessons.doc(id).get();
    if (prompt != null && existingDoc.exists) {
      final oldPrompt = (existingDoc.data()?['prompt'] ?? '').toString();
      final oldUrls = _extractImageUrlsFromPrompt(oldPrompt);
      final newUrls = _extractImageUrlsFromPrompt(prompt);
      final removedUrls = oldUrls.difference(newUrls);
      for (final url in removedUrls) {
        await _deleteFileFromUrl(url);
      }
    }

    final user = FirebaseAuth.instance.currentUser;
    UserRole userRole = UserRole.learner;
    if (user != null) {
      userRole = await RoleService.instance.getRole(user.uid);
    }
    final isAdmin = userRole == UserRole.admin || userRole == UserRole.superadmin;
    final prevStatus = existingDoc.data()?['validationStatus']?.toString();
    final bool wasApproved = prevStatus == 'approved';

    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (prompt != null) data['prompt'] = prompt;
    if (answer != null) data['answer'] = answer;
    if (attachmentUrl != null) data['attachmentUrl'] = attachmentUrl;
    if (attachmentName != null) data['attachmentName'] = attachmentName;
    if (isVisible != null) data['isVisible'] = isVisible;
    if (visibleTo != null) data['visibleTo'] = visibleTo;
    if (isMembersOnly != null) data['isMembersOnly'] = isMembersOnly;
    if (isAdmin) {
      data['isGrammaticaLesson'] = true;
    } else if (isGrammaticaLesson != null) {
      data['isGrammaticaLesson'] = isGrammaticaLesson;
    }

    // Validation routing:
    // If not admin and updating an existing approved lesson (or isUpdate explicitly set):
    // The update MUST run through the validator!
    if (!isAdmin && (wasApproved || isUpdate == true)) {
      data['validationStatus'] = 'awaiting_approval';
      data['isUpdate'] = true;
      data['reviewedAt'] = null;
      data['rejectionReason'] = null;
      data['rejectionDescription'] = null;
    } else if (validationStatus != null) {
      data['validationStatus'] = validationStatus;
      if (isUpdate != null) data['isUpdate'] = isUpdate;
    } else if (isUpdate != null) {
      data['isUpdate'] = isUpdate;
    }

    data['quizId'] = quizId;
    if (imageUrl != null) data['imageUrl'] = imageUrl;
    if (quizId != null) {
      data['quizId'] = quizId;
    }
    if (notebookId != null) {
      data['notebookId'] = notebookId;
    }
    if (data.isNotEmpty) {
      await _lessons.doc(id).update(data);
    }

    if (data['isUpdate'] == true || (data['validationStatus'] == 'awaiting_approval' && wasApproved)) {
      final authorName = user?.displayName ?? user?.email ?? 'An educator';
      NotificationService.instance.notifyValidatorsOfNewLesson(
        authorName: authorName,
        lessonTitle: (title ?? existingDoc.data()?['title'] ?? 'Lesson').toString(),
        isUpdate: true,
      ).catchError((e) => debugPrint('Error notifying validators of lesson update: $e'));
    }
  }

  Future<void> deleteLesson(String id) async {
    final doc = await _lessons.doc(id).get();
    if (doc.exists) {
      final data = doc.data();
      // Delete attachment from storage
      await _deleteFileFromUrl(data?['attachmentUrl']);

      // Delete images embedded in prompt and answer from storage
      final prompt = (data?['prompt'] ?? '').toString();
      final answer = (data?['answer'] ?? '').toString();
      final embeddedUrls = {
        ..._extractImageUrlsFromPrompt(prompt),
        ..._extractImageUrlsFromPrompt(answer),
      };
      for (final url in embeddedUrls) {
        await _deleteFileFromUrl(url);
      }

      // Delete linked quiz if exists
      final quizId = (data?['quizId'] ?? '').toString();
      if (quizId.isNotEmpty) {
        await deleteQuiz(quizId);
      }

      // Clean up any user progress docs referencing this lesson
      try {
        final usersSnap = await _firestore.collection('users').get();
        for (final userDoc in usersSnap.docs) {
          await _userProgress(userDoc.id).doc(id).delete();
        }
      } catch (e) {
        debugPrint('Error cleaning up lesson progress: $e');
      }
    }
    await _lessons.doc(id).delete();
  }

  /// Archives a lesson for 30 days before permanent deletion.
  ///
  /// A lesson is the single centralized unit of content: its quiz and all
  /// companion materials (mind maps, presentations, flashcards, study guides)
  /// are archived together with it and can never be archived on their own.
  Future<void> archiveLesson(String id) async {
    final now = DateTime.now();
    final purgeDate = now.add(const Duration(days: 30));
    final archiveFields = <String, dynamic>{
      'isArchived': true,
      'archivedAt': Timestamp.fromDate(now),
      'purgeAt': Timestamp.fromDate(purgeDate),
    };
    await _lessons.doc(id).update(archiveFields);
    await _applyToLessonPackage(id, archiveFields);
  }

  /// Restores an archived lesson (and all of its linked content) to active status.
  Future<void> restoreLesson(String id) async {
    const restoreFields = <String, dynamic>{
      'isArchived': false,
      'archivedAt': null,
      'purgeAt': null,
    };
    await _lessons.doc(id).update(restoreFields);
    await _applyToLessonPackage(id, restoreFields);
  }

  /// Applies [fields] to every quiz and published item linked to a lesson,
  /// whether linked via the lesson's `quizId`, its `notebookId`, or `lessonId`.
  Future<void> _applyToLessonPackage(
    String lessonId,
    Map<String, dynamic> fields,
  ) async {
    final lessonDoc = await _lessons.doc(lessonId).get();
    final data = lessonDoc.data() ?? {};
    final quizId = (data['quizId'] ?? '').toString();
    final notebookId = (data['notebookId'] ?? '').toString();
    final nbId = notebookId.isNotEmpty ? notebookId : lessonId;

    final refs = <String, DocumentReference<Map<String, dynamic>>>{};
    if (quizId.isNotEmpty) refs[_quizzes.doc(quizId).path] = _quizzes.doc(quizId);

    Future<void> collect(Query<Map<String, dynamic>> query) async {
      try {
        final snap = await query.get();
        for (final doc in snap.docs) {
          refs[doc.reference.path] = doc.reference;
        }
      } catch (e) {
        debugPrint('Error collecting linked lesson content: $e');
      }
    }

    await Future.wait([
      collect(_quizzes.where('notebookId', isEqualTo: nbId)),
      collect(_quizzes.where('lessonId', isEqualTo: lessonId)),
      collect(_publishedContent.where('notebookId', isEqualTo: nbId)),
      collect(_publishedContent.where('lessonId', isEqualTo: lessonId)),
    ]);

    for (final ref in refs.values) {
      try {
        await ref.update(fields);
      } catch (e) {
        debugPrint('Error updating linked content ${ref.path}: $e');
      }
    }
  }

  /// Stream archived lessons for viewing in the Archive modal/view.
  Stream<List<Lesson>> streamArchivedLessons({String? uid}) {
    return _lessons
        .where('isArchived', isEqualTo: true)
        .snapshots()
        .map((snap) {
      var list = snap.docs.map(Lesson.fromDoc).toList();
      if (uid != null) {
        list = list.where((l) => l.createdByUid == uid).toList();
      }
      return list;
    });
  }

  /// Permanently purges lessons whose 30-day archive period has elapsed,
  /// together with their entire linked content package.
  Future<void> purgeExpiredArchive() async {
    final now = Timestamp.now();
    try {
      final expiredLessons = await _lessons.where('isArchived', isEqualTo: true).where('purgeAt', isLessThanOrEqualTo: now).get();
      for (final doc in expiredLessons.docs) {
        await permanentlyDeleteLessonPackage(lesson: Lesson.fromDoc(doc));
      }

      // Legacy cleanup: quizzes used to be archivable on their own. A quiz
      // whose parent lesson is still active is restored instead of purged;
      // only orphaned quizzes (no surviving lesson) are deleted.
      final expiredQuizzes = await _quizzes.where('isArchived', isEqualTo: true).where('purgeAt', isLessThanOrEqualTo: now).get();
      for (final doc in expiredQuizzes.docs) {
        final parent = await _findParentLesson(doc.id, doc.data());
        if (parent != null && parent.data()?['isArchived'] != true) {
          await doc.reference.update({'isArchived': false, 'archivedAt': null, 'purgeAt': null});
        } else if (parent == null) {
          await deleteQuiz(doc.id);
        }
      }
    } catch (e) {
      debugPrint('Error purging expired archive: $e');
    }
  }

  /// Finds the lesson that owns a quiz (via `quizId`, `lessonId`, or `notebookId`).
  Future<DocumentSnapshot<Map<String, dynamic>>?> _findParentLesson(
    String quizId,
    Map<String, dynamic> quizData,
  ) async {
    final byQuizId = await _lessons.where('quizId', isEqualTo: quizId).limit(1).get();
    if (byQuizId.docs.isNotEmpty) return byQuizId.docs.first;

    final lessonId = (quizData['lessonId'] ?? '').toString();
    if (lessonId.isNotEmpty) {
      final doc = await _lessons.doc(lessonId).get();
      if (doc.exists) return doc;
    }

    final notebookId = (quizData['notebookId'] ?? '').toString();
    if (notebookId.isNotEmpty) {
      final byNotebook = await _lessons.where('notebookId', isEqualTo: notebookId).limit(1).get();
      if (byNotebook.docs.isNotEmpty) return byNotebook.docs.first;
      final byId = await _lessons.doc(notebookId).get();
      if (byId.exists) return byId;
    }
    return null;
  }

  /// Permanently purges a lesson and all of its associated content from the site database,
  /// including the primary quiz, companion quizzes, and companion published items (flashcards, mind maps, etc.).
  Future<void> permanentlyDeleteLessonPackage({
    required Lesson lesson,
  }) async {
    // 1. Purge the main lesson
    await deleteLesson(lesson.id);

    // 2. Cascade purge primary linked quiz if not already deleted
    if (lesson.quizId != null && lesson.quizId!.isNotEmpty) {
      try {
        await deleteQuiz(lesson.quizId!);
      } catch (e) {
        debugPrint('Error deleting linked quiz: $e');
      }
    }

    // 3. Purge any companion quizzes and published items linked via notebookId or lesson.id
    final nbId = lesson.notebookId ?? lesson.id;
    if (nbId.isNotEmpty) {
      try {
        final quizzesSnap = await _quizzes.where('notebookId', isEqualTo: nbId).get();
        for (final doc in quizzesSnap.docs) {
          await deleteQuiz(doc.id);
        }
      } catch (e) {
        debugPrint('Error deleting companion quizzes: $e');
      }

      try {
        final publishedSnap = await _publishedContent.where('notebookId', isEqualTo: nbId).get();
        for (final doc in publishedSnap.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        debugPrint('Error deleting companion published items: $e');
      }

      if (lesson.id.isNotEmpty) {
        try {
          final pubByLessonSnap = await _publishedContent.where('lessonId', isEqualTo: lesson.id).get();
          for (final doc in pubByLessonSnap.docs) {
            await doc.reference.delete();
          }
        } catch (e) {
          debugPrint('Error deleting companion published items by lessonId: $e');
        }
      }
    }
  }

  /// Streams the entire collection of all lessons across the platform for the Admin Lesson Database.
  /// Does not enforce creator or status filters, ensuring all platform lessons are displayed.
  Stream<List<Lesson>> streamAllLessonsDatabase() {
    return _lessons.snapshots().map((snapshot) {
      final list = snapshot.docs.map(Lesson.fromDoc).where((l) => !l.isArchived).toList();
      list.sort((a, b) {
        final tsA = a.createdAt;
        final tsB = b.createdAt;
        if (tsA == null && tsB == null) return 0;
        if (tsA == null) return 1;
        if (tsB == null) return -1;
        return tsB.compareTo(tsA);
      });
      return list;
    });
  }

  Future<Lesson?> getLessonById(String id) async {
    final doc = await _lessons.doc(id).get();
    if (!doc.exists) return null;
    return Lesson.fromDoc(doc);
  }

  Future<List<Lesson>> fetchLessons() async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    final role = uid != null
        ? await RoleService.instance.getRole(uid)
        : UserRole.learner;
    final snapshot = await _lessons
        .orderBy('createdAt', descending: false)
        .get();
    return snapshot.docs
        .map(Lesson.fromDoc)
        .where(
          (l) =>
              !l.isArchived &&
              (l.validationStatus == 'approved' ||
                  (uid != null && l.createdByUid == uid) ||
                  role == UserRole.validator),
        )
        .toList();
  }

  Stream<List<Lesson>> streamLessons({
    bool approvedOnly = true,
    UserRole? userRole,
    String? userId,
  }) {
    // We order by createdAt. To avoid composite index requirements and support
    // legacy content (without validationStatus), we filter in Dart.
    return _lessons.orderBy('createdAt', descending: false).snapshots().map((
      snapshot,
    ) {
      final lessons = snapshot.docs
          .map(Lesson.fromDoc)
          .where((l) => !l.isArchived)
          .toList();

      return lessons.where((l) {
        final isAuthor = userId != null && l.createdByUid == userId;
        final isValidator = userRole == UserRole.validator;

        // Pending / unapproved lessons are strictly visible ONLY to the author and validators.
        if (l.validationStatus != 'approved') {
          return isAuthor || isValidator;
        }

        // Approved lessons:
        if (isAuthor) return true;
        if (!approvedOnly &&
            (isValidator ||
                userRole == UserRole.admin ||
                userRole == UserRole.superadmin)) {
          return true;
        }
        return l.isVisible || (userId != null && l.visibleTo.contains(userId));
      }).toList();
    });
  }

  Future<bool> isSubscribed(String educatorUid, String userId) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('subscriptions')
        .doc(educatorUid)
        .get();
    if (!doc.exists) return false;
    final data = doc.data();
    if (data?['status'] != 'active') return false;
    final tier = (data?['tier'] ?? '').toString().toLowerCase();
    return tier == 'premium' || tier == 'standard';
  }

  Stream<List<Lesson>> streamAwaitingApprovalLessons() {
    return _lessons
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(Lesson.fromDoc)
              .where((l) => l.validationStatus == 'awaiting_approval' && !l.isArchived)
              .toList(),
        );
  }

  Stream<Map<String, Map<String, dynamic>>> progressStream(User user) {
    if (_lessonProgressCache.containsKey(user.uid)) {
      return _lessonProgressCache[user.uid]!;
    }
    final stream = _userProgress(user.uid).snapshots().map((q) {
      final map = <String, Map<String, dynamic>>{};
      for (final d in q.docs) {
        final data = d.data();
        map[d.id] = {
          'completed': data['completed'] == true,
          'completedAt': data['completedAt'],
          'lastReadAt': data['lastReadAt'] ?? data['completedAt'],
          'progress': (data['progress'] as num?)?.toDouble() ?? 0.0,
        };
      }
      return map;
    }).asBroadcastStream();
    _lessonProgressCache[user.uid] = stream;
    return stream;
  }

  static String? lastViewedLessonId;

  Future<void> recordLessonViewed({
    required User user,
    required String lessonId,
  }) async {
    lastViewedLessonId = lessonId;
    try {
      await _userProgress(user.uid).doc(lessonId).set({
        'lastReadAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _firestore.collection('users').doc(user.uid).set({
        'lastViewedLessonId': lessonId,
        'lastViewedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error recording lesson viewed: $e');
    }
  }

  Future<Map<String, dynamic>?> getLessonProgress(String uid, String lessonId) async {
    final doc = await _userProgress(uid).doc(lessonId).get();
    return doc.data();
  }

  Stream<Map<String, dynamic>> userStatsSummaryStream(String uid) {
    if (_userStatsSummaryCache.containsKey(uid)) {
      return _userStatsSummaryCache[uid]!;
    }
    final stream = _userStatsSummaryDoc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return <String, dynamic>{
          'totalLessonsCompleted': 0,
          'totalQuizzesTaken': 0,
          'averageQuizScore': 0.0,
          'flashcardsMastered': 0,
          'flashcardsReviewed': 0,
          'studyStreakDays': 0,
          'lastActiveDate': null,
        };
      }
      return doc.data()!;
    }).asBroadcastStream();
    _userStatsSummaryCache[uid] = stream;
    return stream;
  }

  Future<void> updateUserStatsSummary({
    required String uid,
    int incrementLessons = 0,
    int incrementQuizzes = 0,
    double? newQuizScore,
    int incrementFlashcardsReviewed = 0,
    int incrementFlashcardsMastered = 0,
  }) async {
    try {
      final docRef = _userStatsSummaryDoc(uid);
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

      await _firestore.runTransaction((transaction) async {
        final snap = await transaction.get(docRef);
        final data = snap.data() ?? {};

        int lessons = (data['totalLessonsCompleted'] as num?)?.toInt() ?? 0;
        int quizzes = (data['totalQuizzesTaken'] as num?)?.toInt() ?? 0;
        double avgScore = (data['averageQuizScore'] as num?)?.toDouble() ?? 0.0;
        int fcReviewed = (data['flashcardsReviewed'] as num?)?.toInt() ?? 0;
        int fcMastered = (data['flashcardsMastered'] as num?)?.toInt() ?? 0;
        int streak = (data['studyStreakDays'] as num?)?.toInt() ?? 0;
        String? lastDate = data['lastActiveDate'] as String?;

        lessons += incrementLessons;

        if (incrementQuizzes > 0 && newQuizScore != null) {
          final totalPrev = quizzes;
          quizzes += incrementQuizzes;
          avgScore = ((avgScore * totalPrev) + newQuizScore) / quizzes;
        } else if (incrementQuizzes > 0) {
          quizzes += incrementQuizzes;
        }

        fcReviewed += incrementFlashcardsReviewed;
        fcMastered += incrementFlashcardsMastered;

        // Calculate Streak
        if (lastDate == todayStr) {
          if (streak == 0) streak = 1;
        } else if (lastDate == yesterdayStr) {
          streak += 1;
        } else {
          streak = 1;
        }

        final updateData = <String, dynamic>{
          'totalLessonsCompleted': lessons,
          'totalQuizzesTaken': quizzes,
          'averageQuizScore': double.parse(avgScore.toStringAsFixed(1)),
          'flashcardsReviewed': fcReviewed,
          'flashcardsMastered': fcMastered,
          'studyStreakDays': streak,
          'lastActiveDate': todayStr,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        transaction.set(docRef, updateData, SetOptions(merge: true));
      });
    } catch (e) {
      debugPrint('Error updating user stats summary: $e');
    }
  }

  Future<void> markLessonCompleted({
    required User user,
    required String lessonId,
    bool completed = true,
  }) async {
    lastViewedLessonId = lessonId;
    await _userProgress(user.uid).doc(lessonId).set({
      'completed': completed,
      'progress': completed ? 1.0 : 0.0,
      'completedAt': completed ? FieldValue.serverTimestamp() : null,
      'lastReadAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'lastViewedLessonId': lessonId,
        'lastViewedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating lastViewedLessonId on user doc: $e');
    }

    if (completed) {
      updateUserStatsSummary(uid: user.uid, incrementLessons: 1);
      BadgeService.instance.recordLessonCompletion(user.uid);
    }
  }

  Future<void> markContentCompleted({
    required User user,
    required String contentId,
    bool completed = true,
  }) async {
    await markLessonCompleted(user: user, lessonId: contentId, completed: completed);
  }

  Future<String> createPublishedContent({
    required NotebookOutputType type,
    required String title,
    required Map<String, dynamic> data,
    String? createdByUid,
    String? createdByEmail,
    bool isVisible = true,
    List<String> visibleTo = const [],
    bool isMembersOnly = false,
    bool isGrammaticaContent = false,
    String validationStatus = 'awaiting_approval',
    String? notebookId,
    String? outputId,
    String? lessonId,
  }) async {
    final docRef = await _publishedContent.add({
      'type': type.serialName,
      'title': title,
      'data': data,
      'createdByUid': createdByUid,
      'createdByEmail': createdByEmail,
      'createdAt': FieldValue.serverTimestamp(),
      'isVisible': isVisible,
      'visibleTo': visibleTo,
      'isMembersOnly': isMembersOnly,
      'isGrammaticaContent': isGrammaticaContent,
      'validationStatus': validationStatus,
      'notebookId': ?notebookId,
      'outputId': ?outputId,
      'lessonId': ?lessonId,
    });
    return docRef.id;
  }

  Future<void> updatePublishedContent({
    required String id,
    String? title,
    Map<String, dynamic>? data,
    bool? isVisible,
    List<String>? visibleTo,
    bool? isMembersOnly,
    bool? isGrammaticaContent,
    String? validationStatus,
    String? notebookId,
    String? outputId,
    String? lessonId,
  }) async {
    final updateData = <String, dynamic>{};
    if (title != null) updateData['title'] = title;
    if (data != null) updateData['data'] = data;
    if (isVisible != null) updateData['isVisible'] = isVisible;
    if (visibleTo != null) updateData['visibleTo'] = visibleTo;
    if (isMembersOnly != null) updateData['isMembersOnly'] = isMembersOnly;
    if (isGrammaticaContent != null) updateData['isGrammaticaContent'] = isGrammaticaContent;
    if (validationStatus != null) updateData['validationStatus'] = validationStatus;
    if (notebookId != null) updateData['notebookId'] = notebookId;
    if (outputId != null) updateData['outputId'] = outputId;
    if (lessonId != null) updateData['lessonId'] = lessonId;
    if (updateData.isNotEmpty) {
      await _publishedContent.doc(id).update(updateData);
    }
  }

  Future<void> deletePublishedContent(String id) async {
    await _publishedContent.doc(id).delete();
  }

  Stream<List<PublishedContentItem>> streamPublishedContent({
    UserRole? userRole,
    String? userId,
    NotebookOutputType? type,
    bool approvedOnly = true,
  }) {
    return _publishedContent.orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      var items = snapshot.docs.map(PublishedContentItem.fromDoc).toList();

      if (type != null) {
        items = items.where((item) => item.type == type).toList();
      }

      return items.where((item) {
        final isAuthor = userId != null && item.createdByUid == userId;
        final isValidator = userRole == UserRole.validator;

        // Pending / unapproved items are visible ONLY to the author and validators.
        if (item.validationStatus != 'approved') {
          return isAuthor || isValidator;
        }

        if (isAuthor) return true;
        if (!approvedOnly &&
            (isValidator ||
                userRole == UserRole.admin ||
                userRole == UserRole.superadmin)) {
          return true;
        }
        if (item.isGrammaticaContent && item.isVisible) return true;
        if (item.visibleTo.isNotEmpty) {
          return userId != null && item.visibleTo.contains(userId);
        }
        return item.isVisible;
      }).toList();
    });
  }

  static final Map<String, LinkedContentBundle> _bundleCache = {};

  String _bundleCacheKey(String rawKey) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
    return '${uid}_$rawKey';
  }

  /// Synchronously retrieve cached bundle if already loaded.
  LinkedContentBundle? getCachedBundle(String? key) {
    if (key == null || key.isEmpty) return null;
    return _bundleCache[_bundleCacheKey(key)];
  }

  void _cacheBundle(LinkedContentBundle b, {String? nbId, String? lessonId, String? quizId}) {
    if (nbId != null && nbId.isNotEmpty) _bundleCache[_bundleCacheKey(nbId)] = b;
    if (lessonId != null && lessonId.isNotEmpty) _bundleCache[_bundleCacheKey(lessonId)] = b;
    if (quizId != null && quizId.isNotEmpty) _bundleCache[_bundleCacheKey(quizId)] = b;
    for (final item in b.publishedItems) {
      if (item.id.isNotEmpty) _bundleCache[_bundleCacheKey(item.id)] = b;
    }
  }

  /// Resolves all companion content items (Lesson, Quiz, and PublishedContentItems)
  /// that were synthesized together within the same AI notebook or linked bundle.
  Future<LinkedContentBundle> getLinkedContentBundle({
    String? notebookId,
    Lesson? currentLesson,
    Quiz? currentQuiz,
    PublishedContentItem? currentPublishedItem,
  }) async {
    String? nbId = notebookId ??
        currentLesson?.notebookId ??
        currentQuiz?.notebookId ??
        currentPublishedItem?.notebookId;

    Lesson? lesson = currentLesson;
    Quiz? quiz = currentQuiz;

    // Check fast memory cache first for immediate rendering
    final primaryKey = nbId ?? lesson?.id ?? quiz?.id ?? '';
    final scopedKey = _bundleCacheKey(primaryKey);
    if (primaryKey.isNotEmpty && _bundleCache.containsKey(scopedKey)) {
      final cached = _bundleCache[scopedKey]!;
      _resolveLinkedContentBundle(
        notebookId: nbId,
        currentLesson: lesson,
        currentQuiz: quiz,
        currentPublishedItem: currentPublishedItem,
      ).then((fresh) {
        _cacheBundle(fresh, nbId: fresh.notebookId, lessonId: fresh.lesson?.id, quizId: fresh.quiz?.id);
      }).catchError((_) {});
      return cached;
    }

    final fresh = await _resolveLinkedContentBundle(
      notebookId: nbId,
      currentLesson: lesson,
      currentQuiz: quiz,
      currentPublishedItem: currentPublishedItem,
    );
    _cacheBundle(fresh, nbId: fresh.notebookId, lessonId: fresh.lesson?.id, quizId: fresh.quiz?.id);
    return fresh;
  }

  Future<LinkedContentBundle> _resolveLinkedContentBundle({
    String? notebookId,
    Lesson? currentLesson,
    Quiz? currentQuiz,
    PublishedContentItem? currentPublishedItem,
  }) async {
    String? nbId = notebookId ??
        currentLesson?.notebookId ??
        currentQuiz?.notebookId ??
        currentPublishedItem?.notebookId;

    Lesson? lesson = currentLesson;
    Quiz? quiz = currentQuiz;
    List<PublishedContentItem> items = [];

    // Fallback 1: If nbId is missing, check if lesson has a quizId that contains notebookId
    if ((nbId == null || nbId.isEmpty) && lesson != null) {
      if (lesson.quizId != null && lesson.quizId!.isNotEmpty) {
        try {
          final qDoc = await _quizzes.doc(lesson.quizId).get();
          if (qDoc.exists) {
            quiz ??= Quiz.fromDoc(qDoc);
            if (quiz.notebookId != null && quiz.notebookId!.isNotEmpty) {
              nbId = quiz.notebookId;
            }
          }
        } catch (e) {
          debugPrint('Error resolving notebookId from linked quiz: $e');
        }
      }
      // Fallback 2: Check if NotebookService session tracks this lesson
      if (nbId == null || nbId.isEmpty) {
        final localNbId = NotebookService.instance.findNotebookIdForLesson(lesson.id);
        if (localNbId != null && localNbId.isNotEmpty) {
          nbId = localNbId;
        }
      }
      // Fallback 3: Use lesson.id as bundle anchor
      if (nbId == null || nbId.isEmpty) {
        nbId = lesson.id;
      }
    }

    // Fallback 4: If quiz was provided without notebookId or lesson
    if ((nbId == null || nbId.isEmpty) && quiz != null) {
      final localNbId = NotebookService.instance.findNotebookIdForLesson(quiz.id);
      if (localNbId != null && localNbId.isNotEmpty) {
        nbId = localNbId;
      } else {
        nbId = quiz.id;
      }
    }

    if (nbId != null && nbId.isNotEmpty) {
      Future<QuerySnapshot<Map<String, dynamic>>?> safeGetQuery(Query<Map<String, dynamic>> query) async {
        try {
          return await query.get();
        } catch (e) {
          debugPrint('Error in companion query: $e');
          return null;
        }
      }

      Future<DocumentSnapshot<Map<String, dynamic>>?> safeGetDoc(DocumentReference<Map<String, dynamic>> doc) async {
        try {
          return await doc.get();
        } catch (e) {
          debugPrint('Error in companion doc query: $e');
          return null;
        }
      }

      // 1. Fetch lesson if not already provided
      final lessonFuture = (lesson == null)
          ? safeGetQuery(_lessons.where('notebookId', isEqualTo: nbId).limit(1))
          : Future<QuerySnapshot<Map<String, dynamic>>?>.value(null);

      // 2. Fetch quiz if not already provided
      final quizDocFuture =
          (quiz == null && lesson?.quizId != null && lesson!.quizId!.isNotEmpty)
              ? safeGetDoc(_quizzes.doc(lesson.quizId))
              : Future<DocumentSnapshot<Map<String, dynamic>>?>.value(null);

      final quizNbFuture = (quiz == null)
          ? safeGetQuery(_quizzes.where('notebookId', isEqualTo: nbId).limit(1))
          : Future<QuerySnapshot<Map<String, dynamic>>?>.value(null);

      final quizLessonFuture =
          (quiz == null && lesson != null && lesson.id.isNotEmpty)
              ? safeGetQuery(_quizzes.where('lessonId', isEqualTo: lesson.id).limit(1))
              : Future<QuerySnapshot<Map<String, dynamic>>?>.value(null);

      // 3. Fetch published content items for this notebook
      final pubNbFuture =
          safeGetQuery(_publishedContent.where('notebookId', isEqualTo: nbId));

      // 4. Fetch published items by lessonId
      final pubLessonFuture =
          (lesson != null && lesson.id.isNotEmpty)
              ? safeGetQuery(_publishedContent.where('lessonId', isEqualTo: lesson.id))
              : Future<QuerySnapshot<Map<String, dynamic>>?>.value(null);

      final results = await Future.wait([
        lessonFuture,
        quizDocFuture,
        quizNbFuture,
        quizLessonFuture,
        pubNbFuture,
        pubLessonFuture,
      ]);

      // Process lesson
      if (lesson == null && results[0] != null) {
        final snap = results[0] as QuerySnapshot<Map<String, dynamic>>;
        if (snap.docs.isNotEmpty) {
          lesson = Lesson.fromDoc(snap.docs.first);
        }
      }

      // Process quiz
      if (quiz == null) {
        if (results[1] != null) {
          final doc = results[1] as DocumentSnapshot<Map<String, dynamic>>;
          if (doc.exists) quiz = Quiz.fromDoc(doc);
        }
        if (quiz == null && results[2] != null) {
          final snap = results[2] as QuerySnapshot<Map<String, dynamic>>;
          if (snap.docs.isNotEmpty) quiz = Quiz.fromDoc(snap.docs.first);
        }
        if (quiz == null && results[3] != null) {
          final snap = results[3] as QuerySnapshot<Map<String, dynamic>>;
          if (snap.docs.isNotEmpty) quiz = Quiz.fromDoc(snap.docs.first);
        }
      }

      // Process published items
      if (results[4] != null) {
        final snap = results[4] as QuerySnapshot<Map<String, dynamic>>;
        items = snap.docs.map(PublishedContentItem.fromDoc).toList();
      }
      if (results[5] != null) {
        final snap = results[5] as QuerySnapshot<Map<String, dynamic>>;
        for (final doc in snap.docs) {
          if (!items.any((i) => i.id == doc.id)) {
            items.add(PublishedContentItem.fromDoc(doc));
          }
        }
      }

      // Merge local session outputs
      try {
        final localOutputs = NotebookService.instance.getOutputsForNotebook(nbId);
        for (final out in localOutputs) {
          if (out.type != NotebookOutputType.lesson && out.type != NotebookOutputType.quiz) {
            final alreadyIncluded = items.any((i) =>
                i.id == out.publishedId ||
                i.outputId == out.id ||
                (i.title.trim().toLowerCase() == out.title.trim().toLowerCase() && i.type == out.type));
            if (!alreadyIncluded) {
              items.add(PublishedContentItem.fromNotebookOutput(out));
            }
          }
        }
      } catch (e) {
        debugPrint('Error merging local session notebook outputs: $e');
      }

      // Back-populate missing notebookId on Firestore documents
      if (lesson != null && (lesson.notebookId == null || lesson.notebookId!.isEmpty)) {
        _lessons.doc(lesson.id).update({'notebookId': nbId}).catchError((_) {});
      }
      if (quiz != null && (quiz.notebookId == null || quiz.notebookId!.isEmpty)) {
        _quizzes.doc(quiz.id).update({'notebookId': nbId}).catchError((_) {});
      }
      if (currentPublishedItem != null &&
          (currentPublishedItem.notebookId == null || currentPublishedItem.notebookId!.isEmpty)) {
        _publishedContent.doc(currentPublishedItem.id).update({'notebookId': nbId}).catchError((_) {});
      }
      for (final item in items) {
        if (item.notebookId == null || item.notebookId!.isEmpty) {
          _publishedContent.doc(item.id).update({'notebookId': nbId}).catchError((_) {});
        }
      }
    } else {
      // Legacy fallback
      if (lesson != null &&
          quiz == null &&
          lesson.quizId != null &&
          lesson.quizId!.isNotEmpty) {
        try {
          final qDoc = await _quizzes.doc(lesson.quizId).get();
          if (qDoc.exists) {
            quiz = Quiz.fromDoc(qDoc);
          }
        } catch (e) {
          debugPrint('Error fetching fallback quiz: $e');
        }
      }
    }

    if (currentPublishedItem != null &&
        !items.any((i) => i.id == currentPublishedItem.id)) {
      items.add(currentPublishedItem);
    }

    // Enforce pending / unapproved visibility: only the author and validators may see unapproved items.
    final curUid = FirebaseAuth.instance.currentUser?.uid;
    final curRole = curUid != null
        ? await RoleService.instance.getRole(curUid)
        : UserRole.learner;
    final isValidator = curRole == UserRole.validator;

    if (lesson != null) {
      final canSeeLesson = !lesson.isArchived &&
          (lesson.validationStatus == 'approved' ||
              (curUid != null && lesson.createdByUid == curUid) ||
              isValidator);
      if (!canSeeLesson) lesson = null;
    }

    if (quiz != null) {
      final canSeeQuiz = !quiz.isArchived &&
          (quiz.validationStatus == 'approved' ||
              (curUid != null && quiz.createdByUid == curUid) ||
              isValidator);
      if (!canSeeQuiz) quiz = null;
    }

    items = items.where((item) {
      return item.validationStatus == 'approved' ||
          (curUid != null && item.createdByUid == curUid) ||
          isValidator;
    }).toList();

    return LinkedContentBundle(
      notebookId: nbId,
      lesson: lesson,
      quiz: quiz,
      publishedItems: items,
    );
  }

  Future<void> updateLessonProgress({
    required User user,
    required String lessonId,
    required double progress,
  }) async {
    lastViewedLessonId = lessonId;
    final isCompleted = progress >= 1.0;
    final updateData = <String, dynamic>{
      'progress': progress,
      'lastReadAt': FieldValue.serverTimestamp(),
    };
    if (isCompleted) {
      updateData['completed'] = true;
      updateData['completedAt'] = FieldValue.serverTimestamp();
      updateUserStatsSummary(uid: user.uid, incrementLessons: 1);
    }
    await _userProgress(user.uid).doc(lessonId).set(updateData, SetOptions(merge: true));

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'lastViewedLessonId': lessonId,
        'lastViewedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating lastViewedLessonId on user doc: $e');
    }
  }

  Future<Lesson?> getLessonByQuizId(String quizId) async {
    final snap = await _firestore
        .collection('lessons')
        .where('quizId', isEqualTo: quizId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final lesson = Lesson.fromDoc(snap.docs.first);
    if (lesson.isArchived) return null;
    if (lesson.validationStatus != 'approved') {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final role = uid != null
          ? await RoleService.instance.getRole(uid)
          : UserRole.learner;
      if ((uid == null || lesson.createdByUid != uid) &&
          role != UserRole.validator) {
        return null;
      }
    }
    return lesson;
  }

  Future<String> createQuiz({
    required String title,
    required String description,
    required List<QuizQuestion> questions,
    int duration = 0,
    int maxAttempts = 1,
    String? attachmentUrl,
    String? attachmentName,
    bool isVisible = true,
    List<String> visibleTo = const [],
    bool isMembersOnly = false,
    bool isGrammaticaQuiz = false,
    bool isAssessment = false,
    String? validationStatus,
    String? notebookId,
    bool requiresLessonCompleted = false,
    String? requiredLessonId,
    String? requiredLessonTitle,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    UserRole userRole = UserRole.learner;
    if (user != null) {
      userRole = await RoleService.instance.getRole(user.uid);
    }
    final isAdmin = userRole == UserRole.admin || userRole == UserRole.superadmin;

    // Admin content is permanently Grammatica Official
    final effectiveIsGrammaticaQuiz = isAdmin ? true : isGrammaticaQuiz;

    // All newly uploaded quizzes must go through validation process
    final String status = validationStatus ?? 'awaiting_approval';

    final doc = await _quizzes.add({
      'title': title,
      'description': description,
      'questions': questions.map((q) => q.toMap()).toList(),
      'duration': duration,
      'maxAttempts': maxAttempts,
      'createdAt': FieldValue.serverTimestamp(),
      'createdByUid': user?.uid,
      'createdByEmail': user?.email,
      'validationStatus': status,
      'attachmentUrl': attachmentUrl,
      'attachmentName': attachmentName,
      'isVisible': isVisible,
      'visibleTo': visibleTo,
      'isMembersOnly': isMembersOnly,
      'isGrammaticaQuiz': effectiveIsGrammaticaQuiz,
      'isAssessment': isAssessment,
      'notebookId': notebookId,
      'requiresLessonCompleted': requiresLessonCompleted,
      'requiredLessonId': requiredLessonId,
      'requiredLessonTitle': requiredLessonTitle,
    });
    return doc.id;
  }

  Future<void> updateQuiz({
    required String id,
    String? title,
    String? description,
    List<QuizQuestion>? questions,
    int? duration,
    int? maxAttempts,
    String? attachmentUrl,
    String? attachmentName,
    bool? isVisible,
    List<String>? visibleTo,
    bool? isMembersOnly,
    bool? isGrammaticaQuiz,
    bool? isAssessment,
    String? validationStatus,
    String? notebookId,
    bool? requiresLessonCompleted,
    String? requiredLessonId,
    String? requiredLessonTitle,
  }) async {
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (description != null) data['description'] = description;
    if (questions != null) {
      data['questions'] = questions.map((q) => q.toMap()).toList();
    }
    if (duration != null) data['duration'] = duration;
    if (maxAttempts != null) data['maxAttempts'] = maxAttempts;
    if (attachmentUrl != null) data['attachmentUrl'] = attachmentUrl;
    if (attachmentName != null) data['attachmentName'] = attachmentName;
    if (isVisible != null) data['isVisible'] = isVisible;
    if (visibleTo != null) data['visibleTo'] = visibleTo;
    if (isMembersOnly != null) data['isMembersOnly'] = isMembersOnly;
    if (isGrammaticaQuiz != null) data['isGrammaticaQuiz'] = isGrammaticaQuiz;
    if (isAssessment != null) data['isAssessment'] = isAssessment;
    if (validationStatus != null) {
      data['validationStatus'] = validationStatus;
    } else if (isAssessment == true) {
      data['validationStatus'] = 'awaiting_approval';
    }
    if (notebookId != null) data['notebookId'] = notebookId;
    if (requiresLessonCompleted != null) data['requiresLessonCompleted'] = requiresLessonCompleted;
    if (requiredLessonId != null) data['requiredLessonId'] = requiredLessonId;
    if (requiredLessonTitle != null) data['requiredLessonTitle'] = requiredLessonTitle;

    if (data.isNotEmpty) {
      await _quizzes.doc(id).update(data);
    }
  }

  void _extractQuizImageUrls(List<dynamic>? questions, Set<String> targetSet) {
    if (questions == null) return;
    for (final q in questions) {
      if (q is Map<String, dynamic>) {
        final imgUrl = q['imageUrl'] as String?;
        if (imgUrl != null && imgUrl.contains('firebasestorage.googleapis.com')) {
          targetSet.add(imgUrl);
        }
      }
    }
  }

  Future<void> deleteQuiz(String id) async {
    final doc = await _quizzes.doc(id).get();
    if (doc.exists) {
      final data = doc.data() ?? {};
      await _deleteFileFromUrl(data['attachmentUrl'] as String?);
      final urls = <String>{};
      final questions = data['questions'] as List?;
      _extractQuizImageUrls(questions, urls);
      for (final url in urls) {
        await _deleteFileFromUrl(url);
      }

      // Remove quizId reference in lessons pointing to this quiz
      try {
        final linkedLessons = await _lessons.where('quizId', isEqualTo: id).get();
        for (final lDoc in linkedLessons.docs) {
          await _lessons.doc(lDoc.id).update({'quizId': null});
        }
      } catch (e) {
        debugPrint('Error unlinking quiz from lessons: $e');
      }

      // Clean up user quiz progress docs referencing this quiz
      try {
        final usersSnap = await _firestore.collection('users').get();
        for (final userDoc in usersSnap.docs) {
          await _userQuizProgress(userDoc.id).doc(id).delete();
        }
      } catch (e) {
        debugPrint('Error cleaning up quiz progress: $e');
      }
    }
    await _quizzes.doc(id).delete();
  }

  Future<Quiz?> getQuiz(String id) async {
    final doc = await _quizzes.doc(id).get();
    if (!doc.exists) return null;
    return Quiz.fromDoc(doc);
  }

  Future<List<Quiz>> fetchQuizzes() async {
    final snap = await _quizzes.orderBy('createdAt', descending: false).get();
    return snap.docs.map(Quiz.fromDoc).where((q) => !q.isArchived).toList();
  }

  Stream<List<Quiz>> streamQuizzes({
    bool approvedOnly = true,
    UserRole? userRole,
    String? userId,
    bool? isAssessment,
  }) {
    // To avoid composite index requirements and support legacy content,
    // we filter out awaiting_approval docs in Dart.
    return _quizzes.orderBy('createdAt', descending: false).snapshots().map((
      snapshot,
    ) {
      var quizzes = snapshot.docs.map(Quiz.fromDoc).where((q) => !q.isArchived).toList();

      if (isAssessment != null) {
        quizzes = quizzes.where((q) => q.isAssessment == isAssessment).toList();
      }

      return quizzes.where((q) {
        final isAuthor = userId != null && q.createdByUid == userId;
        final isValidator = userRole == UserRole.validator;

        if (q.validationStatus != 'approved') {
          return isAuthor || isValidator;
        }

        if (isAuthor) return true;
        if (!approvedOnly &&
            (isValidator ||
                userRole == UserRole.admin ||
                userRole == UserRole.superadmin)) {
          return true;
        }
        return q.isVisible || (userId != null && q.visibleTo.contains(userId));
      }).toList();
    });
  }

  Stream<List<Quiz>> streamAwaitingApprovalQuizzes() {
    return _quizzes
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(Quiz.fromDoc)
              .where((q) => q.validationStatus == 'awaiting_approval' && !q.isAssessment && !q.isArchived)
              .toList(),
        );
  }

  Stream<List<Quiz>> streamAwaitingApprovalAssessments() {
    return _quizzes
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(Quiz.fromDoc)
              .where((q) => q.validationStatus == 'awaiting_approval' && q.isAssessment && !q.isArchived)
              .toList(),
        );
  }

  Stream<List<Lesson>> streamRejectedLessons() {
    return _lessons
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(Lesson.fromDoc)
              .where((l) => l.validationStatus == 'rejected')
              .toList(),
        );
  }

  Stream<List<Quiz>> streamRejectedQuizzes() {
    return _quizzes
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(Quiz.fromDoc)
              .where((q) => q.validationStatus == 'rejected' && !q.isAssessment)
              .toList(),
        );
  }

  Stream<List<Quiz>> streamRejectedAssessments() {
    return _quizzes
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(Quiz.fromDoc)
              .where((q) => q.validationStatus == 'rejected' && q.isAssessment)
              .toList(),
        );
  }

  Stream<List<EducatorApplication>> streamRejectedApplications() {
    return _educatorApplications
        .orderBy('appliedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(EducatorApplication.fromDoc)
              .where((a) => a.status == 'rejected')
              .toList(),
        );
  }


  Future<void> updateContentStatus(
    String collection,
    String id,
    String status, {
    String? rejectionReason,
    String? rejectionDescription,
  }) async {
    final data = <String, dynamic>{'validationStatus': status};
    if (rejectionReason != null) {
      data['rejectionReason'] = rejectionReason;
    }
    if (rejectionDescription != null) {
      data['rejectionDescription'] = rejectionDescription;
    }
    await _firestore.collection(collection).doc(id).update(data);
  }

  /// Atomically updates a lesson and all of its linked content
  /// (linked quiz and companion published items) to the given status ('approved' or 'rejected').
  Future<void> updateLessonPackageStatus({
    required Lesson lesson,
    required String status,
    String? rejectionReason,
    String? rejectionDescription,
  }) async {
    final batch = _firestore.batch();

    // 1. Update the lesson document
    final lessonRef = _lessons.doc(lesson.id);
    final lessonData = <String, dynamic>{
      'validationStatus': status,
      'reviewedAt': FieldValue.serverTimestamp(),
      'isUpdate': false,
    };
    if (rejectionReason != null) {
      lessonData['rejectionReason'] = rejectionReason;
    }
    if (rejectionDescription != null) {
      lessonData['rejectionDescription'] = rejectionDescription;
    }
    batch.update(lessonRef, lessonData);

    // 2. Cascade to primary linked quiz
    if (lesson.quizId != null && lesson.quizId!.isNotEmpty) {
      final quizRef = _quizzes.doc(lesson.quizId);
      final quizData = <String, dynamic>{
        'validationStatus': status,
        'reviewedAt': FieldValue.serverTimestamp(),
      };
      if (rejectionReason != null) quizData['rejectionReason'] = rejectionReason;
      if (rejectionDescription != null) quizData['rejectionDescription'] = rejectionDescription;
      batch.update(quizRef, quizData);
    }

    // 3. Cascade to any companion quizzes and published items linked via notebookId or lesson.id
    final nbId = lesson.notebookId ?? lesson.id;
    if (nbId.isNotEmpty) {
      try {
        final quizzesSnap = await _quizzes.where('notebookId', isEqualTo: nbId).get();
        for (final doc in quizzesSnap.docs) {
          if (doc.id != lesson.quizId) {
            final qData = <String, dynamic>{
              'validationStatus': status,
              'reviewedAt': FieldValue.serverTimestamp(),
            };
            if (rejectionReason != null) qData['rejectionReason'] = rejectionReason;
            if (rejectionDescription != null) qData['rejectionDescription'] = rejectionDescription;
            batch.update(doc.reference, qData);
          }
        }
      } catch (e) {
        debugPrint('Error finding companion quizzes to update status: $e');
      }

      try {
        final publishedSnap = await _publishedContent.where('notebookId', isEqualTo: nbId).get();
        for (final doc in publishedSnap.docs) {
          final pData = <String, dynamic>{
            'validationStatus': status,
            'reviewedAt': FieldValue.serverTimestamp(),
          };
          if (rejectionReason != null) pData['rejectionReason'] = rejectionReason;
          if (rejectionDescription != null) pData['rejectionDescription'] = rejectionDescription;
          batch.update(doc.reference, pData);
        }
      } catch (e) {
        debugPrint('Error finding published companion items to update status: $e');
      }

      if (lesson.id.isNotEmpty) {
        try {
          final pubByLessonSnap = await _publishedContent.where('lessonId', isEqualTo: lesson.id).get();
          for (final doc in pubByLessonSnap.docs) {
            final pData = <String, dynamic>{
              'validationStatus': status,
              'reviewedAt': FieldValue.serverTimestamp(),
            };
            if (rejectionReason != null) pData['rejectionReason'] = rejectionReason;
            if (rejectionDescription != null) pData['rejectionDescription'] = rejectionDescription;
            batch.update(doc.reference, pData);
          }
        } catch (e) {
          debugPrint('Error finding published companion items by lessonId to update status: $e');
        }
      }
    }

    await batch.commit();
  }

  Future<List<Map<String, dynamic>>> fetchQuizResults(String quizId) async {
    final usersSnap = await _firestore.collection('users').get();
    final results = <Map<String, dynamic>>[];

    for (final userDoc in usersSnap.docs) {
      final userData = userDoc.data();
      final progressDoc = await _userQuizProgress(userDoc.id).doc(quizId).get();

      if (progressDoc.exists) {
        final pData = progressDoc.data()!;
        results.add({
          'username': userData['username'] ?? userData['email'] ?? 'Unknown',
          'email': userData['email'],
          'uid': userDoc.id,
          'isCorrect': pData['isCorrect'] == true,
          'attemptsUsed': pData['attemptsUsed'] ?? 0,
          'completed': pData['completed'] == true,
        });
      }
    }
    return results;
  }

  Future<Map<String, dynamic>?> getQuizProgress(String uid, String quizId) async {
    try {
      final doc = await _userQuizProgress(uid).doc(quizId).get();
      if (doc.exists && doc.data() != null) {
        return doc.data();
      }
    } catch (_) {}
    return null;
  }

  Future<void> markQuizCompleted({
    required User user,
    required String quizId,
    required bool passed,
    int? score,
    int? totalQuestions,
    List<String>? answers,
    int? timeTaken,
  }) async {
    final docRef = _userQuizProgress(user.uid).doc(quizId);

    final updateData = <String, dynamic>{
      'attemptsUsed': FieldValue.increment(1),
      'lastAnswers': answers,
      'score': score,
      'totalQuestions': totalQuestions,
      'timeTaken': timeTaken,
      'lastAttemptAt': FieldValue.serverTimestamp(),
      'passed': passed,
    };

    if (passed) {
      updateData['completed'] = true;
      updateData['completedAt'] = FieldValue.serverTimestamp();
    }

    await docRef.set(updateData, SetOptions(merge: true));

    final quizPct = (totalQuestions != null && totalQuestions > 0 && score != null)
        ? (score / totalQuestions * 100).toDouble()
        : null;
    updateUserStatsSummary(
      uid: user.uid,
      incrementQuizzes: 1,
      newQuizScore: quizPct,
    );
  }

  Future<void> completeQuizAndLesson({
    required User user,
    required String quizId,
    required bool passed,
    required bool isCorrect,
    int? score,
    int? totalQuestions,
    List<String>? answers,
    int? timeTaken,
    String? lessonId,
  }) async {
    final batch = _firestore.batch();

    // Quiz Progress
    final quizRef = _userQuizProgress(user.uid).doc(quizId);
    final quizData = <String, dynamic>{
      'attemptsUsed': FieldValue.increment(1),
      'lastAnswers': answers,
      'score': score,
      'totalQuestions': totalQuestions,
      'timeTaken': timeTaken,
      'lastAttemptAt': FieldValue.serverTimestamp(),
      'passed': passed,
      'isCorrect': isCorrect,
    };
    if (passed) {
      quizData['completed'] = true;
      quizData['completedAt'] = FieldValue.serverTimestamp();
    }
    batch.set(quizRef, quizData, SetOptions(merge: true));

    // Lesson Progress if applicable
    if (lessonId != null) {
      final lessonRef = _userProgress(user.uid).doc(lessonId);
      batch.set(lessonRef, {
        'completed': passed,
        'completedAt': passed ? FieldValue.serverTimestamp() : null,
      }, SetOptions(merge: true));
    }

    await batch.commit();

    final quizPct = (totalQuestions != null && totalQuestions > 0 && score != null)
        ? (score / totalQuestions * 100).toDouble()
        : null;
    updateUserStatsSummary(
      uid: user.uid,
      incrementQuizzes: 1,
      newQuizScore: quizPct,
      incrementLessons: (passed && lessonId != null) ? 1 : 0,
    );
  }

  Stream<Map<String, Map<String, dynamic>>> quizProgressStream(User user) {
    if (_quizProgressCache.containsKey(user.uid)) {
      return _quizProgressCache[user.uid]!;
    }
    final stream = _userQuizProgress(user.uid).snapshots().map((q) {
      final map = <String, Map<String, dynamic>>{};
      for (final d in q.docs) {
        final data = d.data();
        map[d.id] = {
          'completed': data['completed'] == true,
          'passed': data['passed'] == true,
          'isCorrect': data['isCorrect'] == true,
          'attemptsUsed': data['attemptsUsed'] ?? 0,
          'completedAt': data['completedAt'],
          'score': data['score'],
          'totalQuestions': data['totalQuestions'],
          'timeTaken': data['timeTaken'],
          'lastAttemptAt': data['lastAttemptAt'],
          'lastAnswers': data['lastAnswers'],
        };
      }
      return map;
    }).asBroadcastStream();
    _quizProgressCache[user.uid] = stream;
    return stream;
  }

  CollectionReference<Map<String, dynamic>> get _images =>
      _firestore.collection('images');

  Future<String> uploadImage({
    required String userId,
    required Uint8List imageBytes,
    required String fileName,
    String? description,
  }) async {
    try {
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
      await _images.doc(imageId).delete();
      await _deleteFileFromUrl(imageUrl);
    } catch (e) {
      throw Exception('Failed to delete image: $e');
    }
  }

  Future<String> uploadDocument({
    required Uint8List fileBytes,
    required String fileName,
    required String folder, // 'lessons' or 'quizzes'
  }) async {
    try {
      // 2MB check should be done in UI, but safe to have here if needed.
      // We will trust the UI to check size for now to keep this flexible.

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('${folder}_documents')
          .child('${DateTime.now().millisecondsSinceEpoch}_$fileName');

      final uploadTask = storageRef.putData(
        fileBytes,
        SettableMetadata(contentType: 'application/pdf'),
      );

      final snapshot = await uploadTask.whenComplete(() => null);
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload document: $e');
    }
  }

  Future<String> uploadGeneratedImage(Uint8List bytes, String fileName, {String? folder}) async {
    try {
      final targetFolder = folder ?? 'lesson_images';
      final uniqueFileName = generateUniqueImageKey(fileName);
      final storageRef = FirebaseStorage.instance
          .ref()
          .child(targetFolder)
          .child(uniqueFileName);

      final compressedBytes = await compressImageBytes(bytes);
      final mimeType = getMimeType(fileName);

      final uploadTask = storageRef.putData(
        compressedBytes,
        SettableMetadata(contentType: mimeType),
      );

      final snapshot = await uploadTask.whenComplete(() => null);
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> streamEducators() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'EDUCATOR')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'uid': doc.id, ...doc.data()})
              .toList(),
        );
  }

  Stream<List<Lesson>> streamEducatorLessons(
    String educatorUid, {
    bool publicOnly = false,
  }) {
    return _lessons
        .where('createdByUid', isEqualTo: educatorUid)
        .where('isVisible', isEqualTo: true)
        .where('validationStatus', isEqualTo: 'approved')
        .snapshots()
        .map((snapshot) {
          final lessons = snapshot.docs
              .map(Lesson.fromDoc)
              .where((l) => !l.isArchived)
              .toList();
          if (publicOnly) {
            return lessons.where((l) => !l.isMembersOnly).toList();
          }
          return lessons;
        });
  }

  Stream<List<Quiz>> streamEducatorQuizzes(
    String educatorUid, {
    bool publicOnly = false,
  }) {
    return _quizzes
        .where('createdByUid', isEqualTo: educatorUid)
        .where('isVisible', isEqualTo: true)
        .where('validationStatus', isEqualTo: 'approved')
        .snapshots()
        .map((snapshot) {
          final quizzes = snapshot.docs
              .map(Quiz.fromDoc)
              .where((q) => !q.isArchived)
              .toList();
          if (publicOnly) {
            return quizzes.where((q) => !q.isMembersOnly).toList();
          }
          return quizzes;
        });
  }

  Future<void> updateSubscriptionPricing(
    String uid, {
    required int premium,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'subscription_pricing': {'premium': premium},
      'subscription_fee': premium,
    });
  }

  /// Checks if a user has already achieved a specific milestone.
  /// If not, it records the achievement and returns true.
  /// Returns false if already achieved.
  Future<bool> checkAndAwardAchievement(
    String uid,
    String achievementId,
  ) async {
    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('achievements')
        .doc(achievementId);

    final doc = await docRef.get();
    if (doc.exists) {
      return false;
    }

    await docRef.set({
      'achievedAt': FieldValue.serverTimestamp(),
      'id': achievementId,
    });
    return true;
  }

  Future<void> subscribeToEducator(String educatorUid, String tier) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Check if subscription was already active on the same tier to prevent duplicate notifications
    bool wasAlreadyActive = false;
    try {
      final existingSub = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('subscriptions')
          .doc(educatorUid)
          .get();
      if (existingSub.exists) {
        final data = existingSub.data() ?? {};
        if (data['status'] == 'active' && data['tier'] == tier) {
          wasAlreadyActive = true;
        }
      }
    } catch (_) {}

    final batch = _firestore.batch();

    // Educator's view: list of active subscribers
    batch.set(
      _firestore
          .collection('users')
          .doc(educatorUid)
          .collection('subscribers')
          .doc(user.uid),
      {'subscribedAt': FieldValue.serverTimestamp(), 'tier': tier},
    );

    // Learner's view: list of their subscriptions
    batch.set(
      _firestore
          .collection('users')
          .doc(user.uid)
          .collection('subscriptions')
          .doc(educatorUid),
      {
        'educatorUid': educatorUid,
        'status': 'active',
        'tier': tier,
        'billingCycle': 'monthly',
        'subscribedAt': FieldValue.serverTimestamp(),
        'cancelledAt': null,
      },
      SetOptions(merge: true),
    );

    await batch.commit();

    if (wasAlreadyActive) {
      debugPrint('[SubscriptionIdempotency] User already subscribed to $tier. Skipping duplicate notifications.');
      return;
    }

    // Send notifications only on fresh or changed subscription
    try {
      final learnerDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();
      final educatorDoc = await _firestore
          .collection('users')
          .doc(educatorUid)
          .get();

      final learnerName =
          learnerDoc.data()?['username'] ?? user.displayName ?? 'User';
      final educatorName = educatorDoc.data()?['username'] ?? 'Educator';

      await NotificationService.instance.sendSubscriptionNotification(
        learnerUid: user.uid,
        educatorUid: educatorUid,
        learnerName: learnerName,
        educatorName: educatorName,
        tier: tier,
      );
    } catch (e) {
      debugPrint('Error sending subscription notifications: $e');
    }
  }

  /// Records a successful payment receipt in Firestore and updates subscription status.
  /// Fully idempotent: uses deterministic document IDs and transaction checking
  /// to prevent duplicate charges, duplicate receipts, and double notification broadcasts.
  Future<PaymentRecordResult> recordSubscriptionPayment({
    required String educatorUid,
    required String educatorName,
    required String tier,
    required double amount,
    required String referenceNumber,
    required String paymentMethod,
    String? paymongoLinkId,
    String? idempotencyKey,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const PaymentRecordResult(
        isSuccess: false,
        isDuplicate: false,
        paymentId: '',
        message: 'No authenticated user.',
      );
    }

    // Compute deterministic document ID based on paymongoLinkId or referenceNumber
    final String sanitizedRef =
        referenceNumber.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final String docId = (paymongoLinkId != null &&
            paymongoLinkId.isNotEmpty &&
            !paymongoLinkId.startsWith('link_merchant_'))
        ? 'pay_${paymongoLinkId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}'
        : 'pay_$sanitizedRef';

    final effectiveKey = idempotencyKey ?? docId;

    // Execute through client-side single-flight task coalescer
    return await IdempotencyService.instance.executeDeduplicated<PaymentRecordResult>(
      key: 'record_payment_$docId',
      action: () async {
        final paymentDocRef = _firestore
            .collection('users')
            .doc(user.uid)
            .collection('payments')
            .doc(docId);

        // 1. Check if payment was already recorded
        try {
          final existingSnap = await paymentDocRef.get();
          if (existingSnap.exists) {
            final data = existingSnap.data() ?? {};
            if (data['status'] == 'paid') {
              debugPrint(
                  '[PaymentIdempotency] Payment $docId was ALREADY recorded. Replaying cleanly.');
              return PaymentRecordResult(
                isSuccess: true,
                isDuplicate: true,
                paymentId: docId,
                message: 'Payment was previously recorded.',
              );
            }
          }
        } catch (e) {
          debugPrint('[PaymentIdempotency] Note: Read check error: $e');
        }

        // 2. Activate or upgrade subscription status
        await subscribeToEducator(educatorUid, tier);

        // 3. Write receipt document in user's payments subcollection
        final paymentData = {
          'paymentId': docId,
          'learnerUid': user.uid,
          'learnerEmail': user.email ?? '',
          'learnerName': user.displayName ?? 'Learner',
          'educatorUid': educatorUid,
          'educatorName': educatorName,
          'tier': tier,
          'amount': amount,
          'amountPhp': amount,
          'currency': 'PHP',
          'referenceNumber': referenceNumber,
          'paymentMethod': paymentMethod,
          'paymongoLinkId': paymongoLinkId ?? '',
          'idempotencyKey': effectiveKey,
          'status': 'paid',
          'createdAt': FieldValue.serverTimestamp(),
        };

        await paymentDocRef.set(paymentData, SetOptions(merge: true));

        // 4. Write in top-level payments collection for administrative & analytics tracking
        try {
          await _firestore
              .collection('payments')
              .doc(docId)
              .set(paymentData, SetOptions(merge: true));
        } catch (e) {
          debugPrint('[DatabaseService] Note: top-level payments ledger write: $e');
        }

        // 5. Record in global idempotency_keys collection
        try {
          await _firestore
              .collection('idempotency_keys')
              .doc(effectiveKey)
              .set({
            'key': effectiveKey,
            'scope': 'subscription_payment',
            'docId': docId,
            'learnerUid': user.uid,
            'educatorUid': educatorUid,
            'tier': tier,
            'amount': amount,
            'referenceNumber': referenceNumber,
            'status': 'RESOLVED',
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('[DatabaseService] Note: global idempotency key record write: $e');
        }

        // 6. Mark locally completed
        await IdempotencyService.instance.markCompletedLocally(
          effectiveKey,
          metadata: {'docId': docId, 'referenceNumber': referenceNumber},
        );

        return PaymentRecordResult(
          isSuccess: true,
          isDuplicate: false,
          paymentId: docId,
          message: 'Payment recorded successfully.',
        );
      },
    );
  }

  /// Stream of payment receipts for the learner (defaults to currently signed-in user).
  Stream<List<Map<String, dynamic>>> streamLearnerPayments([String? learnerUid]) {
    final targetUid = learnerUid ?? FirebaseAuth.instance.currentUser?.uid;
    if (targetUid == null) return Stream.value([]);
    return _firestore
        .collection('users')
        .doc(targetUid)
        .collection('payments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  Future<void> unsubscribeFromEducator(String educatorUid) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final batch = _firestore.batch();

    // Remove from educator's active list
    batch.delete(
      _firestore
          .collection('users')
          .doc(educatorUid)
          .collection('subscribers')
          .doc(user.uid),
    );

    // Mark as cancelled in learner's list
    batch.update(
      _firestore
          .collection('users')
          .doc(user.uid)
          .collection('subscriptions')
          .doc(educatorUid),
      {'status': 'cancelled', 'cancelledAt': FieldValue.serverTimestamp()},
    );

    await batch.commit();
  }

  Stream<Map<String, int>> getTieredSubscriberCounts(String educatorUid) {
    return _firestore
        .collection('users')
        .doc(educatorUid)
        .collection('subscribers')
        .snapshots()
        .map((snapshot) {
          int basic = 0;
          int premium = 0;

          for (var doc in snapshot.docs) {
            final tier = doc.data()['tier'] as String?;
            if (tier == 'Premium' || tier == 'Standard') {
              premium++;
            } else {
              basic++;
            }
          }

          return {'Basic': basic, 'Premium': premium};
        });
  }

  Future<void> updateSubscriptionBillingCycle(
    String educatorUid,
    String cycle,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('subscriptions')
        .doc(educatorUid)
        .update({'billingCycle': cycle});
  }

  // Spelling Bee Methods

  Future<void> createSpellingWord({
    required String word,
    required SpellingDifficulty difficulty,
    String? audioUrl,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final normalized = word.trim().toLowerCase();

    // Check for duplicates
    final existing = await _spellingWords
        .where('word_lowercase', isEqualTo: normalized)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return; // Silent ignore or throw error? Let's ignore for now.
    }

    await _spellingWords.add({
      'word': word.trim(),
      'word_lowercase': normalized,
      'difficulty': difficulty.name.toUpperCase(),
      'createdAt': FieldValue.serverTimestamp(),
      'createdByUid': user?.uid,
      'audioUrl': audioUrl,
    });
  }

  Future<String> uploadSpellingAudio({
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('UPLOAD ERROR: No authenticated user found.');
    } else {
      debugPrint('UPLOAD ATTEMPT: User UID is ${user.uid}');
    }

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('spelling_audio')
          .child('${DateTime.now().millisecondsSinceEpoch}_$fileName');

      String contentType = 'audio/mpeg';
      if (fileName.endsWith('.m4a')) contentType = 'audio/mp4';
      if (fileName.endsWith('.wav')) contentType = 'audio/wav';

      final uploadTask = storageRef.putData(
        fileBytes,
        SettableMetadata(contentType: contentType),
      );

      final snapshot = await uploadTask.whenComplete(() => null);
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload audio: $e');
    }
  }

  Future<void> updateSpellingWord({
    required String id,
    String? word,
    SpellingDifficulty? difficulty,
  }) async {
    final data = <String, dynamic>{};
    if (word != null) data['word'] = word;
    if (difficulty != null) data['difficulty'] = difficulty.name.toUpperCase();
    if (data.isNotEmpty) {
      await _spellingWords.doc(id).update(data);
    }
  }

  /// Deletes a specific spelling word by its document ID.
  Future<void> deleteSpellingWord(String id) async {
    final doc = await _spellingWords.doc(id).get();
    if (doc.exists) {
      final data = doc.data();
      await _deleteFileFromUrl(data?['audioUrl']);
    }
    await _spellingWords.doc(id).delete();
  }

  Future<void> deleteAllSpellingWords() async {
    final batch = _firestore.batch();
    final snapshot = await _spellingWords.get();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<int> cleanupDuplicateSpellingWords() async {
    final snapshot = await _spellingWords.get();
    final seen = <String, String>{}; // word_lowercase -> first doc id
    int count = 0;

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final wordRaw = data['word'] as String?;
      if (wordRaw == null) continue;

      final word =
          (data['word_lowercase'] as String?) ?? wordRaw.trim().toLowerCase();

      if (seen.containsKey(word)) {
        batch.delete(doc.reference);
        count++;
      } else {
        seen[word] = doc.id;
        // Also ensure word_lowercase exists
        if (data['word_lowercase'] == null) {
          batch.update(doc.reference, {'word_lowercase': word});
        }
      }
    }
    await batch.commit();
    return count;
  }

  Future<List<SpellingWord>> fetchSpellingWords({
    SpellingDifficulty? difficulty,
  }) async {
    // To avoid composite index requirements, we fetch all and filter in memory.
    final snapshot = await _spellingWords.get();
    var words = snapshot.docs.map(SpellingWord.fromDoc).toList();

    if (difficulty != null) {
      words = words.where((w) => w.difficulty == difficulty).toList();
    }

    // Sort by createdAt descending, handling nulls (newly added words)
    words.sort((a, b) {
      final aTime = a.createdAt?.toDate() ?? DateTime.now();
      final bTime = b.createdAt?.toDate() ?? DateTime.now();
      return bTime.compareTo(aTime);
    });

    return words;
  }

  Stream<bool> isSubscribedStream(String educatorUid) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(false);
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('subscriptions')
        .doc(educatorUid)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return false;
          final data = doc.data();
          if (data?['status'] != 'active') return false;
          final tier = (data?['tier'] ?? '').toString().toLowerCase();
          return tier == 'premium' || tier == 'standard';
        });
  }

  Stream<Set<String>> streamActiveSubscribedEducatorIds(String learnerUid) {
    return _firestore
        .collection('users')
        .doc(learnerUid)
        .collection('subscriptions')
        .snapshots()
        .map((snapshot) {
          final set = <String>{};
          for (final doc in snapshot.docs) {
            final data = doc.data();
            if (data['status'] == 'active') {
              set.add(doc.id);
              final eduUid = data['educatorUid']?.toString();
              if (eduUid != null && eduUid.isNotEmpty) {
                set.add(eduUid);
              }
            }
          }
          return set;
        });
  }

  Future<Map<String, dynamic>?> getSubscription(String learnerUid, String educatorUid) async {
    final doc = await _firestore
        .collection('users')
        .doc(learnerUid)
        .collection('subscriptions')
        .doc(educatorUid)
        .get();
    return doc.data();
  }

  Stream<List<Map<String, dynamic>>> streamLearnerSubscriptions(
    String learnerUid,
  ) {
    return _firestore
        .collection('users')
        .doc(learnerUid)
        .collection('subscriptions')
        .snapshots()
        .asyncMap((snapshot) async {
          final List<Map<String, dynamic>> subscriptions = [];
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final eduUid = (data['educatorUid'] ?? data['educatorId'] ?? doc.id) as String?;
            if (eduUid == null || eduUid.isEmpty) continue;
            final eduDoc = await _firestore
                .collection('users')
                .doc(eduUid)
                .get();
            if (eduDoc.exists) {
              subscriptions.add({'educatorData': eduDoc.data(), ...data});
            }
          }
          return subscriptions;
        });
  }

  Stream<List<Map<String, dynamic>>> streamEducatorSubscribers(
    String educatorUid,
  ) {
    return _firestore
        .collection('users')
        .doc(educatorUid)
        .collection('subscribers')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => {
        'uid': doc.id,
        ...doc.data(),
      }).toList();
    });
  }

  // New helper for fetching user details without blocking the subscriber stream
  Stream<Map<String, dynamic>> streamUserDetails(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) => {
      ...doc.data() ?? {},
      'uid': doc.id,
    });
  }

  /// Archives a user account.
  /// Per system requirements: Accounts are NEVER permanently deleted.
  /// All accounts are preserved in the archive so emails cannot be recycled or claimed,
  /// and the archived user is permanently barred from logging in.
  Future<void> archiveUserAccount(String uid, {bool asSuperAdmin = false}) async {
    try {
      final userDocSnap = await _firestore.collection('users').doc(uid).get();
      if (userDocSnap.exists) {
        if (RoleService.isDefaultAdmin(userDocSnap.data(), uid)) {
          throw Exception('The default Super Admin account cannot be archived.');
        }
        final role = (userDocSnap.data()?['role'] as String?)?.toUpperCase();
        if (!asSuperAdmin && (role == 'ADMIN' || role == 'SUPERADMIN')) {
          throw Exception('Administrator accounts cannot be archived.');
        }
      }

      final userData = userDocSnap.data() ?? {};
      final email = userData['email'] ?? '';
      final username = userData['username'] ?? userData['full_name'] ?? '';
      final role = userData['role'] ?? 'LEARNER';

      // 1. Mark account as ARCHIVED in users collection
      await _firestore.collection('users').doc(uid).set({
        'status': 'ARCHIVED',
        'isArchived': true,
        'is_active': false,
        'archivedAt': FieldValue.serverTimestamp(),
        'archivedBySuperAdmin': asSuperAdmin,
      }, SetOptions(merge: true));

      // 2. Record archive audit entry
      await _firestore.collection('archived_users').doc(uid).set({
        'uid': uid,
        'email': email,
        'username': username,
        'role': role,
        'archivedAt': FieldValue.serverTimestamp(),
        'bySuperAdmin': asSuperAdmin,
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to archive user account: $e');
    }
  }

  /// Restores an archived user account back to ACTIVE status.
  Future<void> unarchiveUserAccount(String uid, {bool asSuperAdmin = false}) async {
    try {
      final userDocSnap = await _firestore.collection('users').doc(uid).get();
      if (!userDocSnap.exists) {
        throw Exception('User account not found.');
      }

      // 1. Mark account as ACTIVE in users collection
      await _firestore.collection('users').doc(uid).set({
        'status': 'ACTIVE',
        'isArchived': false,
        'is_active': true,
        'unarchivedAt': FieldValue.serverTimestamp(),
        'unarchivedBySuperAdmin': asSuperAdmin,
      }, SetOptions(merge: true));

      // 2. Remove from archived_users collection
      await _firestore.collection('archived_users').doc(uid).delete();
    } catch (e) {
      throw Exception('Failed to unarchive user account: $e');
    }
  }

  /// Permanently removes a user account from Firestore.
  /// Used exclusively when the owner of the account permanently deletes their account.
  /// Completely deletes the user doc, any archive record, and any lingering lockout document.
  Future<void> permanentlyDeleteUserAccount(String uid, {String? email}) async {
    try {
      // 1. Delete user document from users collection
      await _firestore.collection('users').doc(uid).delete();

      // 2. Remove any archive audit doc in archived_users
      await _firestore.collection('archived_users').doc(uid).delete();

      // 3. Clear any lockout documents for this email so new signup starts clean
      if (email != null && email.trim().isNotEmpty) {
        final emailClean = email.trim().toLowerCase().replaceAll('/', '_');
        try {
          await _firestore.collection('login_attempts').doc(emailClean).delete();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error in permanentlyDeleteUserAccount: $e');
      throw Exception('Failed to permanently delete user account from database: $e');
    }
  }

  /// Backward-compatible wrapper: accounts are NEVER permanently deleted.
  /// Routes directly to [archiveUserAccount].
  Future<void> deleteUserAccount(String uid, {bool asSuperAdmin = false}) async {
    await archiveUserAccount(uid, asSuperAdmin: asSuperAdmin);
  }

  // --- Rating and Review System ---

  Future<void> addReview(String educatorUid, Review review) async {
    final batch = _firestore.batch();
    // Use doc() for multiple reviews per user, or use reviewerUid for one review per user.
    // User requested "reviews disappearing" which happens when overwriting the same reviewerUid.
    // Switching to doc() to allow multiple reviews.
    final reviewRef = _firestore
        .collection('users')
        .doc(educatorUid)
        .collection('reviews')
        .doc(); 

    final educatorRef = _firestore.collection('users').doc(educatorUid);

    // Get current rating data
    final educatorDoc = await educatorRef.get();
    final data = educatorDoc.data() ?? {};
    final double currentTotalRating = (data['totalRating'] ?? 0.0).toDouble();
    final int currentReviewCount = (data['reviewCount'] ?? 0);

    final newTotalRating = currentTotalRating + review.rating;
    final newReviewCount = currentReviewCount + 1;

    batch.set(reviewRef, {
      ...review.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    batch.update(educatorRef, {
      'totalRating': newTotalRating,
      'reviewCount': newReviewCount,
      'averageRating': newTotalRating / newReviewCount,
    });

    await batch.commit();
  }

  Stream<List<Review>> streamReviews(String educatorUid) {
    return _firestore
        .collection('users')
        .doc(educatorUid)
        .collection('reviews')
        .snapshots()
        .map((snapshot) {
      final reviews = snapshot.docs.map((doc) => Review.fromDoc(doc)).toList();
      // Client-side sorting to handle documents with missing createdAt fields gracefully
      // and to avoid the need for composite indexes.
      reviews.sort((a, b) {
        // First sort by rating (highest first)
        int ratingCompare = b.rating.compareTo(a.rating);
        if (ratingCompare != 0) return ratingCompare;

        // Then sort by date (newest first)
        if (a.createdAt == null && b.createdAt == null) return 0;
        if (a.createdAt == null) return 1; // Put nulls at the end
        if (b.createdAt == null) return -1;
        return b.createdAt!.compareTo(a.createdAt!);
      });
      return reviews;
    });
  }

  Future<void> clearAllLessons() async {
    final snapshot = await _lessons.get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      await _deleteFileFromUrl(data['attachmentUrl']);
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> clearAllQuizzes() async {
    final snapshot = await _quizzes.get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      await _deleteFileFromUrl(data['attachmentUrl']);
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Marks already-approved lessons created by actual ADMIN/SUPERADMIN accounts
  /// under the Grammatica Official folder without auto-approving pending lessons.
  Future<int> migrateAdminLessonsToGrammaticaOfficial() async {
    try {
      // 1. Find actual admin/superadmin UIDs from users collection
      final usersSnap = await _firestore.collection('users').get();
      final adminUids = <String>{};

      for (final doc in usersSnap.docs) {
        final data = doc.data();
        final role = (data['role'] ?? '').toString().toUpperCase();

        if (role == 'ADMIN' || role == 'SUPERADMIN') {
          adminUids.add(doc.id);
        }
      }

      // 2. Fetch all lessons and check which approved admin lessons need tagging
      final lessonsSnap = await _lessons.get();
      final batch = _firestore.batch();
      int migratedCount = 0;

      for (final doc in lessonsSnap.docs) {
        final data = doc.data();
        final creatorUid = (data['createdByUid'] ?? '').toString();
        final isGrammatica = data['isGrammaticaLesson'] == true;
        final status = (data['validationStatus'] ?? 'approved').toString();

        if (adminUids.contains(creatorUid) &&
            !isGrammatica &&
            status == 'approved') {
          batch.update(doc.reference, {
            'isGrammaticaLesson': true,
          });
          migratedCount++;
        }
      }

      if (migratedCount > 0) {
        await batch.commit();
        debugPrint('Successfully migrated $migratedCount admin lesson(s) to Grammatica Official.');
      }
      return migratedCount;
    } catch (e) {
      debugPrint('Error migrating admin lessons: $e');
      return 0;
    }
  }
}