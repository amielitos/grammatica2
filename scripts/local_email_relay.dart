import 'dart:io';
import 'dart:convert';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

// This is a local development server to bypass Chrome's Socket limitations.
// It receives HTTP POST requests from your Flutter Web app and sends actual emails using the mailer package.

Future<void> main() async {
  final port = 8081;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  print('========================================================================');
  print('GRAMMATICA LOCAL EMAIL RELAY ACTIVE!');
  print('Listening on http://localhost:$port');
  print('Now your Flutter Web app can send emails perfectly via HTTP to this app.');
  print('Keep this terminal running while testing on Chrome!');
  print('========================================================================');

  await for (HttpRequest request in server) {
    // Add CORS headers to allow Chrome Web App to connect
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      continue;
    }

    if (request.method == 'POST') {
      try {
        final content = await utf8.decoder.bind(request).join();
        final data = jsonDecode(content);

        final String smtpEmail = data['smtpEmail'];
        final String smtpPassword = data['smtpPassword'];
        final String recipientEmail = data['recipientEmail'];
        
        final smtpServer = gmail(smtpEmail, smtpPassword);
        final message = Message()
          ..from = Address(smtpEmail, 'Grammatica Team')
          ..recipients.add(recipientEmail);

        if (request.uri.path == '/send-generic') {
          message.subject = data['subject'];
          message.html = data['body'];
          print('[GENERIC] Sending email to $recipientEmail with subject: ${message.subject}');
        } else {
          final String recipientName = data['recipientName'] ?? 'Learner';
          final String otpCode = data['otpCode'];
          print('[OTP] Sending OTP $otpCode to $recipientEmail...');
          
          String htmlTemplate = """
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
          """;
          message.subject = 'Your Grammatica Verification Code: $otpCode';
          message.html = htmlTemplate;
        }

        final sendReport = await send(message, smtpServer);
        print('[SUCCESS] Successfully sent to $recipientEmail: ${sendReport.toString()}');

        request.response.statusCode = HttpStatus.ok;
        request.response.write('{"status":"success"}');
      } catch (e) {
        print('[ERROR] $e');
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write('{"error":"${e.toString()}"}');
      }
    } else {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      request.response.write('{"error":"Method not allowed"}');
    }
    await request.response.close();
  }
}
