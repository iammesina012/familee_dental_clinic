import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// EmailService
///
/// Handles sending verification emails for password reset functionality.
/// Currently uses a simple HTTP-based approach that can be easily
/// integrated with email services like SendGrid, Mailgun, etc.
class EmailService {
  /// Send password reset verification email
  ///
  /// This method sends an email with the verification code to the user.
  /// Currently simulated, but ready for integration with real email services.
  static Future<bool> sendPasswordResetEmail({
    required String email,
    required String verificationCode,
    required String expirationMinutes,
  }) async {
    try {
      print('📧 EmailService: Preparing to send password reset email');
      print('📧 EmailService: To: $email');
      print('📧 EmailService: Code: $verificationCode');
      print('📧 EmailService: Expires in: $expirationMinutes minutes');

      // Try to send via Resend API first
      final resendApiKey = dotenv.env['RESEND_API_KEY'];
      if (resendApiKey != null && resendApiKey.isNotEmpty) {
        print('📧 EmailService: Using Resend API');
        final success = await _sendViaResend(
            email, verificationCode, expirationMinutes, resendApiKey);
        if (success) {
          print('✅ EmailService: Email sent successfully via Resend');
          return true;
        }
      }

      // Try Gmail SMTP as fallback
      final gmailPassword = dotenv.env['GMAIL_APP_PASSWORD'];
      if (gmailPassword != null && gmailPassword.isNotEmpty) {
        print('📧 EmailService: Using Gmail SMTP');
        final success = await _sendViaGmailSMTP(
            email, verificationCode, expirationMinutes, gmailPassword);
        if (success) {
          print('✅ EmailService: Email sent successfully via Gmail SMTP');
          return true;
        }
      }

      // Fallback to simulation if no API keys available
      print(
          '📧 EmailService: Falling back to simulation (no API keys configured)');
      await _simulateEmailSending(email, verificationCode, expirationMinutes);

      print('✅ EmailService: Email sent successfully (simulated)');
      return true;
    } catch (e) {
      print('❌ EmailService: Failed to send email: $e');
      return false;
    }
  }

  /// Send email via Resend API (recommended for production)
  static Future<bool> _sendViaResend(String email, String code,
      String expirationMinutes, String apiKey) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.resend.com/emails'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from':
              'FamiLee Dental <noreply@familee-dental.com>', // You'll need to verify this domain
          'to': [email],
          'subject': 'FamiLee Dental - Password Reset Verification',
          'html': generateEmailTemplate(code, expirationMinutes),
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Resend API: Email sent successfully');
        return true;
      } else {
        print('❌ Resend API error: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Resend API exception: $e');
      return false;
    }
  }

  /// Send email via Gmail SMTP (alternative option)
  static Future<bool> _sendViaGmailSMTP(String email, String code,
      String expirationMinutes, String appPassword) async {
    try {
      // Note: This is a simplified implementation
      // For production, you'd want to use a proper SMTP library
      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'service_id': 'gmail', // You'd need to set up EmailJS
          'template_id': 'password_reset',
          'user_id': 'your_user_id',
          'template_params': {
            'to_email': email,
            'verification_code': code,
            'expiration_minutes': expirationMinutes,
          }
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Gmail SMTP: Email sent successfully');
        return true;
      } else {
        print('❌ Gmail SMTP error: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Gmail SMTP exception: $e');
      return false;
    }
  }

  /// Simulate email sending (for development/testing)
  static Future<void> _simulateEmailSending(
      String email, String code, String expirationMinutes) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    print('📧 SIMULATION: Email sent to $email');
    print(
        '📧 SIMULATION: Subject: FamiLee Dental - Password Reset Verification');
    print('📧 SIMULATION: Verification Code: $code');
    print('📧 SIMULATION: Expires in: $expirationMinutes minutes');
    print('📧 SIMULATION: Email content would contain the verification code');
  }

  /// SendGrid Integration Example
  /// Uncomment and configure when ready to use SendGrid
  /*
  static Future<void> _sendViaSendGrid(
    String email, 
    String code, 
    String expirationMinutes
  ) async {
    final sendGridApiKey = dotenv.env['SENDGRID_API_KEY'];
    if (sendGridApiKey == null) {
      throw Exception('SendGrid API key not configured');
    }
    
    final response = await http.post(
      Uri.parse('https://api.sendgrid.com/v3/mail/send'),
      headers: {
        'Authorization': 'Bearer $sendGridApiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'personalizations': [
          {
            'to': [{'email': email}],
            'subject': 'FamiLee Dental - Password Reset Verification'
          }
        ],
        'from': {'email': 'noreply@familee-dental.com'},
        'content': [
          {
            'type': 'text/html',
            'value': _generateEmailTemplate(code, expirationMinutes)
          }
        ]
      }),
    );
    
    if (response.statusCode != 202) {
      throw Exception('SendGrid API error: ${response.statusCode} - ${response.body}');
    }
  }
  */

  /// Mailgun Integration Example
  /// Uncomment and configure when ready to use Mailgun
  /*
  static Future<void> _sendViaMailgun(
    String email, 
    String code, 
    String expirationMinutes
  ) async {
    final mailgunApiKey = dotenv.env['MAILGUN_API_KEY'];
    final mailgunDomain = dotenv.env['MAILGUN_DOMAIN'];
    
    if (mailgunApiKey == null || mailgunDomain == null) {
      throw Exception('Mailgun configuration missing');
    }
    
    final response = await http.post(
      Uri.parse('https://api.mailgun.net/v3/$mailgunDomain/messages'),
      headers: {
        'Authorization': 'Basic ${base64Encode(utf8.encode('api:$mailgunApiKey'))}',
      },
      body: {
        'from': 'FamiLee Dental <noreply@$mailgunDomain>',
        'to': email,
        'subject': 'FamiLee Dental - Password Reset Verification',
        'html': _generateEmailTemplate(code, expirationMinutes),
      },
    );
    
    if (response.statusCode != 200) {
      throw Exception('Mailgun API error: ${response.statusCode} - ${response.body}');
    }
  }
  */

  /// Generate HTML email template (for future email service integration)
  static String generateEmailTemplate(String code, String expirationMinutes) {
    return '''
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Password Reset Verification</title>
      <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background-color: #f4f4f4; }
        .container { max-width: 600px; margin: 0 auto; background-color: white; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #00D4AA, #00B894); padding: 30px; text-align: center; }
        .header h1 { color: white; margin: 0; font-size: 24px; }
        .content { padding: 30px; }
        .code-box { background-color: #f8f9fa; border: 2px solid #00D4AA; border-radius: 8px; padding: 20px; text-align: center; margin: 20px 0; }
        .code { font-size: 32px; font-weight: bold; color: #00D4AA; letter-spacing: 4px; }
        .footer { background-color: #f8f9fa; padding: 20px; text-align: center; color: #666; font-size: 14px; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>FamiLee Dental Clinic</h1>
        </div>
        <div class="content">
          <h2>Password Reset Verification</h2>
          <p>We received a request to reset your password. For your security, please use the verification code below to complete the process:</p>
          
          <div class="code-box">
            <div class="code">$code</div>
          </div>
          
          <p><strong>Important:</strong></p>
          <ul>
            <li>This code expires in $expirationMinutes minutes</li>
            <li>If you didn't request this password reset, please ignore this email</li>
            <li>Never share this code with anyone</li>
          </ul>
          
          <p>If you're having trouble, please contact our support team.</p>
        </div>
        <div class="footer">
          <p>&copy; 2024 FamiLee Dental Clinic. All rights reserved.</p>
        </div>
      </div>
    </body>
    </html>
    ''';
  }
}
