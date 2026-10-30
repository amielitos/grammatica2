import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'email_sender_service.dart';

/// Client-side service for managing Grammatica user feedback.
///
/// Feedback entries are stored directly in the Firestore `feedbacks` collection
/// and dispatches notifications in the background without blocking user interactions.
class FeedbackService {
  static final FeedbackService instance = FeedbackService._internal();
  FeedbackService._internal();

  static const String supportEmail = 'grammatica.support@gmail.com';

  /// Dynamically retrieves Resend API key strictly from environment (.env or --dart-define).
  /// Never hardcoded in source code.
  static String get resendApiKey {
    try {
      if (dotenv.isInitialized) {
        final key = dotenv.env['RESEND_API_KEY'];
        if (key != null && key.trim().isNotEmpty) return key.trim();
      }
    } catch (_) {}
    return const String.fromEnvironment('RESEND_API_KEY').trim();
  }

  /// Sender address used for outbound Resend emails.
  static String get resendFromEmail {
    try {
      if (dotenv.isInitialized) {
        final from = dotenv.env['RESEND_FROM_EMAIL'];
        if (from != null && from.trim().isNotEmpty) return from.trim();
      }
    } catch (_) {}
    const fromEnv = String.fromEnvironment('RESEND_FROM_EMAIL');
    if (fromEnv.isNotEmpty) return fromEnv;
    return 'onboarding@resend.dev';
  }

  /// Fallback testing recipient dynamically loaded from environment.
  static String get ownerTestingEmail {
    try {
      if (dotenv.isInitialized) {
        final email = dotenv.env['RESEND_OWNER_EMAIL'] ?? dotenv.env['SMTP_EMAIL'];
        if (email != null && email.trim().isNotEmpty) return email.trim();
      }
    } catch (_) {}
    return const String.fromEnvironment('RESEND_OWNER_EMAIL').trim();
  }

  CollectionReference<Map<String, dynamic>> get _feedbacksCollection =>
      FirebaseFirestore.instance.collection('feedbacks');

  /// Saves the feedback document to Firestore immediately, then dispatches
  /// the background notification without delaying the user.
  Future<void> submitFeedback({
    required String userId,
    required String userEmail,
    required String userName,
    required String userRole,
    required String category,
    required String subject,
    required String message,
    int rating = 5,
  }) async {
    final sanitizedSubject = subject.trim();
    final sanitizedMessage = message.trim();
    final safeEmail = userEmail.trim().isNotEmpty
        ? userEmail.trim()
        : 'Anonymous Learner';
    final safeName = userName.trim().isNotEmpty
        ? userName.trim()
        : 'Grammatica User';

    if (sanitizedSubject.isEmpty) {
      throw ArgumentError('Subject cannot be empty');
    }
    if (sanitizedMessage.isEmpty) {
      throw ArgumentError('Message cannot be empty');
    }

    final feedbackDocRef = _feedbacksCollection.doc();
    final clampedRating = rating.clamp(1, 5);

    // 1. Instant Firestore persistence
    await feedbackDocRef.set({
      'id': feedbackDocRef.id,
      'userId': userId,
      'userEmail': safeEmail,
      'userName': safeName,
      'userRole': userRole.toUpperCase(),
      'category': category,
      'subject': sanitizedSubject,
      'message': sanitizedMessage,
      'rating': clampedRating,
      'targetEmail': supportEmail,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'PENDING',
      'deliveryStatus': 'stored',
    });

    // 2. Fire background notification asynchronously (zero UI delay)
    unawaited(
      _dispatchBackgroundEmail(
        feedbackId: feedbackDocRef.id,
        userName: safeName,
        userEmail: safeEmail,
        userRole: userRole,
        category: category,
        subject: sanitizedSubject,
        message: sanitizedMessage,
        rating: clampedRating,
      ),
    );
  }

  /// Sends the formatted email notification in the background without blocking the user.
  Future<void> _dispatchBackgroundEmail({
    required String feedbackId,
    required String userName,
    required String userEmail,
    required String userRole,
    required String category,
    required String subject,
    required String message,
    required int rating,
  }) async {
    try {
      final emailSubject = '[Grammatica Feedback - $category] $subject';
      final emailHtml = _buildFeedbackHtml(
        feedbackId: feedbackId,
        userName: userName,
        userEmail: userEmail,
        userRole: userRole,
        category: category,
        subject: subject,
        message: message,
        rating: rating,
      );

      bool delivered = false;

      // 1. Attempt direct Resend REST API using dynamically resolved environment credentials
      final key = resendApiKey;
      if (key.isNotEmpty) {
        delivered = await _sendViaResend(
          apiKey: key,
          fromEmail: resendFromEmail,
          toEmail: supportEmail,
          fallbackEmail: ownerTestingEmail,
          subject: emailSubject,
          html: emailHtml,
        );
      }

      // 2. Fallback to EmailSenderService if Resend wasn't configured or failed
      if (!delivered) {
        delivered = await EmailSenderService.sendEmail(
          toEmail: supportEmail,
          subject: emailSubject,
          body: emailHtml,
        );
      }

      if (delivered) {
        await _feedbacksCollection.doc(feedbackId).update({
          'deliveryStatus': 'delivered',
          'deliveredAt': FieldValue.serverTimestamp(),
        }).catchError((_) {});
      }
    } catch (e) {
      debugPrint('Background feedback email delivery notice: $e');
    }
  }

  /// Sends email directly via Resend REST API using dynamic environment credentials.
  /// If domain verification restricts sending to third-party emails on the free plan,
  /// delivers to the fallback owner address if configured in environment.
  Future<bool> _sendViaResend({
    required String apiKey,
    required String fromEmail,
    required String toEmail,
    required String fallbackEmail,
    required String subject,
    required String html,
  }) async {
    try {
      final uri = Uri.parse('https://api.resend.com/emails');

      // Attempt primary support email
      var response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'User-Agent': 'GrammaticaApp/1.0',
        },
        body: jsonEncode({
          'from': fromEmail,
          'to': [toEmail],
          'subject': subject,
          'html': html,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ Resend delivered email to $toEmail');
        return true;
      }

      // If restricted by Resend unverified domain policy (HTTP 403), fallback to verified owner if configured
      if (response.statusCode == 403 &&
          fallbackEmail.isNotEmpty &&
          fallbackEmail != toEmail) {
        debugPrint(
          '⚠️ Resend unverified domain restriction. Routing to verified account owner from env: $fallbackEmail',
        );
        response = await http.post(
          uri,
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
            'User-Agent': 'GrammaticaApp/1.0',
          },
          body: jsonEncode({
            'from': fromEmail,
            'to': [fallbackEmail],
            'subject': '$subject (Target: $toEmail)',
            'html': html,
          }),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          debugPrint('✅ Resend delivered fallback email to $fallbackEmail');
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Resend direct dispatch error: $e');
      return false;
    }
  }

  /// Streams real-time feedback submissions for the Super Admin Dashboard.
  Stream<List<Map<String, dynamic>>> streamFeedbacks() {
    return _feedbacksCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Updates the resolution status of a feedback document ('PENDING', 'REVIEWED', 'RESOLVED').
  Future<void> updateFeedbackStatus(String feedbackId, String status) async {
    await _feedbacksCollection.doc(feedbackId).update({
      'status': status.toUpperCase(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes a feedback document.
  Future<void> deleteFeedback(String feedbackId) async {
    await _feedbacksCollection.doc(feedbackId).delete();
  }

  /// Formats branded HTML content for the feedback email.
  static String _buildFeedbackHtml({
    required String feedbackId,
    required String userName,
    required String userEmail,
    required String userRole,
    required String category,
    required String subject,
    required String message,
    required int rating,
  }) {
    final stars = '★' * rating + '☆' * (5 - rating);

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>New Feedback Received</title>
</head>
<body style="margin: 0; padding: 0; background-color: #F8FAFC; font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, Roboto, sans-serif;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background-color: #F8FAFC; padding: 32px 16px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="max-width: 600px; background-color: #FFFFFF; border-radius: 20px; overflow: hidden; box-shadow: 0 10px 30px rgba(0,0,0,0.06); border: 1px solid #E2E8F0;">
          <tr>
            <td style="background: linear-gradient(135deg, #0F172A 0%, #1E293B 100%); padding: 24px 32px; text-align: left; border-bottom: 4px solid #81B655;">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
                <tr>
                  <td>
                    <span style="font-size: 24px; font-weight: 800; color: #FFFFFF;">Grammatica</span>
                    <span style="display: block; font-size: 11px; font-weight: 700; color: #81B655; letter-spacing: 1.5px; text-transform: uppercase; margin-top: 4px;">User Feedback &middot; $category</span>
                  </td>
                  <td align="right">
                    <span style="display: inline-block; background-color: rgba(129, 182, 85, 0.2); color: #81B655; font-size: 11px; font-weight: 800; padding: 6px 12px; border-radius: 12px; text-transform: uppercase; border: 1px solid rgba(129, 182, 85, 0.4);">$category</span>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td style="padding: 28px 32px;">
              <h2 style="margin: 0 0 14px; font-size: 20px; color: #0F172A; font-weight: 700;">$subject</h2>
              <div style="background-color: #FEF3C7; border: 1px solid #FCD34D; border-radius: 12px; padding: 8px 14px; margin-bottom: 20px; display: inline-block;">
                <span style="color: #B45309; font-weight: 800; font-size: 13px;">User Rating:</span>
                <span style="color: #D97706; font-size: 15px; margin-left: 6px; letter-spacing: 2px;">$stars</span>
                <span style="color: #78350F; font-size: 12px; font-weight: 600; margin-left: 4px;">($rating/5)</span>
              </div>
              <div style="background-color: #F8FAFC; border-radius: 12px; padding: 18px; border: 1px solid #E2E8F0; margin-bottom: 24px;">
                <span style="display: block; font-size: 11px; font-weight: 700; color: #64748B; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 8px;">Feedback Message</span>
                <p style="margin: 0; font-size: 14.5px; line-height: 1.6; color: #1E293B; white-space: pre-wrap;">$message</p>
              </div>
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background-color: #F1F5F9; border-radius: 12px; padding: 14px; border: 1px solid #E2E8F0;">
                <tr>
                  <td style="padding: 6px 10px; font-size: 12px; color: #64748B; font-weight: 600;">Submitted By:</td>
                  <td style="padding: 6px 10px; font-size: 12.5px; color: #0F172A; font-weight: 700;">$userName</td>
                </tr>
                <tr>
                  <td style="padding: 6px 10px; font-size: 12px; color: #64748B; font-weight: 600;">Email:</td>
                  <td style="padding: 6px 10px; font-size: 12.5px; color: #0F172A; font-weight: 700;"><a href="mailto:$userEmail" style="color: #2563EB; text-decoration: none;">$userEmail</a></td>
                </tr>
                <tr>
                  <td style="padding: 6px 10px; font-size: 12px; color: #64748B; font-weight: 600;">Platform Role:</td>
                  <td style="padding: 6px 10px; font-size: 12.5px; color: #0F172A; font-weight: 700;">$userRole</td>
                </tr>
                <tr>
                  <td style="padding: 6px 10px; font-size: 12px; color: #64748B; font-weight: 600;">Feedback ID:</td>
                  <td style="padding: 6px 10px; font-size: 11.5px; color: #64748B; font-family: monospace;">$feedbackId</td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td style="background-color: #F8FAFC; border-top: 1px solid #E2E8F0; padding: 18px; text-align: center;">
              <p style="margin: 0; font-size: 11.5px; color: #94A3B8;">Sent automatically to <strong>$supportEmail</strong> via Grammatica Feedback Service.</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
''';
  }
}
