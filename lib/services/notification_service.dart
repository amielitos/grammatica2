import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');

  Stream<List<NotificationModel>> streamNotifications(
    String uid, {
    bool archived = false,
  }) {
    // Removed orderBy to fix potential missing index issues in Firestore
    return _notifications
        .where('uid', isEqualTo: uid)
        .where('isArchived', isEqualTo: archived)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => NotificationModel.fromDoc(doc))
              .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)), // Manual sort
        );
  }

  Future<void> sendNotification({
    required String uid,
    required String title,
    required String message,
    required NotificationType type,
    String? rejectionReason,
    String? rejectionDescription,
  }) async {
    try {
      final notification = NotificationModel(
        id: '',
        uid: uid,
        title: title,
        message: message,
        type: type,
        createdAt: DateTime.now(),
        rejectionReason: rejectionReason,
        rejectionDescription: rejectionDescription,
      );
      await _notifications.add(notification.toMap());
    } catch (e) {
      debugPrint('NOTIFICATION ERROR: $e');
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await _notifications.doc(id).update({'isRead': true});
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  Future<void> markAllAsRead(String uid) async {
    final unread = await _notifications
        .where('uid', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .get();
    
    final batch = _firestore.batch();
    for (var doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> archiveNotification(String id, {bool archive = true}) async {
    await _notifications.doc(id).update({'isArchived': archive});
  }

  Future<void> deleteNotification(String id) async {
    await _notifications.doc(id).delete();
  }

  Future<void> sendDailyLessonReminders(String educatorUid) async {
    final now = DateTime.now();
    if (now.weekday < 1 || now.weekday > 5) return;

    try {
      final today = DateTime(now.year, now.month, now.day);
      // Simplify query to avoid index errors, filter in Dart instead
      final snapshots = await _notifications
          .where('uid', isEqualTo: educatorUid)
          .get();

      final existingReminders = snapshots.docs.where((doc) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        return data['type'] == 'general' &&
               data['title'] == 'Mandatory Lesson Upload Reminder' &&
               createdAt != null &&
               createdAt.isAfter(today);
      });

      if (existingReminders.isNotEmpty) return;

      final subscribers = await _firestore
          .collection('users')
          .doc(educatorUid)
          .collection('subscribers')
          .where('tier', isEqualTo: 'Premium')
          .get();

      if (subscribers.docs.isNotEmpty) {
        await sendNotification(
          uid: educatorUid,
          title: 'Mandatory Lesson Upload Reminder',
          message:
              'You have active premium learners. Please remember to upload a lesson for them today.',
          type: NotificationType.general,
        );
      }
    } catch (e) {
      debugPrint('Failed to send daily lesson reminder: $e');
    }
  }

  Future<void> sendWelcomeNotification(String uid) async {
    await sendNotification(
      uid: uid,
      title: 'Welcome to Grammatica!',
      message:
          'We are excited to have you here! Explore lessons, practice your spelling, and improve your English skills with us.',
      type: NotificationType.welcome,
    );
  }

  Future<void> sendRejectionNotification({
    required String uid,
    required String reason,
    required String description,
  }) async {
    await sendNotification(
      uid: uid,
      title: 'Application Update',
      message: 'Your educator application has been reviewed.',
      type: NotificationType.appRejected,
      rejectionReason: reason,
      rejectionDescription: description,
    );
  }

  Future<void> sendApprovalNotification(String uid) async {
    await sendNotification(
      uid: uid,
      title: 'Application Approved!',
      message:
          'Congratulations! Your application to become an educator has been approved. You can now start creating lessons and quizzes.',
      type: NotificationType.appApproved,
    );
  }

  Future<void> sendContentValidationNotification({
    required String uid,
    required String title,
    required bool approved,
    String? reason,
  }) async {
    await sendNotification(
      uid: uid,
      title: approved ? 'Content Approved!' : 'Content Rejected',
      message: approved 
          ? 'Your content "$title" has been approved and is now live!'
          : 'Your content "$title" was not approved. ${reason ?? ""}',
      type: approved ? NotificationType.general : NotificationType.appRejected,
    );
  }

  Future<void> sendAchievementNotification({
    required String uid,
    required String title,
    required String message,
  }) async {
    await sendNotification(
      uid: uid,
      title: title,
      message: message,
      type: NotificationType.achievement,
    );
  }

  Future<void> sendProfileReminderNotification(String uid) async {
    await sendNotification(
      uid: uid,
      title: 'Complete Your Profile',
      message:
          'Please finish setting up your profile by adding your phone number and birthdate to get the most out of Grammatica.',
      type: NotificationType.profileReminder,
    );
  }

  Future<void> sendSubscriptionNotification({
    required String learnerUid,
    required String educatorUid,
    required String learnerName,
    required String educatorName,
    required String tier,
  }) async {
    await sendNotification(
      uid: learnerUid,
      title: 'Subscription Successful!',
      message:
          'You have successfully subscribed to $educatorName ($tier tier).',
      type: NotificationType.subscription,
    );

    await sendNotification(
      uid: educatorUid,
      title: 'New Subscriber!',
      message: '$learnerName has subscribed to you as a $tier.',
      type: NotificationType.subscription,
    );
  }
}
