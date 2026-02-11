import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'role_service.dart';
import '../models/spelling_word.dart';

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
  final String videoUrl;
  final String syllabusUrl;
  final String status; // 'pending', 'approved', 'rejected'
  final Timestamp? appliedAt;

  EducatorApplication({
    required this.id,
    required this.applicantUid,
    required this.applicantEmail,
    required this.videoUrl,
    required this.syllabusUrl,
    required this.status,
    required this.appliedAt,
  });

  factory EducatorApplication.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return EducatorApplication(
      id: doc.id,
      applicantUid: data['applicantUid'] ?? '',
      applicantEmail: data['applicantEmail'] ?? '',
      videoUrl: data['videoUrl'] ?? '',
      syllabusUrl: data['syllabusUrl'] ?? '',
      status: data['status'] ?? 'pending',
      appliedAt: data['appliedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'applicantUid': applicantUid,
      'applicantEmail': applicantEmail,
      'videoUrl': videoUrl,
      'syllabusUrl': syllabusUrl,
      'status': status,
      'appliedAt': appliedAt ?? FieldValue.serverTimestamp(),
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
  final String? attachmentUrl;
  final String? attachmentName;
  final String validationStatus; // 'approved', 'awaiting_approval'
  final bool isVisible;
  final List<String> visibleTo;
  final bool isMembersOnly;
  final bool isGrammaticaLesson;

  Lesson({
    required this.id,
    required this.title,
    required this.prompt,
    required this.answer,
    this.createdAt,
    this.createdByUid,
    this.createdByEmail,
    this.attachmentUrl,
    this.attachmentName,
    this.validationStatus = 'approved',
    this.isVisible = true,
    this.visibleTo = const [],
    this.isMembersOnly = false,
    this.isGrammaticaLesson = false,
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
      attachmentUrl: (data['attachmentUrl'] ?? '').toString(),
      attachmentName: (data['attachmentName'] ?? '').toString(),
      validationStatus: (data['validationStatus'] ?? 'approved').toString(),
      isVisible: data['isVisible'] ?? true,
      visibleTo: List<String>.from(data['visibleTo'] ?? []),
      isMembersOnly: data['isMembersOnly'] ?? false,
      isGrammaticaLesson: data['isGrammaticaLesson'] ?? false,
    );
  }
}

class QuizQuestion {
  final String question;
  final String answer;
  final String type; // 'text', 'multiple_choice'
  final List<String>? options;

  QuizQuestion({
    required this.question,
    required this.answer,
    this.type = 'text',
    this.options,
  });

  factory QuizQuestion.fromMap(Map<String, dynamic> map) {
    return QuizQuestion(
      question: (map['question'] ?? '').toString(),
      answer: (map['answer'] ?? '').toString(),
      type: (map['type'] ?? 'text').toString(),
      options: map['options'] != null
          ? List<String>.from(map['options'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'answer': answer,
      'type': type,
      'options': options,
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
  final String validationStatus; // 'approved', 'awaiting_approval'
  final bool isVisible;
  final List<String> visibleTo;
  final bool isMembersOnly;
  final bool isGrammaticaQuiz;
  final bool isAssessment;

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
  });

  factory Quiz.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final questionsData = (d['questions'] as List?) ?? [];
    return Quiz(
      id: doc.id,
      title: (d['title'] ?? '').toString(),
      description: (d['description'] ?? '').toString(),
      questions: questionsData
          .map((q) => QuizQuestion.fromMap(Map<String, dynamic>.from(q)))
          .toList(),
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
    );
  }
}

class DatabaseService {
  DatabaseService._();
  static final instance = DatabaseService._();

  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  Future<void> _deleteFileFromUrl(String? url) async {
    if (url == null || url.isEmpty) return;
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
  CollectionReference<Map<String, dynamic>> _userProgress(String uid) =>
      _firestore.collection('users').doc(uid).collection('progress');
  CollectionReference<Map<String, dynamic>> _userQuizProgress(String uid) =>
      _firestore.collection('users').doc(uid).collection('quizProgress');
  CollectionReference<Map<String, dynamic>> get _spellingWords =>
      _firestore.collection('spelling_words');

  CollectionReference<Map<String, dynamic>> get _educatorApplications =>
      _firestore.collection('educator_applications');

  Future<void> updateUserField(String uid, String field, dynamic value) async {
    await _firestore.collection('users').doc(uid).update({field: value});
  }

  Future<void> submitEducatorApplication({
    required String uid,
    required String email,
    required String videoUrl,
    required String syllabusUrl,
  }) async {
    await _educatorApplications.add({
      'applicantUid': uid,
      'applicantEmail': email,
      'videoUrl': videoUrl,
      'syllabusUrl': syllabusUrl,
      'status': 'pending',
      'appliedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<EducatorApplication>> streamEducatorApplications() {
    return _educatorApplications
        .where('status', isEqualTo: 'pending')
        .orderBy('appliedAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(EducatorApplication.fromDoc).toList(),
        );
  }

  Stream<EducatorApplication?> streamUserApplication(String uid) {
    return _educatorApplications
        .where('applicantUid', isEqualTo: uid)
        .orderBy('appliedAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return EducatorApplication.fromDoc(snapshot.docs.first);
        });
  }

  Future<void> updateApplicationStatus(String id, String status) async {
    await _educatorApplications.doc(id).update({'status': status});
  }

  Future<void> rejectEducatorApplication(
    EducatorApplication app, {
    String? reason,
    String? description,
  }) async {
    // Delete files from storage
    if (app.videoUrl.isNotEmpty) {
      await _deleteFileFromUrl(app.videoUrl);
    }
    if (app.syllabusUrl.isNotEmpty) {
      await _deleteFileFromUrl(app.syllabusUrl);
    }
    // Update status and clear URLs in Firestore
    await _educatorApplications.doc(app.id).update({
      'status': 'rejected',
      'videoUrl': '', // Clear URLs to indicate files are gone
      'syllabusUrl': '',
      'rejectionReason': reason,
      'rejectionDescription': description,
    });
  }

  Future<String> uploadApplicationFile({
    required String uid,
    required Uint8List fileBytes,
    required String fileName,
    required String contentType,
  }) async {
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('educator_applications')
          .child(uid)
          .child('${DateTime.now().millisecondsSinceEpoch}_$fileName');

      final uploadTask = storageRef.putData(
        fileBytes,
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
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    // Determine initial status based on role
    String status = 'approved';
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final role = doc.data()?['role'];
      if (role == 'EDUCATOR') {
        status = 'awaiting_approval';
      }
    }

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
      'isGrammaticaLesson': isGrammaticaLesson,
    });
    return doc.id;
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
  }) async {
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (prompt != null) data['prompt'] = prompt;
    if (answer != null) data['answer'] = answer;
    if (attachmentUrl != null) data['attachmentUrl'] = attachmentUrl;
    if (attachmentName != null) data['attachmentName'] = attachmentName;
    if (isVisible != null) data['isVisible'] = isVisible;
    if (visibleTo != null) data['visibleTo'] = visibleTo;
    if (isMembersOnly != null) data['isMembersOnly'] = isMembersOnly;
    if (isGrammaticaLesson != null) {
      data['isGrammaticaLesson'] = isGrammaticaLesson;
    }
    if (data.isNotEmpty) {
      await _lessons.doc(id).update(data);
    }
  }

  Future<void> deleteLesson(String id) async {
    final doc = await _lessons.doc(id).get();
    if (doc.exists) {
      final data = doc.data();
      await _deleteFileFromUrl(data?['attachmentUrl']);
    }
    await _lessons.doc(id).delete();
  }

  Future<Lesson?> getLessonById(String id) async {
    final doc = await _lessons.doc(id).get();
    if (!doc.exists) return null;
    return Lesson.fromDoc(doc);
  }

  Future<List<Lesson>> fetchLessons() async {
    final snapshot = await _lessons
        .orderBy('createdAt', descending: false)
        .get();
    return snapshot.docs.map(Lesson.fromDoc).toList();
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
      final lessons = snapshot.docs.map(Lesson.fromDoc).toList();

      // Admins and Superadmins see all items
      if (userRole == UserRole.admin || userRole == UserRole.superadmin) {
        return lessons;
      }

      // Educators see their own content + public content from admins
      if (userRole == UserRole.educator && userId != null) {
        return lessons.where((l) {
          // Own content
          if (l.createdByUid == userId) return true;
          // Approved content only
          if (l.validationStatus == 'awaiting_approval') return false;

          return (l.isVisible || (l.visibleTo.contains(userId)));
        }).toList();
      }

      if (approvedOnly) {
        return lessons.where((l) {
          // Other users must respect isVisible flag or be in visibleTo list
          return (l.validationStatus != 'awaiting_approval') &&
              (l.isVisible || (userId != null && l.visibleTo.contains(userId)));
        }).toList();
      }
      return lessons;
    });
  }

  Future<bool> isSubscribed(String educatorUid, String userId) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('subscriptions')
        .doc(educatorUid)
        .get();
    return doc.exists && doc.data()?['status'] == 'active';
  }

  Stream<List<Lesson>> streamAwaitingApprovalLessons() {
    return _lessons
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(Lesson.fromDoc)
              .where((l) => l.validationStatus == 'awaiting_approval')
              .toList(),
        );
  }

  Stream<Map<String, Map<String, dynamic>>> progressStream(User user) {
    return _userProgress(user.uid).snapshots().map((q) {
      final map = <String, Map<String, dynamic>>{};
      for (final d in q.docs) {
        final data = d.data();
        map[d.id] = {
          'completed': data['completed'] == true,
          'completedAt': data['completedAt'],
        };
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
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    // Determine initial status based on role
    String status = 'approved';
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final role = doc.data()?['role'];
      if (role == 'EDUCATOR') {
        status = 'awaiting_approval';
      }
    }

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
      'isGrammaticaQuiz': isGrammaticaQuiz,
      'isAssessment': isAssessment,
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
    if (data.isNotEmpty) {
      await _quizzes.doc(id).update(data);
    }
  }

  Future<void> deleteQuiz(String id) async {
    final doc = await _quizzes.doc(id).get();
    if (doc.exists) {
      final data = doc.data();
      await _deleteFileFromUrl(data?['attachmentUrl']);
    }
    await _quizzes.doc(id).delete();
  }

  Future<List<Quiz>> fetchQuizzes() async {
    final snap = await _quizzes.orderBy('createdAt', descending: false).get();
    return snap.docs.map(Quiz.fromDoc).toList();
  }

  Stream<List<Quiz>> streamQuizzes({
    bool approvedOnly = true,
    UserRole? userRole,
    String? userId,
  }) {
    // To avoid composite index requirements and support legacy content,
    // we filter out awaiting_approval docs in Dart.
    return _quizzes.orderBy('createdAt', descending: false).snapshots().map((
      snapshot,
    ) {
      final quizzes = snapshot.docs.map(Quiz.fromDoc).toList();

      // Admins and Superadmins see all items
      if (userRole == UserRole.admin || userRole == UserRole.superadmin) {
        return quizzes;
      }

      // Educators see their own content + public content from admins
      if (userRole == UserRole.educator && userId != null) {
        return quizzes.where((q) {
          // Own content
          if (q.createdByUid == userId) return true;
          // Approved content only
          if (q.validationStatus == 'awaiting_approval') return false;

          return (q.isVisible || (q.visibleTo.contains(userId)));
        }).toList();
      }

      if (approvedOnly) {
        return quizzes.where((q) {
          // Other users must respect isVisible flag or be in visibleTo list
          return (q.validationStatus != 'awaiting_approval') &&
              (q.isVisible || (userId != null && q.visibleTo.contains(userId)));
        }).toList();
      }
      return quizzes;
    });
  }

  Stream<List<Quiz>> streamAwaitingApprovalQuizzes() {
    return _quizzes
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(Quiz.fromDoc)
              .where((q) => q.validationStatus == 'awaiting_approval')
              .toList(),
        );
  }

  Future<void> updateContentStatus(
    String collection,
    String id,
    String status,
  ) async {
    await _firestore.collection(collection).doc(id).update({
      'validationStatus': status,
    });
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

  Future<void> markQuizCompleted({
    required User user,
    required String quizId,
    required bool isCorrect,
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
      'isCorrect': isCorrect,
    };

    if (isCorrect) {
      updateData['completed'] = true;
      updateData['completedAt'] = FieldValue.serverTimestamp();
    }

    await docRef.set(updateData, SetOptions(merge: true));
  }

  Stream<Map<String, Map<String, dynamic>>> quizProgressStream(User user) {
    return _userQuizProgress(user.uid).snapshots().map((q) {
      final map = <String, Map<String, dynamic>>{};
      for (final d in q.docs) {
        final data = d.data();
        map[d.id] = {
          'completed': data['completed'] == true,
          'isCorrect': data['isCorrect'] == true,
          'attemptsUsed': data['attemptsUsed'] ?? 0,
          'completedAt': data['completedAt'],
          'score': data['score'],
          'totalQuestions': data['totalQuestions'],
        };
      }
      return map;
    });
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
          final lessons = snapshot.docs.map(Lesson.fromDoc).toList();
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
          final quizzes = snapshot.docs.map(Quiz.fromDoc).toList();
          if (publicOnly) {
            return quizzes.where((q) => !q.isMembersOnly).toList();
          }
          return quizzes;
        });
  }

  Future<void> updateSubscriptionFee(String uid, int amount) async {
    await _firestore.collection('users').doc(uid).update({
      'subscription_fee': amount,
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

  Future<void> subscribeToEducator(String educatorUid) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final batch = _firestore.batch();

    // Educator's view: list of active subscribers
    batch.set(
      _firestore
          .collection('users')
          .doc(educatorUid)
          .collection('subscribers')
          .doc(user.uid),
      {'subscribedAt': FieldValue.serverTimestamp()},
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
        'billingCycle': 'monthly',
        'subscribedAt': FieldValue.serverTimestamp(),
        'cancelledAt': null,
      },
      SetOptions(merge: true),
    );

    await batch.commit();
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
        .map((doc) => doc.exists && doc.data()?['status'] == 'active');
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
            final eduUid = data['educatorUid'] as String;
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
        .asyncMap((snapshot) async {
          final List<Map<String, dynamic>> subscribers = [];
          for (final doc in snapshot.docs) {
            final userDoc = await _firestore
                .collection('users')
                .doc(doc.id)
                .get();
            if (userDoc.exists) {
              subscribers.add({'uid': doc.id, ...userDoc.data()!});
            }
          }
          return subscribers;
        });
  }

  Future<void> deleteUserAccount(String uid) async {
    try {
      // 1. Delete all user content (Lessons)
      final lessonSnap = await _lessons
          .where('createdByUid', isEqualTo: uid)
          .get();
      for (final doc in lessonSnap.docs) {
        await deleteLesson(doc.id);
      }

      // 2. Delete all user content (Quizzes)
      final quizSnap = await _quizzes
          .where('createdByUid', isEqualTo: uid)
          .get();
      for (final doc in quizSnap.docs) {
        await deleteQuiz(doc.id);
      }

      // 3. Delete all user images
      final imageSnap = await _images.where('userId', isEqualTo: uid).get();
      for (final doc in imageSnap.docs) {
        await deleteImage(doc.id, doc.data()['imageUrl'] ?? '');
      }

      // 4. Delete educator applications
      final appSnap = await _educatorApplications
          .where('applicantUid', isEqualTo: uid)
          .get();
      for (final doc in appSnap.docs) {
        final data = doc.data();
        await _deleteFileFromUrl(data['videoUrl']);
        await _deleteFileFromUrl(data['syllabusUrl']);
        await doc.reference.delete();
      }

      // 5. Delete specific collections
      // Progress
      final progressSnap = await _userProgress(uid).get();
      for (final doc in progressSnap.docs) {
        await doc.reference.delete();
      }

      // Quiz Progress
      final qProgressSnap = await _userQuizProgress(uid).get();
      for (final doc in qProgressSnap.docs) {
        await doc.reference.delete();
      }

      // Subscriptions (Learner side)
      final subsSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('subscriptions')
          .get();
      for (final doc in subsSnap.docs) {
        // Also remove learner from educator's subscriber list
        final educatorUid = doc.id;
        await _firestore
            .collection('users')
            .doc(educatorUid)
            .collection('subscribers')
            .doc(uid)
            .delete();
        await doc.reference.delete();
      }

      // Subscribers (Educator side)
      final followersSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('subscribers')
          .get();
      for (final doc in followersSnap.docs) {
        // Also remove educator from learner's subscription list
        final learnerUid = doc.id;
        await _firestore
            .collection('users')
            .doc(learnerUid)
            .collection('subscriptions')
            .doc(uid)
            .delete();
        await doc.reference.delete();
      }

      // 6. Delete user profile photo if exists
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final photoUrl = userDoc.data()?['photoUrl'];
        if (photoUrl != null && photoUrl.toString().isNotEmpty) {
          await _deleteFileFromUrl(photoUrl);
        }
      }

      // 7. Finally delete user doc
      await _firestore.collection('users').doc(uid).delete();
    } catch (e) {
      throw Exception('Failed to delete user account: $e');
    }
  }
}
