import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/product.dart';

class ProductService {
  static const String _baseUrl = 'http://127.0.0.1:8000';

  Future<Product?> fetchProductById(String productId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/products/$productId/'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return Product.fromMap(data);
      }
    } catch (_) {}

    return null;
  }
}