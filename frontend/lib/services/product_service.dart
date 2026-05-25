import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import 'auth_service.dart';

class ProductService {
  static const String _baseUrl = 'http://127.0.0.1:8000';

  Future<List<Product>> fetchAllProducts() async {
    try {
      final token = await AuthService.getAccessToken();
      final headers = <String, String>{};
      if (token != null) headers['Authorization'] = 'Bearer $token';
      final response = await http.get(
        Uri.parse('$_baseUrl/api/products/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        return data
            .map((item) => Product.fromMap(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      print('Error fetching products: $e');
    }

    return [];
  }

  Future<Product?> updateProductPrice(String productId, {double? price, double? discountPercentage}) async {
    try {
      final body = <String, dynamic>{};
      if (price != null) body['price'] = price;
      if (discountPercentage != null) body['discount_percentage'] = discountPercentage;

      final headers = await AuthService.getAuthHeaders();

      final response = await http.patch(
        Uri.parse('$_baseUrl/api/products/$productId/price/'),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return Product.fromMap(jsonDecode(response.body) as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }


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

  Future<Product?> updateProductStock(String productId, int quantity) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http.patch(
        Uri.parse('$_baseUrl/api/products/$productId/stock/'),
        headers: headers,
        body: jsonEncode({'stock_quantity': quantity}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return Product.fromMap(data);
      }
    } catch (_) {}

    return null;
  }
}