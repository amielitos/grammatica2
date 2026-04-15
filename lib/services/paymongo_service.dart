import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../config/secrets.dart';

class PaymongoService {
  // Live Secret Key to fetch the live QR Code
  static const String _secretKey = Secrets.paymongoSecretKey;
  
  static Future<String?> createPaymentLink({
    required double amount, 
    required String description,
  }) async {
    // Paymongo expects amount in cents/centavos (e.g., 100.00 PHP = 10000)
    final int amountInCents = (amount * 100).toInt();
    
    final String basicAuth = 'Basic ${base64Encode(utf8.encode('$_secretKey:'))}';

    try {
      final response = await http.post(
        Uri.parse('https://api.paymongo.com/v1/links'),
        headers: {
          'accept': 'application/json',
          'content-type': 'application/json',
          'authorization': basicAuth,
        },
        body: jsonEncode({
          "data": {
            "attributes": {
              "amount": amountInCents,
              "description": description,
              "remarks": "Grammatica Subscription"
            }
          }
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        // This checkout URL automatically handles GCash, Maya, and QR PH
        return data['data']['attributes']['checkout_url'];
      } else {
        debugPrint('PayMongo Error: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('PayMongo Exception: $e');
      return null;
    }
  }

  static Future<String?> getQRCodeString(String qrCodeId) async {
    final String basicAuth = 'Basic ${base64Encode(utf8.encode('$_secretKey:'))}';

    try {
      final response = await http.get(
        Uri.parse('https://api.paymongo.com/v1/qr_codes/$qrCodeId'),
        headers: {
          'accept': 'application/json',
          'authorization': basicAuth,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data']['attributes']['qr_string'];
      } else {
        debugPrint('PayMongo Error Fetching QR: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('PayMongo Exception: $e');
      return null;
    }
  }
}
