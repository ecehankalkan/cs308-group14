import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../models/order.dart';
import 'auth_service.dart';

class ProductAdminService {
  static const String _baseUrl = 'http://127.0.0.1:8000/api';

  static Future<String?> _getToken() async {
    return await AuthService.getAccessToken();
  }

  static Future<List<Product>> fetchAllProducts() async {
    final token = await _getToken();
    final headers = <String, String>{};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/products/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        return data.map((item) => Product.fromMap(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      // ignore
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> fetchCategories() async {
    try {
      final token = await _getToken();
      final headers = <String, String>{};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
      
      final response = await http.get(
        Uri.parse('$_baseUrl/categories/'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        return data.map((item) => item as Map<String, dynamic>).toList();
      }
    } catch (e) {
      // ignore
    }
    return [];
  }

  static Future<Map<String, dynamic>?> createCategory(Map<String, dynamic> categoryData) async {
    final token = await _getToken();
    if (token == null) return null;
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/categories/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(categoryData),
      );
      if (response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        print("Failed to create category: \${response.statusCode} - \${response.body}");
      }
    } catch (e) {
      print("Error creating category: \$e");
    }
    return null;
  }

  static Future<bool> updateCategoryStatus(int id, bool isActive) async {
    final token = await _getToken();
    if (token == null) return false;
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/categories/$id/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'is_active': isActive}),
      );
      if (response.statusCode == 200) {
        return true;
      } else {
        print("Failed to update category status: \${response.statusCode} - \${response.body}");
      }
    } catch (e) {
      print("Error updating category status: \$e");
    }
    return false;
  }

  // Create Product
  static Future<Product?> createProduct(Map<String, dynamic> productData) async {
    final token = await _getToken();
    if (token == null) return null;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/products/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(productData),
      );

      if (response.statusCode == 201) {
        return Product.fromMap(jsonDecode(response.body));
      } else {
        print('Error creating product: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Exception creating product: $e');
      // Handle error
    }
    return null;
  }

  static Future<String> updateProductStatus(String id, bool isActive) async {
    final token = await _getToken();
    if (token == null) return 'No auth token found';

    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/products/$id/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'is_active': isActive}),
      );

      if (response.statusCode == 200) {
        return 'success';
      } else {
        return '${response.statusCode} - ${response.body}';
      }
    } catch (e) {
      return 'Exception: $e';
    }
  }

  static Future<Product?> updateProductStock(String id, int quantity) async {
    final token = await _getToken();
    if (token == null) return null;

    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/products/$id/stock/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'stock_quantity': quantity}),
      );

      if (response.statusCode == 200) {
        return Product.fromMap(jsonDecode(response.body) as Map<String, dynamic>);
      } else {
        print('Error updating stock: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Exception updating stock: $e');
    }
    return null;
  }

  static Future<List<Order>> fetchAllOrders() async {
    final token = await _getToken();
    final headers = <String, String>{};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/manager/orders/'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        return data.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<bool> updateDeliveryStatus(String orderId, String newStatus) async {
    final token = await _getToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/manager/orders/$orderId/delivery/'),
        headers: headers,
        body: jsonEncode({'status': newStatus}),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
