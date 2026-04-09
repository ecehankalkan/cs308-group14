import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';

class CartItem {
  final int cartItemId;
  final Product product;
  final int quantity;

  const CartItem({
    required this.cartItemId,
    required this.product,
    required this.quantity,
  });

  double get subtotal => product.price * quantity;

  CartItem copyWith({
    int? cartItemId,
    Product? product,
    int? quantity,
  }) {
    return CartItem(
      cartItemId: cartItemId ?? this.cartItemId,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }
}

class CartUpdateResult {
  final List<CartItem> items;
  final bool adjustedToStock;

  const CartUpdateResult({
    required this.items,
    required this.adjustedToStock,
  });
}

class CartService {
  static const String _baseUrl = 'http://127.0.0.1:8000';
  static const String _cookieKey = 'sessionid_cookie';

  // We keep track of items locally so we can find cartItemId by productId easily
  List<CartItem> _currentItems = [];

  Future<bool> _isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    return token != null && token.isNotEmpty;
  }

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final headers = {'Content-Type': 'application/json'};
    
    final token = prefs.getString('access_token');
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    } else {
      final cookie = prefs.getString(_cookieKey);
      if (cookie != null && cookie.isNotEmpty) {
        final sessionId = cookie.replaceAll('sessionid=', '').trim();
        headers['X-Session-Id'] = sessionId;
        headers['Cookie'] = cookie;
      }
    }
    return headers;
  }

  Future<void> _updateCookie(http.Response response) async {
    if (await _isLoggedIn()) return; // Don't track guest session ID once logged in
    
    final sessionId = response.headers['x-session-id'];
    if (sessionId != null && sessionId.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cookieKey, 'sessionid=$sessionId');
      return;
    }
    
    final rawCookie = response.headers['set-cookie'];
    if (rawCookie != null) {
      final parts = rawCookie.split(',');
      for (var p in parts) {
        if (p.contains('sessionid=')) {
          final cookieStr = p.split(';')[0].trim();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_cookieKey, cookieStr);
          break;
        }
      }
    }
  }

  Future<List<CartItem>> fetchCartItems() async {
    try {
      final headers = await _getHeaders();
      final endpoint = await _isLoggedIn() ? '$_baseUrl/api/cart/' : '$_baseUrl/api/guest/cart/';
      
      final response = await http.get(Uri.parse(endpoint), headers: headers);
      await _updateCookie(response);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _currentItems = data.map((item) {
          return CartItem(
            cartItemId: item['id'],
            quantity: item['quantity'],
            product: Product.fromMap(item['product']),
          );
        }).toList();
        return _currentItems;
      }
    } catch (e) {
      print('Fetch cart error: $e');
    }
    return [];
  }

  Future<CartUpdateResult> updateQuantity({
    required String productId,
    required int requestedQuantity,
  }) async {
    final headers = await _getHeaders();
    final isAuth = await _isLoggedIn();
    final baseEndpoint = isAuth ? '$_baseUrl/api/cart/' : '$_baseUrl/api/guest/cart/';
    
    final existingItemIndex = _currentItems.indexWhere((item) => item.product.id == productId);
    
    if (requestedQuantity <= 0) {
        if (existingItemIndex != -1) {
          final cartItemId = _currentItems[existingItemIndex].cartItemId;
          final response = await http.delete(
            Uri.parse('$baseEndpoint$cartItemId/'),
            headers: headers,
          );
          if (response.statusCode >= 400) throw Exception('Delete failed: ${response.body}');
          await _updateCookie(response);
        }
    } else {
        if (existingItemIndex != -1) {
            final cartItemId = _currentItems[existingItemIndex].cartItemId;
            final response = await http.patch(
              Uri.parse('$baseEndpoint$cartItemId/'),
              headers: headers,
              body: jsonEncode({'quantity': requestedQuantity}),
            );
            if (response.statusCode >= 400) throw Exception('Patch failed: ${response.body}');
            await _updateCookie(response);
        } else {
            // Try POST to add new product if not found locally
            final response = await http.post(
              Uri.parse(baseEndpoint),
              headers: headers,
              body: jsonEncode({'product_id': int.tryParse(productId) ?? 0, 'quantity': requestedQuantity}),
            );
            if (response.statusCode >= 400) throw Exception('Post failed: ${response.statusCode}');
            await _updateCookie(response);
        }
    }

    final newItems = await fetchCartItems();
    return CartUpdateResult(items: newItems, adjustedToStock: false);
  }
}