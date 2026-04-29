import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/order.dart';

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
}
