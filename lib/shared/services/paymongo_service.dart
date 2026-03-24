import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PaymongoService {
  static String get _publicKey => dotenv.env['PAYMONGO_PUBLIC_KEY'] ?? '';
  static String get _secretKey => dotenv.env['PAYMONGO_SECRET_KEY'] ?? '';
  static const String _baseUrl = 'https://api.paymongo.com/v1';

  static String get _authHeader {
    final bytes = utf8.encode('$_secretKey:');
    return 'Basic ${base64.encode(bytes)}';
  }

  /// Create a Source for GCash or PayMaya
  /// [amount] in PHP (e.g., 100.00)
  /// [type] can be 'gcash' or 'grab_pay' or 'paymaya'
  static Future<Map<String, dynamic>> createSource({
    required double amount,
    required String type,
    required String successUrl,
    required String failureUrl,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/sources'),
      headers: {
        'Authorization': _authHeader,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'data': {
          'attributes': {
            'amount': (amount * 100).toInt(), // PayMongo uses centavos
            'currency': 'PHP',
            'type': type,
            'redirect': {
              'success': successUrl,
              'failed': failureUrl,
            },
          }
        }
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(data['errors']?[0]?['detail'] ?? 'Failed to create source');
    }

    return data['data'];
  }

  /// Retrieve a source by ID to check its status
  static Future<Map<String, dynamic>> retrieveSource(String sourceId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/sources/$sourceId'),
      headers: {
        'Authorization': _authHeader,
      },
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['errors']?[0]?['detail'] ?? 'Failed to retrieve source');
    }

    return data['data'];
  }

  /// Create a Payment from a 'chargeable' source
  static Future<Map<String, dynamic>> createPayment({
    required double amount,
    required String sourceId,
    String? description,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/payments'),
      headers: {
        'Authorization': _authHeader,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'data': {
          'attributes': {
            'amount': (amount * 100).toInt(),
            'currency': 'PHP',
            'source': {
              'id': sourceId,
              'type': 'source',
            },
            'description': description ?? 'Wallet Cash In',
          }
        }
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(data['errors']?[0]?['detail'] ?? 'Failed to create payment');
    }

    return data['data'];
  }
}
