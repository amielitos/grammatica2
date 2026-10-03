import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../config/ai_config.dart';

class EmailSenderService {
  static String get _smtpEmail {
    try {
      if (dotenv.isInitialized) {
        final email = dotenv.env['SMTP_EMAIL'];
        if (email != null && email.isNotEmpty) return email;
      }
    } catch (_) {}
    const fromEnv = String.fromEnvironment('SMTP_EMAIL');
    if (fromEnv.isNotEmpty) return fromEnv;
    return 'otosuave@gmail.com';
  }

  static String get _smtpPassword {
    try {
      if (dotenv.isInitialized) {
        final pass = dotenv.env['SMTP_PASSWORD'];
        if (pass != null && pass.isNotEmpty) return pass;
      }
    } catch (_) {}
    const fromEnv = String.fromEnvironment('SMTP_PASSWORD');
    if (fromEnv.isNotEmpty) return fromEnv;
    return 'ughc ndaj gxpf vkxe';
  }

  /// Generates a unified, ultra-premium HTML email layout with Grammatica branding & logo.
  static String _buildBrandedEmailTemplate({
    required String title,
    required String subtitle,
    required String badgeIcon,
    required String badgeText,
    required String recipientName,
    required String contentHtml,
    String badgeBgColor = '#F0FDF4',
    String badgeBorderColor = '#81B655',
    String badgeTextColor = '#166534',
    String headerGradientStart = '#0D2818',
    String headerGradientEnd = '#1E6B3C',
    String? ctaButtonText,
    String? ctaButtonUrl,
  }) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Grammatica</title>
</head>
<body style="margin: 0; padding: 0; background-color: #F4F7F5; font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, Roboto, Helvetica, Arial, sans-serif; -webkit-font-smoothing: antialiased;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background-color: #F4F7F5; padding: 40px 16px;">
    <tr>
      <td align="center">
        <!-- Main Email Container Card -->
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="max-width: 620px; background-color: #FFFFFF; border-radius: 24px; overflow: hidden; box-shadow: 0 20px 50px rgba(0, 0, 0, 0.07); border: 1px solid #E2E8F0;">
          
          <!-- Top Branding Header with Logo -->
          <tr>
            <td style="background: linear-gradient(135deg, $headerGradientStart 0%, #164E2B 55%, $headerGradientEnd 100%); padding: 36px 32px; text-align: center; position: relative;">
              <!-- Top Accent Bar -->
              <div style="background: linear-gradient(90deg, #81B655 0%, #A3E635 50%, #4D8B28 100%); height: 5px; width: 100%; position: absolute; top: 0; left: 0;"></div>
              
              <!-- Logo Container -->
              <table role="presentation" align="center" cellspacing="0" cellpadding="0" border="0">
                <tr>
                  <td align="center" style="vertical-align: middle;">
                    <!-- Grammatica Logo Emblem Icon -->
                    <div style="display: inline-block; background: linear-gradient(135deg, #81B655 0%, #4D8B28 100%); border-radius: 16px; padding: 12px 14px; box-shadow: 0 8px 22px rgba(129, 182, 85, 0.35); vertical-align: middle; margin-right: 14px;">
                      <svg width="34" height="34" viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg" style="display: block;">
                        <path d="M4 8C4 5.79086 5.79086 4 8 4H14V26H8C5.79086 26 4 24.2091 4 22V8Z" fill="#FFFFFF" fill-opacity="0.95"/>
                        <path d="M28 8C28 5.79086 26.2091 4 24 4H18V26H24C26.2091 26 28 24.2091 28 22V8Z" fill="#FFFFFF"/>
                        <path d="M14 8C14 6.89543 14.8954 6 16 6C17.1046 6 18 6.89543 18 8V24C18 25.1046 17.1046 26 16 26C14.8954 26 14 25.1046 14 24V8Z" fill="#A3E635"/>
                        <path d="M8 10H12M8 14H12M8 18H11" stroke="#164E2B" stroke-width="1.6" stroke-linecap="round"/>
                        <path d="M20 10H24M20 14H24M21 18H24" stroke="#164E2B" stroke-width="1.6" stroke-linecap="round"/>
                      </svg>
                    </div>
                  </td>
                  <td align="left" style="vertical-align: middle;">
                    <span style="font-size: 29px; font-weight: 900; color: #FFFFFF; letter-spacing: -0.5px; font-family: 'Segoe UI', Arial, sans-serif; display: block; line-height: 1;">Grammatica</span>
                    <span style="font-size: 11px; font-weight: 700; color: #A3E635; letter-spacing: 2.5px; text-transform: uppercase; margin-top: 5px; display: block;">Interactive Language Learning</span>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Main Card Body -->
          <tr>
            <td style="padding: 44px 40px; background-color: #FFFFFF;">
              
              <!-- Topic Badge -->
              <div style="text-align: center; margin-bottom: 28px;">
                <div style="display: inline-block; background-color: $badgeBgColor; border: 1.5px solid $badgeBorderColor; border-radius: 999px; padding: 8px 20px;">
                  <span style="font-size: 16px; vertical-align: middle; margin-right: 6px;">$badgeIcon</span>
                  <span style="font-size: 12px; font-weight: 800; color: $badgeTextColor; letter-spacing: 1.5px; text-transform: uppercase; vertical-align: middle;">$badgeText</span>
                </div>
              </div>

              <!-- Title & Subtitle -->
              <h1 style="color: #0F172A; font-size: 26px; font-weight: 800; text-align: center; margin: 0 0 10px 0; letter-spacing: -0.5px; line-height: 1.3;">$title</h1>
              <p style="color: #64748B; text-align: center; font-size: 15px; margin: 0 0 32px 0; line-height: 1.5;">$subtitle</p>

              <!-- Greeting -->
              <p style="color: #334155; font-size: 16px; line-height: 1.7; margin: 0 0 16px 0;">Hello <strong style="color: #0F172A;">$recipientName</strong>,</p>

              <!-- Custom HTML Content -->
              $contentHtml

              ${ctaButtonText != null && ctaButtonUrl != null ? '''
              <!-- Primary CTA Button -->
              <div style="text-align: center; margin: 36px 0 24px 0;">
                <a href="$ctaButtonUrl" target="_blank" style="background: linear-gradient(135deg, #81B655 0%, #5A8E2E 100%); color: #FFFFFF; font-size: 16px; font-weight: 700; text-decoration: none; padding: 16px 36px; border-radius: 14px; display: inline-block; box-shadow: 0 8px 20px rgba(129, 182, 85, 0.35); letter-spacing: 0.3px;">$ctaButtonText</a>
              </div>
              ''' : ''}

              <!-- Divider -->
              <hr style="border: none; border-top: 1px solid #F1F5F9; margin: 36px 0 24px 0;">

              <!-- Footer Note -->
              <p style="color: #94A3B8; font-size: 13px; text-align: center; margin: 0;">
                Sent with ❤️ by the <strong style="color: #81B655;">Grammatica Team</strong>
              </p>

            </td>
          </tr>

          <!-- Bottom Footer Bar -->
          <tr>
            <td style="background-color: #F8FAFC; padding: 24px 32px; text-align: center; border-top: 1px solid #F1F5F9;">
              <p style="color: #64748B; font-size: 13px; font-weight: 600; margin: 0 0 6px 0;">Grammatica Language Learning Platform</p>
              <p style="color: #94A3B8; font-size: 12px; margin: 0;">
                Need assistance? Contact support at <a href="mailto:support@grammatica.app" style="color: #81B655; text-decoration: none; font-weight: 600;">support@grammatica.app</a>
              </p>
              <p style="color: #CBD5E1; font-size: 11px; margin: 12px 0 0 0;">
                © 2026 Grammatica Inc. All rights reserved.
              </p>
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

  /// Send Account Verification OTP Code Email
  static Future<bool> sendOtpEmail({
    required String recipientEmail,
    required String recipientName,
    required String otpCode,
  }) async {
    debugPrint('==============================================');
    debugPrint('🔑 VERIFICATION OTP FOR $recipientEmail: $otpCode');
    debugPrint('==============================================');

    final codeDigits = otpCode.split('');
    final digitsHtml = codeDigits.map((digit) => '''
      <span style="display: inline-block; background-color: #FFFFFF; color: #0F172A; font-size: 32px; font-weight: 900; width: 52px; height: 60px; border-radius: 12px; line-height: 60px; text-align: center; box-shadow: 0 4px 12px rgba(0,0,0,0.08); border: 1.5px solid #C8E6B5; font-family: 'Courier New', monospace;">$digit</span>
    ''').join('');

    final contentHtml = '''
      <p style="color: #475569; font-size: 15px; line-height: 1.7; margin-bottom: 28px;">
        Thank you for registering with <strong>Grammatica</strong>! To activate and secure your account, please use the 6-digit verification code below:
      </p>

      <!-- OTP Box -->
      <div style="background: linear-gradient(145deg, #F0FDF4, #E6F7D9); border-radius: 20px; padding: 32px 20px; text-align: center; margin-bottom: 32px; border: 2px dashed #81B655;">
        <p style="margin: 0 0 14px 0; font-size: 12px; font-weight: 800; letter-spacing: 3px; color: #81B655; text-transform: uppercase;">Your Verification Code</p>
        <div style="display: inline-flex; gap: 10px; justify-content: center; flex-wrap: wrap;">
          $digitsHtml
        </div>
        <p style="margin: 18px 0 0 0; font-size: 12px; color: #64748B; font-weight: 600;">
          ⏱ Code expires in 10 minutes &nbsp;·&nbsp; Keep confidential
        </p>
      </div>

      <!-- Security Notice -->
      <div style="background-color: #F8FAFC; border-left: 4px solid #81B655; border-radius: 10px; padding: 16px 20px; margin-bottom: 24px;">
        <p style="margin: 0; color: #475569; font-size: 13.5px; line-height: 1.6;">
          <strong>🔒 Security Tip:</strong> Grammatica staff will never ask you for this code. If you did not sign up for Grammatica, please safely ignore this email.
        </p>
      </div>
    ''';

    final body = _buildBrandedEmailTemplate(
      title: 'Verify Your Email Address',
      subtitle: 'Complete your registration to start your language learning journey',
      badgeIcon: '🔑',
      badgeText: 'Email Verification',
      recipientName: recipientName,
      contentHtml: contentHtml,
      badgeBgColor: '#F0FDF4',
      badgeBorderColor: '#81B655',
      badgeTextColor: '#166534',
    );

    return await sendEmail(
      toEmail: recipientEmail,
      subject: 'Your Grammatica Verification Code: $otpCode',
      body: body,
    );
  }

  /// Send Forgot Password Reset OTP Code Email
  static Future<bool> sendPasswordResetOtpEmail({
    required String recipientEmail,
    required String recipientName,
    required String otpCode,
  }) async {
    debugPrint('==============================================');
    debugPrint('🔑 PASSWORD RESET OTP FOR $recipientEmail: $otpCode');
    debugPrint('==============================================');

    final codeDigits = otpCode.split('');
    final digitsHtml = codeDigits.map((digit) => '''
      <span style="display: inline-block; background-color: #FFFFFF; color: #0F172A; font-size: 32px; font-weight: 900; width: 52px; height: 60px; border-radius: 12px; line-height: 60px; text-align: center; box-shadow: 0 4px 12px rgba(0,0,0,0.08); border: 1.5px solid #C8E6B5; font-family: 'Courier New', monospace;">$digit</span>
    ''').join('');

    final contentHtml = '''
      <p style="color: #475569; font-size: 15px; line-height: 1.7; margin-bottom: 28px;">
        We received a request to reset the password for your <strong>Grammatica</strong> account. Use the 6-digit verification code below to confirm your identity and set a new password:
      </p>

      <!-- OTP Box -->
      <div style="background: linear-gradient(145deg, #F0FDF4, #E6F7D9); border-radius: 20px; padding: 32px 20px; text-align: center; margin-bottom: 32px; border: 2px dashed #81B655;">
        <p style="margin: 0 0 14px 0; font-size: 12px; font-weight: 800; letter-spacing: 3px; color: #81B655; text-transform: uppercase;">Your Password Reset Code</p>
        <div style="display: inline-flex; gap: 10px; justify-content: center; flex-wrap: wrap;">
          $digitsHtml
        </div>
        <p style="margin: 18px 0 0 0; font-size: 12px; color: #64748B; font-weight: 600;">
          ⏱ Code expires in 10 minutes &nbsp;·&nbsp; Single-use only
        </p>
      </div>

      <!-- Warning Notice -->
      <div style="background-color: #FEFCE8; border-left: 4px solid #F59E0B; border-radius: 10px; padding: 16px 20px; margin-bottom: 24px;">
        <p style="margin: 0; color: #78350F; font-size: 13.5px; line-height: 1.6;">
          <strong>⚠️ Did not request this?</strong> If you didn't request a password reset, you can safely ignore this message. Your account remains secure and no changes will be made.
        </p>
      </div>
    ''';

    final body = _buildBrandedEmailTemplate(
      title: 'Reset Your Password',
      subtitle: 'Use your secure reset code to create a new password',
      badgeIcon: '🔐',
      badgeText: 'Password Reset',
      recipientName: recipientName,
      contentHtml: contentHtml,
      badgeBgColor: '#FEF3C7',
      badgeBorderColor: '#F59E0B',
      badgeTextColor: '#92400E',
    );

    return await sendEmail(
      toEmail: recipientEmail,
      subject: 'Grammatica Password Reset Code: $otpCode',
      body: body,
    );
  }

  /// Send Security Lockout Alert Email
  static Future<bool> sendAccountLockedEmail({
    required String recipientEmail,
    String? recipientName,
    int lockoutMinutes = 5,
  }) async {
    debugPrint('==============================================');
    debugPrint('🔒 ACCOUNT LOCKED ALERT FOR $recipientEmail ($lockoutMinutes min)');
    debugPrint('==============================================');

    final name = recipientName ?? 'Learner';

    final contentHtml = '''
      <p style="color: #475569; font-size: 15px; line-height: 1.7; margin-bottom: 24px;">
        For your protection, your Grammatica account has been temporarily locked for <strong>$lockoutMinutes minutes</strong> after 3 consecutive unsuccessful login attempts.
      </p>

      <div style="background-color: #FEF2F2; border-left: 4px solid #EF4444; border-radius: 12px; padding: 20px 24px; margin-bottom: 28px;">
        <p style="margin: 0 0 10px 0; color: #991B1B; font-weight: 800; font-size: 14.5px;">What happens next?</p>
        <ul style="margin: 0; padding-left: 20px; color: #7F1D1D; font-size: 14px; line-height: 1.7;">
          <li>Your account will automatically unlock in <strong>$lockoutMinutes minutes</strong>.</li>
          <li>You can reset your password immediately on the sign-in page to regain access right away.</li>
          <li>An administrator can also manually unlock your account.</li>
        </ul>
      </div>

      <div style="background-color: #F8FAFC; border-radius: 12px; padding: 18px 20px; border: 1px solid #E2E8F0; margin-bottom: 24px;">
        <p style="margin: 0; color: #475569; font-size: 13.5px; line-height: 1.6;">
          <strong>Didn't attempt to log in?</strong> Someone else may have tried to access your account. We recommend updating your password once your account is unlocked.
        </p>
      </div>
    ''';

    final body = _buildBrandedEmailTemplate(
      title: 'Security Alert: Account Locked',
      subtitle: '3 consecutive failed sign-in attempts detected',
      badgeIcon: '🛡️',
      badgeText: 'Security Notice',
      recipientName: name,
      contentHtml: contentHtml,
      badgeBgColor: '#FEF2F2',
      badgeBorderColor: '#EF4444',
      badgeTextColor: '#991B1B',
      headerGradientStart: '#450A0A',
      headerGradientEnd: '#991B1B',
    );

    return await sendEmail(
      toEmail: recipientEmail,
      subject: 'Security Alert: Your Grammatica Account Has Been Temporarily Locked',
      body: body,
    );
  }

  /// Send Mentorship Session Notification Email
  static Future<bool> sendMentorshipNotificationEmail({
    required String recipientEmail,
    required String recipientName,
    required String educatorName,
    required String meetingTitle,
    required String timeStr,
    required String conferenceApp,
    required String meetingLink,
  }) async {
    String appName = 'Google Meet';
    if (conferenceApp.toLowerCase().contains('zoom')) appName = 'Zoom';
    if (conferenceApp.toLowerCase().contains('team')) appName = 'MS Teams';

    final contentHtml = '''
      <p style="color: #475569; font-size: 15px; line-height: 1.7; margin-bottom: 24px;">
        Your educator <strong>$educatorName</strong> has scheduled an interactive 1-on-1 mentorship session with you on Grammatica!
      </p>

      <div style="background-color: #EFF6FF; border-radius: 16px; padding: 24px; margin-bottom: 28px; border: 1px solid #BFDBFE;">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
          <tr>
            <td style="padding-bottom: 12px; color: #1E40AF; font-size: 14.5px;">
              <strong>Topic:</strong> <span style="color: #1E3A8A; font-weight: 700;">$meetingTitle</span>
            </td>
          </tr>
          <tr>
            <td style="padding-bottom: 12px; color: #1E40AF; font-size: 14.5px;">
              <strong>Date & Time:</strong> <span style="color: #1E3A8A; font-weight: 700;">$timeStr</span>
            </td>
          </tr>
          <tr>
            <td style="color: #1E40AF; font-size: 14.5px;">
              <strong>Conference Platform:</strong> <span style="color: #1E3A8A; font-weight: 700;">$appName</span>
            </td>
          </tr>
        </table>
      </div>

      <p style="color: #64748B; font-size: 14px; line-height: 1.6;">
        You can also join or review this session anytime from your <strong>Grammatica Subscriptions Dashboard</strong> or your educator's profile page.
      </p>
    ''';

    final body = _buildBrandedEmailTemplate(
      title: 'Mentorship Session Scheduled',
      subtitle: 'Prepare for your upcoming 1-on-1 live session',
      badgeIcon: '📅',
      badgeText: 'Mentorship Session',
      recipientName: recipientName,
      contentHtml: contentHtml,
      badgeBgColor: '#EFF6FF',
      badgeBorderColor: '#3B82F6',
      badgeTextColor: '#1E40AF',
      ctaButtonText: meetingLink.isNotEmpty ? 'Join Session on $appName' : null,
      ctaButtonUrl: meetingLink.isNotEmpty ? meetingLink : null,
    );

    return await sendEmail(
      toEmail: recipientEmail,
      subject: '📅 Mentorship Session Scheduled: $meetingTitle with $educatorName',
      body: body,
    );
  }

  /// Send Branded Password Reset Email with Link
  static Future<bool> sendPasswordResetLinkEmail({
    required String recipientEmail,
    required String recipientName,
    required String resetLink,
  }) async {
    final contentHtml = '''
      <p style="color: #475569; font-size: 15px; line-height: 1.7; margin-bottom: 24px;">
        We received a request to reset the password for your <strong>Grammatica</strong> account.
      </p>

      <p style="color: #475569; font-size: 15px; line-height: 1.7; margin-bottom: 28px;">
        Click the button below to set a new password for your account:
      </p>

      <!-- CTA Button -->
      <div style="text-align: center; margin: 32px 0;">
        <a href="$resetLink" style="display: inline-block; background: linear-gradient(135deg, #81B655 0%, #4D8B28 100%); color: #FFFFFF; font-size: 16px; font-weight: 800; padding: 16px 36px; border-radius: 14px; text-decoration: none; box-shadow: 0 8px 20px rgba(129, 182, 85, 0.35);">
          🔑 Reset My Password
        </a>
      </div>

      <!-- Security Notice -->
      <div style="background-color: #F8FAFC; border-left: 4px solid #81B655; border-radius: 10px; padding: 16px 20px; margin-bottom: 24px;">
        <p style="margin: 0; color: #475569; font-size: 13.5px; line-height: 1.6;">
          <strong>🛡️ Security Note:</strong> If you did not request a password reset, you can safely ignore this email. Your password will remain unchanged.
        </p>
      </div>
    ''';

    final body = _buildBrandedEmailTemplate(
      title: 'Reset Your Password 🔑',
      subtitle: 'Secure password recovery for your Grammatica account',
      badgeIcon: '🔒',
      badgeText: 'Password Reset',
      recipientName: recipientName,
      contentHtml: contentHtml,
      badgeBgColor: '#F0FDF4',
      badgeBorderColor: '#81B655',
      badgeTextColor: '#166534',
    );

    return await sendEmail(
      toEmail: recipientEmail,
      subject: '🔑 Reset Your Grammatica Password',
      body: body,
    );
  }

  /// Send Temporary Password Email for Google Sign-Up Users
  static Future<bool> sendTempPasswordEmail({
    required String recipientEmail,
    required String recipientName,
    required String tempPassword,
  }) async {
    final contentHtml = '''
      <p style="color: #475569; font-size: 15px; line-height: 1.7; margin-bottom: 28px;">
        Thank you for registering with Google! To give you full access to Grammatica across all devices and web platforms, we generated a secure <strong>Temporary Password</strong> for your account:
      </p>

      <!-- Password Box -->
      <div style="background: linear-gradient(145deg, #F0FDF4, #E6F7D9); border-radius: 20px; padding: 32px 20px; text-align: center; margin-bottom: 32px; border: 2px dashed #81B655;">
        <p style="margin: 0 0 14px 0; font-size: 12px; font-weight: 800; letter-spacing: 3px; color: #81B655; text-transform: uppercase;">Your Temporary Password</p>
        <span style="display: inline-block; background-color: #FFFFFF; color: #0F172A; font-size: 34px; font-weight: 900; padding: 12px 28px; border-radius: 14px; letter-spacing: 8px; box-shadow: 0 4px 12px rgba(0,0,0,0.08); border: 1.5px solid #C8E6B5; font-family: 'Courier New', monospace;">$tempPassword</span>
        <p style="margin: 18px 0 0 0; font-size: 12px; color: #64748B; font-weight: 600;">
          (Case sensitive &middot; Keep confidential)
        </p>
      </div>

      <!-- Security Notice -->
      <div style="background-color: #F8FAFC; border-left: 4px solid #81B655; border-radius: 10px; padding: 16px 20px; margin-bottom: 24px;">
        <p style="margin: 0; color: #475569; font-size: 13.5px; line-height: 1.6;">
          <strong>💡 Pro-tip:</strong> You can log in with this password or change it anytime in your Profile Settings to something personal and memorable.
        </p>
      </div>
    ''';

    final body = _buildBrandedEmailTemplate(
      title: 'Welcome to Grammatica! 🎉',
      subtitle: 'Your account credentials are ready for use',
      badgeIcon: '🔑',
      badgeText: 'Account Credentials',
      recipientName: recipientName,
      contentHtml: contentHtml,
      badgeBgColor: '#F0FDF4',
      badgeBorderColor: '#81B655',
      badgeTextColor: '#166534',
    );

    return await sendEmail(
      toEmail: recipientEmail,
      subject: 'Welcome to Grammatica! Your Account Password',
      body: body,
    );
  }

  /// Send Welcome Onboarding Email
  static Future<bool> sendWelcomeEmail({
    required String recipientEmail,
    required String recipientName,
  }) async {
    final contentHtml = '''
      <p style="color: #475569; font-size: 15px; line-height: 1.7; margin-bottom: 24px;">
        Welcome to <strong>Grammatica</strong>! We are thrilled to have you join our community of passionate language learners and educators.
      </p>

      <div style="background-color: #F0FDF4; border-radius: 16px; padding: 24px; margin-bottom: 28px; border: 1px solid #C8E6B5;">
        <p style="margin: 0 0 12px 0; color: #166534; font-weight: 800; font-size: 15px;">🚀 What you can do next:</p>
        <ul style="margin: 0; padding-left: 20px; color: #15803D; font-size: 14px; line-height: 1.8;">
          <li>Explore interactive grammar lessons & quizzes.</li>
          <li>Practice spelling & pronunciation in real-time.</li>
          <li>Connect with certified educators for 1-on-1 mentorship.</li>
          <li>Track your progress & earn achievements!</li>
        </ul>
      </div>
    ''';

    final body = _buildBrandedEmailTemplate(
      title: 'Welcome to Grammatica!',
      subtitle: 'Your journey to mastering languages begins today',
      badgeIcon: '🎉',
      badgeText: 'Welcome',
      recipientName: recipientName,
      contentHtml: contentHtml,
      badgeBgColor: '#F0FDF4',
      badgeBorderColor: '#81B655',
      badgeTextColor: '#166534',
    );

    return await sendEmail(
      toEmail: recipientEmail,
      subject: '🎉 Welcome to Grammatica, $recipientName!',
      body: body,
    );
  }

  /// Base Core Send Email Function
  static Future<bool> sendEmail({
    required String toEmail,
    required String subject,
    required String body,
  }) async {
    // ==========================================
    // FLUTTER WEB (CHROME) - ROUTE VIA LOCAL RELAY
    // Browsers can't open raw SMTP sockets.
    // Try Dart relay (port 8081) first, then Python backend (port 8001).
    // ==========================================
    if (kIsWeb) {
      // --- Try Dart relay first (dart run scripts/local_email_relay.dart) ---
      try {
        debugPrint('📧 Trying Dart relay at http://localhost:8081/send-generic ...');
        final smtpEmail = _smtpEmail;
        final smtpPassword = _smtpPassword;
        final dartResponse = await http.post(
          Uri.parse('http://localhost:8081/send-generic'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'smtpEmail': smtpEmail,
            'smtpPassword': smtpPassword,
            'recipientEmail': toEmail,
            'subject': subject,
            'body': body,
          }),
        ).timeout(const Duration(seconds: 6));

        if (dartResponse.statusCode == 200) {
          debugPrint('✅ Dart relay sent email to $toEmail');
          return true;
        } else {
          debugPrint('⚠️ Dart relay returned ${dartResponse.statusCode}: ${dartResponse.body}');
        }
      } catch (_) {
        debugPrint('⚠️ Dart relay not available, trying Python backend...');
      }

      // --- Fallback: Python FastAPI backend (port 8001) ---
      try {
        final backendUrl = AIConfig.pythonBackendUrl;
        final apiKey = AIConfig.pythonApiKey;
        debugPrint('📧 Trying Python backend at $backendUrl/api/v1/email/send ...');
        final response = await http.post(
          Uri.parse('$backendUrl/api/v1/email/send'),
          headers: {
            'Content-Type': 'application/json',
            'X-API-Key': apiKey,
          },
          body: jsonEncode({
            'recipientEmail': toEmail,
            'subject': subject,
            'body': body,
          }),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          debugPrint('✅ Python backend sent email to $toEmail');
          return true;
        } else {
          debugPrint('❌ Python backend failed: ${response.body}');
          return false;
        }
      } catch (e) {
        debugPrint('❌ Both relays failed. Is a relay running? Error: $e');
        return false;
      }
    }


    final smtpServer = gmail(_smtpEmail, _smtpPassword);
    final message = Message()
      ..from = Address(_smtpEmail, 'Grammatica Team')
      ..recipients.add(toEmail)
      ..subject = subject
      ..html = body;

    try {
      await send(message, smtpServer);
      return true;
    } catch (e) {
      debugPrint('Error sending email: $e');
      return false;
    }
  }
}
