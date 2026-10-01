import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../config/ai_config.dart';

class EmailSenderService {
  static String get _smtpEmail {
    const fromEnv = String.fromEnvironment('SMTP_EMAIL');
    if (fromEnv.isNotEmpty) return fromEnv;
    return dotenv.env['SMTP_EMAIL'] ?? '';
  }

  static String get _smtpPassword {
    const fromEnv = String.fromEnvironment('SMTP_PASSWORD');
    if (fromEnv.isNotEmpty) return fromEnv;
    return dotenv.env['SMTP_PASSWORD'] ?? '';
  } 

  static Future<bool> sendOtpEmail({
    required String recipientEmail,
    required String recipientName,
    required String otpCode,
  }) async {
    debugPrint('==============================================');
    debugPrint('🔑 VERIFICATION OTP FOR $recipientEmail: $otpCode');
    debugPrint('==============================================');
    return await sendEmail(
      toEmail: recipientEmail,
      subject: 'Your Grammatica Verification Code: $otpCode',
      body: """
      <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 600px; margin: 0 auto; background-color: #f4f7f6; padding: 20px; border-radius: 12px;">
        <div style="text-align: center; margin-bottom: 24px;">
          <h1 style="color: #81B655; margin: 0; font-size: 32px; font-weight: 800; letter-spacing: -1px;">Grammatica</h1>
          <p style="color: #666; font-size: 15px; margin-top: 5px;">Your ultimate language learning partner</p>
        </div>
        
        <div style="background-color: white; padding: 40px; border-radius: 16px; box-shadow: 0 8px 24px rgba(0,0,0,0.06); border-top: 4px solid #81B655;">
          <h2 style="color: #2c3e50; margin-top: 0; font-size: 22px;">Verify your email address</h2>
          
          <p style="color: #4a5568; font-size: 16px; line-height: 1.6;">Hello <strong style="color: #2d3748;">$recipientName</strong>,</p>
          
          <p style="color: #4a5568; font-size: 16px; line-height: 1.6;">Thank you for registering an account with Grammatica! To complete your registration and secure your new account, please use the 6-digit verification code below:</p>
          
          <div style="background-color: #f0fdf4; text-align: center; padding: 24px; margin: 32px 0; border-radius: 12px; border: 1px dashed #81B655;">
            <span style="font-size: 38px; font-weight: 900; color: #81B655; letter-spacing: 8px;">$otpCode</span>
          </div>
          
          <p style="color: #718096; font-size: 14px; line-height: 1.6;"><strong>Security Tip:</strong> Please do not share this code with anyone. Grammatica employees will never ask you for this code.</p>
          <p style="color: #718096; font-size: 14px; line-height: 1.6;">If you didn't attempt to sign up for Grammatica, please safely ignore this email.</p>
        </div>
      </div>
      """,
    );
  }

  static Future<bool> sendPasswordResetOtpEmail({
    required String recipientEmail,
    required String recipientName,
    required String otpCode,
  }) async {
    debugPrint('==============================================');
    debugPrint('🔑 PASSWORD RESET OTP FOR $recipientEmail: $otpCode');
    debugPrint('==============================================');
    return await sendEmail(
      toEmail: recipientEmail,
      subject: 'Grammatica Password Reset Code: $otpCode',
      body: """
      <div style="font-family: 'Inter', 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 620px; margin: 0 auto; background-color: #f7f9f7; padding: 32px 20px;">

        <!-- Header -->
        <div style="text-align: center; margin-bottom: 32px;">
          <div style="display: inline-block; background: linear-gradient(135deg, #81B655, #5a8e2e); border-radius: 16px; padding: 14px 28px; margin-bottom: 16px;">
            <span style="color: white; font-size: 28px; font-weight: 900; letter-spacing: -1px;">Grammatica</span>
          </div>
          <p style="color: #64748b; font-size: 14px; margin: 0;">Your trusted language learning platform</p>
        </div>

        <!-- Card -->
        <div style="background-color: #ffffff; border-radius: 24px; overflow: hidden; box-shadow: 0 20px 60px rgba(0,0,0,0.08);">

          <!-- Card Top Accent -->
          <div style="background: linear-gradient(135deg, #81B655 0%, #5a8e2e 100%); height: 6px;"></div>

          <!-- Card Body -->
          <div style="padding: 48px 44px;">

            <!-- Lock Icon Area -->
            <div style="text-align: center; margin-bottom: 32px;">
              <div style="display: inline-block; background-color: #f0fdf4; border-radius: 50%; padding: 20px; border: 2px solid #c8e6b5;">
                <span style="font-size: 40px;">🔐</span>
              </div>
            </div>

            <!-- Title -->
            <h2 style="color: #0f172a; font-size: 26px; font-weight: 800; text-align: center; margin: 0 0 8px 0; letter-spacing: -0.5px;">Password Reset Request</h2>
            <p style="color: #64748b; text-align: center; font-size: 15px; margin: 0 0 36px 0;">We received a request to reset your password.</p>

            <!-- Greeting -->
            <p style="color: #334155; font-size: 16px; line-height: 1.7; margin-bottom: 8px;">Hi <strong style="color: #0f172a;">$recipientName</strong>,</p>
            <p style="color: #475569; font-size: 15px; line-height: 1.7; margin-bottom: 32px;">Use the verification code below to confirm your identity. This code is valid for <strong>10 minutes</strong> and can only be used once.</p>

            <!-- OTP Box -->
            <div style="background: linear-gradient(145deg, #f0fdf4, #e6f7d9); border-radius: 20px; padding: 36px 24px; text-align: center; margin-bottom: 32px; border: 2px dashed #81B655; position: relative;">
              <p style="margin: 0 0 12px 0; font-size: 12px; font-weight: 700; letter-spacing: 3px; color: #81B655; text-transform: uppercase;">Your Reset Code</p>
              <div style="display: inline-flex; gap: 10px; justify-content: center; flex-wrap: wrap;">
                ${otpCode.split('').map((digit) => '''
                  <span style="display: inline-block; background-color: #ffffff; color: #0f172a; font-size: 32px; font-weight: 900; width: 52px; height: 60px; border-radius: 12px; line-height: 60px; text-align: center; box-shadow: 0 4px 12px rgba(0,0,0,0.08); border: 1.5px solid #d4edbc;">$digit</span>
                ''').join('')}
              </div>
              <p style="margin: 16px 0 0 0; font-size: 12px; color: #94a3b8;">⏱ Expires in 10 minutes &nbsp;·&nbsp; Do not share</p>
            </div>

            <!-- Security Note -->
            <div style="background-color: #fefce8; border-left: 4px solid #f59e0b; border-radius: 8px; padding: 16px 20px; margin-bottom: 28px;">
              <p style="margin: 0; color: #78350f; font-size: 13px; line-height: 1.6;">
                <strong>⚠️ Security Notice:</strong> If you did not request a password reset, please ignore this email. Your account is safe. Never share this code with anyone — Grammatica staff will never ask for it.
              </p>
            </div>

            <!-- Divider -->
            <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 0 0 24px 0;">

            <!-- Footer note -->
            <p style="color: #94a3b8; font-size: 13px; text-align: center; margin: 0;">
              Sent with ❤️ by the <strong style="color: #81B655;">Grammatica Team</strong>
            </p>

          </div>
        </div>

        <!-- Bottom Caption -->
        <p style="text-align: center; color: #cbd5e1; font-size: 12px; margin-top: 24px;">
          © 2026 Grammatica. All rights reserved.
        </p>
      </div>
      """,
    );
  }

  static Future<bool> sendAccountLockedEmail({
    required String recipientEmail,
    String? recipientName,
    int lockoutMinutes = 5,
  }) async {
    debugPrint('==============================================');
    debugPrint('🔒 ACCOUNT LOCKED ALERT FOR $recipientEmail ($lockoutMinutes min)');
    debugPrint('==============================================');
    final name = recipientName ?? 'Learner';
    return await sendEmail(
      toEmail: recipientEmail,
      subject: 'Security Alert: Your Grammatica Account Has Been Temporarily Locked',
      body: """
      <div style="font-family: 'Inter', 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 620px; margin: 0 auto; background-color: #f7f9f7; padding: 32px 20px;">
        <div style="text-align: center; margin-bottom: 32px;">
          <div style="display: inline-block; background: linear-gradient(135deg, #81B655, #5a8e2e); border-radius: 16px; padding: 14px 28px; margin-bottom: 16px;">
            <span style="color: white; font-size: 28px; font-weight: 900; letter-spacing: -1px;">Grammatica</span>
          </div>
          <p style="color: #64748b; font-size: 14px; margin: 0;">Your trusted language learning platform</p>
        </div>

        <div style="background-color: #ffffff; border-radius: 24px; overflow: hidden; box-shadow: 0 20px 60px rgba(0,0,0,0.08);">
          <div style="background: linear-gradient(135deg, #ef4444 0%, #b91c1c 100%); height: 6px;"></div>

          <div style="padding: 48px 44px;">
            <div style="text-align: center; margin-bottom: 32px;">
              <div style="display: inline-block; background-color: #fef2f2; border-radius: 50%; padding: 20px; border: 2px solid #fecaca;">
                <span style="font-size: 40px;">🛡️</span>
              </div>
            </div>

            <h2 style="color: #0f172a; font-size: 24px; font-weight: 800; text-align: center; margin: 0 0 8px 0; letter-spacing: -0.5px;">Security Alert: Account Temporarily Locked</h2>
            <p style="color: #64748b; text-align: center; font-size: 15px; margin: 0 0 32px 0;">3 consecutive failed login attempts detected</p>

            <p style="color: #334155; font-size: 16px; line-height: 1.7; margin-bottom: 8px;">Hi <strong style="color: #0f172a;">$name</strong>,</p>
            <p style="color: #475569; font-size: 15px; line-height: 1.7; margin-bottom: 24px;">For your protection, your Grammatica account has been temporarily locked for <strong>$lockoutMinutes minutes</strong> due to 3 consecutive unsuccessful password attempts.</p>

            <div style="background-color: #fef2f2; border-left: 4px solid #ef4444; border-radius: 12px; padding: 20px; margin-bottom: 28px;">
              <p style="margin: 0 0 8px 0; color: #991b1b; font-weight: 700; font-size: 14px;">What happens next?</p>
              <ul style="margin: 0; padding-left: 20px; color: #7f1d1d; font-size: 13px; line-height: 1.7;">
                <li>Your account will automatically unlock in <strong>$lockoutMinutes minutes</strong>.</li>
                <li>You can immediately reset your password on the sign-in page using <strong>Forgot Password</strong> to regain access right away.</li>
                <li>If an administrator is available, they can also unlock your account manually.</li>
              </ul>
            </div>

            <div style="background-color: #f8fafc; border-radius: 12px; padding: 18px 20px; margin-bottom: 28px; border: 1px solid #e2e8f0;">
              <p style="margin: 0; color: #475569; font-size: 13px; line-height: 1.6;">
                <strong>Didn't try to log in?</strong> Someone else may have attempted to access your account. We strongly recommend resetting your password immediately once unlocked.
              </p>
            </div>

            <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 0 0 24px 0;">

            <p style="color: #94a3b8; font-size: 13px; text-align: center; margin: 0;">
              Grammatica Security Team
            </p>
          </div>
        </div>

        <p style="text-align: center; color: #cbd5e1; font-size: 12px; margin-top: 24px;">
          © 2026 Grammatica. All rights reserved.
        </p>
      </div>
      """,
    );
  }

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

    final subject = '📅 Mentorship Session Scheduled: $meetingTitle with $educatorName';
    final body = """
    <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 600px; margin: 0 auto; background-color: #f4f7f6; padding: 20px; border-radius: 12px;">
      <div style="text-align: center; margin-bottom: 24px;">
        <h1 style="color: #81B655; margin: 0; font-size: 32px; font-weight: 800; letter-spacing: -1px;">Grammatica</h1>
        <p style="color: #666; font-size: 15px; margin-top: 5px;">Personalized Language Learning</p>
      </div>
      
      <div style="background-color: white; padding: 36px; border-radius: 16px; box-shadow: 0 8px 24px rgba(0,0,0,0.06); border-top: 4px solid #3B82F6;">
        <h2 style="color: #1E293B; margin-top: 0; font-size: 22px;">📅 Mentorship Session Scheduled!</h2>
        
        <p style="color: #475569; font-size: 16px; line-height: 1.6;">Hi <strong>$recipientName</strong>,</p>
        
        <p style="color: #475569; font-size: 16px; line-height: 1.6;">Your educator <strong>$educatorName</strong> has scheduled a mentorship session with you on Grammatica!</p>
        
        <div style="background-color: #f0f9ff; padding: 20px; border-radius: 12px; margin: 24px 0; border: 1px solid #bae6fd;">
          <p style="margin: 0 0 8px 0; font-size: 14px; color: #0369a1;"><strong>Topic:</strong> $meetingTitle</p>
          <p style="margin: 0 0 8px 0; font-size: 14px; color: #0369a1;"><strong>Date & Time:</strong> $timeStr</p>
          <p style="margin: 0; font-size: 14px; color: #0369a1;"><strong>Platform:</strong> $appName</p>
        </div>

        ${meetingLink.isNotEmpty ? '''
        <div style="text-align: center; margin: 32px 0;">
          <a href="$meetingLink" target="_blank" style="background-color: #3B82F6; color: white; padding: 14px 28px; border-radius: 10px; text-decoration: none; font-weight: bold; font-size: 16px; display: inline-block;">Join Session on $appName</a>
        </div>
        ''' : ''}

        <p style="color: #64748b; font-size: 14px; line-height: 1.6;">You can also access this session directly from your <strong>Grammatica Subscriptions Dashboard</strong> or your educator's profile page.</p>
        <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 24px 0;">
        <p style="color: #94a3b8; font-size: 12px; text-align: center; margin: 0;">Sent with ❤️ by the Grammatica Team</p>
      </div>
    </div>
    """;

    return await sendEmail(
      toEmail: recipientEmail,
      subject: subject,
      body: body,
    );
  }

  static Future<bool> sendEmail({
    required String toEmail,
    required String subject,
    required String body,
  }) async {
    // ==========================================
    // FLUTTER WEB (CHROME) - ROUTE VIA PYTHON BACKEND
    // Browsers can't open raw SMTP sockets, so we
    // delegate to the FastAPI /api/v1/email/send endpoint.
    // ==========================================
    if (kIsWeb) {
      try {
        final backendUrl = AIConfig.pythonBackendUrl;
        final apiKey = AIConfig.pythonApiKey;
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
        );
        if (response.statusCode == 200) {
          debugPrint('Backend email relay success to $toEmail');
          return true;
        } else {
          debugPrint('Backend email relay failed: ${response.body}');
          return false;
        }
      } catch (e) {
        debugPrint("Backend email relay error: $e");
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
