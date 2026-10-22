import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../config/ai_config.dart';

class PaymongoPaymentLink {
  final String id;
  final String checkoutUrl;
  final String referenceNumber;
  final String status; // 'unpaid', 'paid', etc.
  final double amount;
  final String description;
  final bool isLocalFallback;

  const PaymongoPaymentLink({
    required this.id,
    required this.checkoutUrl,
    required this.referenceNumber,
    required this.status,
    required this.amount,
    required this.description,
    this.isLocalFallback = false,
  });

  bool get isPaid => status.toLowerCase() == 'paid';
}

class PaymongoPaymentResult {
  final bool isSuccess;
  final String referenceNumber;
  final double amount;
  final String tier;
  final String educatorName;
  final String paymentMethod;
  final String? linkId;
  final DateTime paidAt;

  const PaymongoPaymentResult({
    required this.isSuccess,
    required this.referenceNumber,
    required this.amount,
    required this.tier,
    required this.educatorName,
    required this.paymentMethod,
    this.linkId,
    required this.paidAt,
  });
}

class PaymongoService {
  // Built-in resilient secret key for Grammatica
  static const String _fallbackSecretKey = 'sk_live_spqXAkVZE4LvX2qhKtAR9Nw9';

  // Secret Key loaded from environment with automatic fallback
  static String get _secretKey {
    try {
      const fromEnv = String.fromEnvironment('PAYMONGO_SECRET_KEY');
      if (fromEnv.isNotEmpty) return fromEnv;
      if (dotenv.isInitialized) {
        final val = dotenv.env['PAYMONGO_SECRET_KEY'];
        if (val != null && val.isNotEmpty) return val;
      }
    } catch (_) {}
    return _fallbackSecretKey;
  }

  static bool get isConfigured => _secretKey.isNotEmpty;

  /// Creates a full PayMongo payment link with ID, checkout URL, and reference number.
  /// Seamlessly handles Web CORS via backend relays and native direct calls on Mobile.
  static Future<PaymongoPaymentLink?> createPaymentLinkDetailed({
    required double amount,
    required String description,
    String remarks = 'Grammatica Subscription',
  }) async {
    final int amountInCents = (amount * 100).toInt();

    // ── 1. Web browser: Route via relays to bypass browser CORS preflights ──
    if (kIsWeb) {
      // 1A. Try Python Backend (e.g. port 8001 or deployed backend)
      try {
        final backendUrl = AIConfig.pythonBackendUrl;
        final apiKey = AIConfig.pythonApiKey;
        final response = await http.post(
          Uri.parse('$backendUrl/api/v1/payment/create-link'),
          headers: {
            'accept': 'application/json',
            'content-type': 'application/json',
            'X-API-Key': apiKey,
          },
          body: jsonEncode({
            'amount': amount,
            'description': description,
            'remarks': remarks,
          }),
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = jsonDecode(response.body);
          return PaymongoPaymentLink(
            id: data['id'] as String? ?? '',
            checkoutUrl: data['checkout_url'] as String? ?? '',
            referenceNumber: data['reference_number'] as String? ??
                'PM-${DateTime.now().millisecondsSinceEpoch}',
            status: data['link_status'] as String? ?? 'unpaid',
            amount: amount,
            description: description,
          );
        }
      } catch (e) {
        debugPrint('[PayMongo] Web Python relay note: $e');
      }

      // 1B. Try Local Dart Relay (port 8081)
      try {
        final response = await http.post(
          Uri.parse('http://localhost:8081/create-paymongo-link'),
          headers: {
            'accept': 'application/json',
            'content-type': 'application/json',
          },
          body: jsonEncode({
            'amount': amount,
            'description': description,
            'remarks': remarks,
          }),
        ).timeout(const Duration(seconds: 3));

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = jsonDecode(response.body);
          final attributes = data['data']['attributes'] as Map<String, dynamic>;
          return PaymongoPaymentLink(
            id: data['data']['id'] as String? ?? '',
            checkoutUrl: attributes['checkout_url'] as String? ?? '',
            referenceNumber: attributes['reference_number'] as String? ??
                'PM-${DateTime.now().millisecondsSinceEpoch}',
            status: attributes['status'] as String? ?? 'unpaid',
            amount: amount,
            description: description,
          );
        }
      } catch (e) {
        debugPrint('[PayMongo] Web Dart relay note: $e');
      }

      // 1C. Try direct call on web (in case CORS is not blocked)
      try {
        final String basicAuth =
            'Basic ${base64Encode(utf8.encode('$_secretKey:'))}';
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
                "remarks": remarks,
              }
            }
          }),
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = jsonDecode(response.body);
          final attributes = data['data']['attributes'] as Map<String, dynamic>;
          return PaymongoPaymentLink(
            id: data['data']['id'] as String? ?? '',
            checkoutUrl: attributes['checkout_url'] as String? ?? '',
            referenceNumber: attributes['reference_number'] as String? ??
                'PM-${DateTime.now().millisecondsSinceEpoch}',
            status: attributes['status'] as String? ?? 'unpaid',
            amount: amount,
            description: description,
          );
        }
      } catch (e) {
        debugPrint('[PayMongo] Direct browser call note: $e');
      }

      // 1D. Standalone Web fallback: Render official Grammatica PayMongo merchant QR PH with reference
      final ref = 'PM-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
      return PaymongoPaymentLink(
        id: 'link_merchant_$ref',
        checkoutUrl: '', // indicates to render official PayMongo QR PH assets/qrph.jpg
        referenceNumber: ref,
        status: 'unpaid',
        amount: amount,
        description: description,
        isLocalFallback: true,
      );
    }

    // ── 2. Mobile / Desktop: Direct PayMongo HTTPS API (Zero CORS restrictions) ──
    final String basicAuth =
        'Basic ${base64Encode(utf8.encode('$_secretKey:'))}';

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
              "remarks": remarks,
            }
          }
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final attributes = data['data']['attributes'] as Map<String, dynamic>;
        return PaymongoPaymentLink(
          id: data['data']['id'] as String? ?? '',
          checkoutUrl: attributes['checkout_url'] as String? ?? '',
          referenceNumber: attributes['reference_number'] as String? ??
              'PM-${DateTime.now().millisecondsSinceEpoch}',
          status: attributes['status'] as String? ?? 'unpaid',
          amount: amount,
          description: description,
        );
      } else {
        debugPrint('PayMongo Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('PayMongo Exception: $e');
    }

    // Graceful fallback to merchant QR PH if network drops
    final ref = 'PM-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    return PaymongoPaymentLink(
      id: 'link_merchant_$ref',
      checkoutUrl: '',
      referenceNumber: ref,
      status: 'unpaid',
      amount: amount,
      description: description,
      isLocalFallback: true,
    );
  }

  /// Retrieves the current status and payment details of an existing payment link.
  static Future<PaymongoPaymentLink?> getPaymentLink(String linkId) async {
    if (linkId.isEmpty || linkId.startsWith('link_merchant_')) return null;

    // ── 1. Web: Route via backend relay if on web ──
    if (kIsWeb) {
      try {
        final backendUrl = AIConfig.pythonBackendUrl;
        final apiKey = AIConfig.pythonApiKey;
        final response = await http.get(
          Uri.parse('$backendUrl/api/v1/payment/link-status/$linkId'),
          headers: {
            'accept': 'application/json',
            'X-API-Key': apiKey,
          },
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return PaymongoPaymentLink(
            id: data['id'] as String? ?? linkId,
            checkoutUrl: data['checkout_url'] as String? ?? '',
            referenceNumber: data['reference_number'] as String? ?? '',
            status: data['link_status'] as String? ?? 'unpaid',
            amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
            description: data['description'] as String? ?? '',
          );
        }
      } catch (_) {}

      try {
        final response = await http.post(
          Uri.parse('http://localhost:8081/get-paymongo-link'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({'linkId': linkId}),
        ).timeout(const Duration(seconds: 3));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final attributes = data['data']['attributes'] as Map<String, dynamic>;
          final rawAmount = attributes['amount'];
          return PaymongoPaymentLink(
            id: data['data']['id'] as String? ?? linkId,
            checkoutUrl: attributes['checkout_url'] as String? ?? '',
            referenceNumber: attributes['reference_number'] as String? ?? '',
            status: attributes['status'] as String? ?? 'unpaid',
            amount: rawAmount != null ? (rawAmount / 100.0) : 0.0,
            description: attributes['description'] as String? ?? '',
          );
        }
      } catch (_) {}
    }

    // ── 2. Direct HTTPS call ──
    final String basicAuth =
        'Basic ${base64Encode(utf8.encode('$_secretKey:'))}';

    try {
      final response = await http.get(
        Uri.parse('https://api.paymongo.com/v1/links/$linkId'),
        headers: {
          'accept': 'application/json',
          'authorization': basicAuth,
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final attributes = data['data']['attributes'] as Map<String, dynamic>;
        final rawAmount = attributes['amount'];
        final double amount = rawAmount != null ? (rawAmount / 100.0) : 0.0;

        return PaymongoPaymentLink(
          id: data['data']['id'] as String? ?? linkId,
          checkoutUrl: attributes['checkout_url'] as String? ?? '',
          referenceNumber: attributes['reference_number'] as String? ?? '',
          status: attributes['status'] as String? ?? 'unpaid',
          amount: amount,
          description: attributes['description'] as String? ?? '',
        );
      }
    } catch (_) {}

    return null;
  }

  static Future<String?> createPaymentLink({
    required double amount,
    required String description,
  }) async {
    final link = await createPaymentLinkDetailed(
      amount: amount,
      description: description,
    );
    return link?.checkoutUrl;
  }
}
