import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/product.dart';
import 'product_page.dart';

const _dark     = Color(0xFF8D7B68);
const _medium   = Color(0xFFA4907C);
const _taupe    = Color(0xFFC8B6A6);
const _cream    = Color(0xFFF1DEC9);
const _offWhite = Color(0xFFFAF5EF);

String _coverUrl(String title) {
  final encoded = Uri.encodeComponent(title);
  return 'https://covers.openlibrary.org/b/title/$encoded-M.jpg';
}

// ─── Simple model to hold a wishlist item returned by the API ─────────────────
class WishlistItem {
  final int     id;
  final Product product;
  final String  created_at;

  const WishlistItem({
    required this.id,
    required this.product,
    required this.created_at,
  });

  factory WishlistItem.fromJson(Map<String, dynamic> json) {
    return WishlistItem(
      id:         json['id'] as int,
      product:    Product.fromMap(json['product']),
      created_at: json['created_at']?.toString() ?? '',
    );
  }
}

// ─── WishlistPage ─────────────────────────────────────────────────────────────
class WishlistPage extends StatefulWidget {
  const WishlistPage({super.key});

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  List<WishlistItem> _items   = [];
  bool               _loading = true;
  String?            _error;

  static const String _baseUrl = 'http://127.0.0.1:8000/api';

  @override
  void initState() {
    super.initState();
    _fetchWishlist();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<void> _fetchWishlist() async {
    setState(() { _loading = true; _error = null; });
    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        setState(() {
          _error   = 'Please log in to view your wishlist.';
          _loading = false;
        });
        return;
      }
      final response = await http.get(
        Uri.parse('$_baseUrl/wishlist/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _items   = data.map((e) => WishlistItem.fromJson(e)).toList();
          _loading = false;
        });
      } else {
        setState(() { _error = 'Failed to load wishlist.'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Could not connect to server.'; _loading = false; });
    }
  }

  Future<void> _removeItem(WishlistItem item) async {
    try {
      final token = await _getToken();
      if (token == null) return;
      final response = await http.delete(
        Uri.parse('$_baseUrl/wishlist/${item.product.id}/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 204) {
        setState(() => _items.removeWhere((i) => i.id == item.id));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${item.product.name} removed from wishlist.'),
            backgroundColor: _dark,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to remove item.'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _offWhite,
      appBar: AppBar(
        backgroundColor: _dark,
        elevation: 0,
        title: const Text(
          'My Wishlist',
          style: TextStyle(
            color: _offWhite,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        iconTheme: const IconThemeData(color: _offWhite),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _dark));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite_border, color: _taupe, size: 64),
              const SizedBox(height: 16),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _dark, fontSize: 16)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _fetchWishlist,
                style: ElevatedButton.styleFrom(
                    backgroundColor: _dark, foregroundColor: _offWhite),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite_border, color: _taupe, size: 72),
              const SizedBox(height: 16),
              const Text(
                'Your wishlist is empty.',
                style: TextStyle(
                    color: _dark, fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Browse books and tap the heart icon to save them here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _medium, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: _dark,
      onRefresh: _fetchWishlist,
      child: ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final item = _items[index];
          return _WishlistCard(
            item: item,
            onRemove: () => _removeItem(item),
          );
        },
      ),
    );
  }
}

// ─── Wishlist Card ────────────────────────────────────────────────────────────
class _WishlistCard extends StatelessWidget {
  final WishlistItem item;
  final VoidCallback onRemove;

  const _WishlistCard({required this.item, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProductPage(product: item.product),
        ),
      ),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: _cream,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _taupe, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl: _coverUrl(item.product.name),
                  width: 60,
                  height: 80,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 60,
                    height: 80,
                    color: _taupe,
                    child: const Center(
                      child: CircularProgressIndicator(color: _offWhite, strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 60,
                    height: 80,
                    color: _taupe,
                    child: const Icon(Icons.menu_book, color: _offWhite, size: 32),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      style: const TextStyle(
                        color: _dark,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.product.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _medium, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '\$${item.product.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: _dark,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          item.product.stockQuantity > 0 ? 'In stock' : 'Out of stock',
                          style: TextStyle(
                            color: item.product.stockQuantity > 0
                                ? Colors.green.shade700
                                : Colors.red.shade400,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.favorite, color: Colors.red),
                tooltip: 'Remove from wishlist',
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
