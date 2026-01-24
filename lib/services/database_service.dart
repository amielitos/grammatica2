import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'role_service.dart';

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
  final String? attachmentUrl;
  final String? attachmentName;
  final String validationStatus; // 'approved', 'awaiting_approval'
  final bool isVisible;
  final List<String> visibleTo;
  final bool isMembersOnly;

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

  Future<String> createLesson({
    required String title,
    required String prompt,
    required String answer,
    String? attachmentUrl,
    String? attachmentName,
    bool isVisible = true,
    List<String> visibleTo = const [],
    bool isMembersOnly = false,
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

  Stream<List<Lesson>> streamEducatorLessons(String educatorUid) {
    return _lessons
        .where('createdByUid', isEqualTo: educatorUid)
        .where('isVisible', isEqualTo: true)
        .where('validationStatus', isEqualTo: 'approved')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Lesson.fromDoc).toList());
  }

  Stream<List<Quiz>> streamEducatorQuizzes(String educatorUid) {
    return _quizzes
        .where('createdByUid', isEqualTo: educatorUid)
        .where('isVisible', isEqualTo: true)
        .where('validationStatus', isEqualTo: 'approved')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Quiz.fromDoc).toList());
  }

  Future<void> updateSubscriptionFee(String uid, int amount) async {
    await _firestore.collection('users').doc(uid).update({
      'subscription_fee': amount,
    });
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
}
