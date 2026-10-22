import 'dart:io';
import 'dart:convert';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

// This is a local development server to bypass Chrome's Socket limitations.
// It receives HTTP POST requests from your Flutter Web app and sends actual emails using the mailer package.

Future<void> main() async {
  final port = 8081;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('========================================================================');
  stdout.writeln('GRAMMATICA LOCAL EMAIL RELAY ACTIVE!');
  stdout.writeln('Listening on http://localhost:$port');
  stdout.writeln('Now your Flutter Web app can send emails perfectly via HTTP to this app.');
  stdout.writeln('Keep this terminal running while testing on Chrome!');
  stdout.writeln('========================================================================');

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

        // --- PayMongo Link Relay (bypasses browser CORS for Flutter Web) ---
        if (request.uri.path == '/create-paymongo-link') {
          final client = HttpClient();
          final paymongoReq = await client.postUrl(Uri.parse('https://api.paymongo.com/v1/links'));
          const secretKey = 'sk_live_spqXAkVZE4LvX2qhKtAR9Nw9';
          final basicAuth = 'Basic ${base64Encode(utf8.encode('$secretKey:'))}';
          paymongoReq.headers.set('authorization', basicAuth);
          paymongoReq.headers.set('content-type', 'application/json');
          paymongoReq.headers.set('accept', 'application/json');
          final double amount = (data['amount'] as num).toDouble();
          paymongoReq.write(jsonEncode({
            "data": {
              "attributes": {
                "amount": (amount * 100).toInt(),
                "description": data['description'],
                "remarks": data['remarks'] ?? 'Grammatica Subscription',
              }
            }
          }));
          final paymongoRes = await paymongoReq.close();
          final resBody = await utf8.decoder.bind(paymongoRes).join();
          request.response.statusCode = paymongoRes.statusCode;
          request.response.write(resBody);
          await request.response.close();
          continue;
        }

        if (request.uri.path == '/get-paymongo-link') {
          final linkId = data['linkId'] as String;
          final client = HttpClient();
          final paymongoReq = await client.getUrl(Uri.parse('https://api.paymongo.com/v1/links/$linkId'));
          const secretKey = 'sk_live_spqXAkVZE4LvX2qhKtAR9Nw9';
          final basicAuth = 'Basic ${base64Encode(utf8.encode('$secretKey:'))}';
          paymongoReq.headers.set('authorization', basicAuth);
          paymongoReq.headers.set('accept', 'application/json');
          final paymongoRes = await paymongoReq.close();
          final resBody = await utf8.decoder.bind(paymongoRes).join();
          request.response.statusCode = paymongoRes.statusCode;
          request.response.write(resBody);
          await request.response.close();
          continue;
        }

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
          stdout.writeln('[GENERIC] Sending email to $recipientEmail with subject: ${message.subject}');
        } else {
          final String recipientName = data['recipientName'] ?? 'Learner';
          final String otpCode = data['otpCode'];
          stdout.writeln('[OTP] Sending OTP $otpCode to $recipientEmail...');
          
          final codeDigits = otpCode.split('');
          final digitsHtml = codeDigits.map((digit) => '''
            <span style="display: inline-block; background-color: #FFFFFF; color: #0F172A; font-size: 32px; font-weight: 900; width: 52px; height: 60px; border-radius: 12px; line-height: 60px; text-align: center; box-shadow: 0 4px 12px rgba(0,0,0,0.08); border: 1.5px solid #C8E6B5; font-family: 'Courier New', monospace;">$digit</span>
          ''').join('');

          String htmlTemplate = """
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Grammatica Verification Code</title>
</head>
<body style="margin: 0; padding: 0; background-color: #F4F7F5; font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, Roboto, Helvetica, Arial, sans-serif;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background-color: #F4F7F5; padding: 40px 16px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="max-width: 620px; background-color: #FFFFFF; border-radius: 24px; overflow: hidden; box-shadow: 0 20px 50px rgba(0, 0, 0, 0.07); border: 1px solid #E2E8F0;">
          <tr>
            <td style="background: linear-gradient(135deg, #0D2818 0%, #164E2B 55%, #1E6B3C 100%); padding: 36px 32px; text-align: center; position: relative;">
              <div style="background: linear-gradient(90deg, #81B655 0%, #A3E635 50%, #4D8B28 100%); height: 5px; width: 100%; position: absolute; top: 0; left: 0;"></div>
              <table role="presentation" align="center" cellspacing="0" cellpadding="0" border="0">
                <tr>
                  <td align="center" style="vertical-align: middle;">
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
          <tr>
            <td style="padding: 44px 40px; background-color: #FFFFFF;">
              <div style="text-align: center; margin-bottom: 28px;">
                <div style="display: inline-block; background-color: #F0FDF4; border: 1.5px solid #81B655; border-radius: 999px; padding: 8px 20px;">
                  <span style="font-size: 16px; vertical-align: middle; margin-right: 6px;">🔑</span>
                  <span style="font-size: 12px; font-weight: 800; color: #166534; letter-spacing: 1.5px; text-transform: uppercase; vertical-align: middle;">Email Verification</span>
                </div>
              </div>
              <h1 style="color: #0F172A; font-size: 26px; font-weight: 800; text-align: center; margin: 0 0 10px 0; letter-spacing: -0.5px;">Verify Your Email Address</h1>
              <p style="color: #64748B; text-align: center; font-size: 15px; margin: 0 0 32px 0;">Complete your registration to start your language learning journey</p>
              <p style="color: #334155; font-size: 16px; line-height: 1.7; margin: 0 0 16px 0;">Hello <strong style="color: #0F172A;">$recipientName</strong>,</p>
              <p style="color: #475569; font-size: 15px; line-height: 1.7; margin-bottom: 28px;">
                Thank you for registering with <strong>Grammatica</strong>! To activate and secure your account, please use the 6-digit verification code below:
              </p>
              <div style="background: linear-gradient(145deg, #F0FDF4, #E6F7D9); border-radius: 20px; padding: 32px 20px; text-align: center; margin-bottom: 32px; border: 2px dashed #81B655;">
                <p style="margin: 0 0 14px 0; font-size: 12px; font-weight: 800; letter-spacing: 3px; color: #81B655; text-transform: uppercase;">Your Verification Code</p>
                <div style="display: inline-flex; gap: 10px; justify-content: center; flex-wrap: wrap;">
                  $digitsHtml
                </div>
                <p style="margin: 18px 0 0 0; font-size: 12px; color: #64748B; font-weight: 600;">
                  ⏱ Code expires in 10 minutes &nbsp;·&nbsp; Keep confidential
                </p>
              </div>
              <hr style="border: none; border-top: 1px solid #F1F5F9; margin: 36px 0 24px 0;">
              <p style="color: #94A3B8; font-size: 13px; text-align: center; margin: 0;">
                Sent with ❤️ by the <strong style="color: #81B655;">Grammatica Team</strong>
              </p>
            </td>
          </tr>
          <tr>
            <td style="background-color: #F8FAFC; padding: 24px 32px; text-align: center; border-top: 1px solid #F1F5F9;">
              <p style="color: #64748B; font-size: 13px; font-weight: 600; margin: 0 0 6px 0;">Grammatica Language Learning Platform</p>
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
          """;
          message.subject = 'Your Grammatica Verification Code: $otpCode';
          message.html = htmlTemplate;
        }

        final sendReport = await send(message, smtpServer);
        stdout.writeln('[SUCCESS] Successfully sent to $recipientEmail: ${sendReport.toString()}');

        request.response.statusCode = HttpStatus.ok;
        request.response.write('{"status":"success"}');
      } catch (e) {
        stdout.writeln('[ERROR] $e');
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
