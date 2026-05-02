import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/order.dart';
import '../services/auth_service.dart';

class OrderService {
  static const String _baseUrl = 'http://127.0.0.1:8000';

  Future<List<Order>> fetchAllOrders() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/sales/orders/'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        return data.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Cancel a processing order OR request a refund for a delivered order.
  /// [action] must be either 'cancel' or 'refund'.
  Future<bool> cancelOrRefundOrder(String orderId, String action) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/api/orders/$orderId/action/'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: jsonEncode({'action': action}),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Accept or reject a refund request (Sales Manager only).
  /// [decision] must be either 'accept' or 'reject'.
  Future<bool> resolveRefundRequest(String orderId, String decision) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/sales/orders/$orderId/refund-decision/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'decision': decision}),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
