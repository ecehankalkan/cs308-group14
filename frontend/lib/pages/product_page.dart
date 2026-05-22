import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product.dart';
import '../models/review.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/product_service.dart';
import '../services/review_service.dart';

const String _baseUrl = 'http://127.0.0.1:8000/api';

const _dark = Color(0xFF8D7B68);
const _medium = Color(0xFFA4907C);
const _taupe = Color(0xFFC8B6A6);
const _cream = Color(0xFFF1DEC9);
const _offWhite = Color(0xFFFAF5EF);

// ─── Open Library cover URL by book title ─────────────────────────────────────
String _coverUrl(String title) {
  final encoded = Uri.encodeComponent(title);
  return 'https://covers.openlibrary.org/b/title/$encoded-M.jpg';
}
class ProductPage extends StatefulWidget {
  final Product product;

  const ProductPage({super.key, required this.product});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final CartService _cartService = CartService();
  final ProductService _productService = ProductService();
  final ReviewService _reviewService = ReviewService();
  final TextEditingController _quantityController = TextEditingController(
    text: '1',
  );

  Product? _backendProduct;
  int _selectedQuantity = 1;
  bool _isLoadingProduct = true;
  late bool _inWishlist;
  List<ProductReview> _reviews = [];
  bool _isLoadingReviews = true;
  double _avgRating = 0.0;
  int _ratingCount = 0;

  ProductReview? _myReview;
  bool _isLoadingMyReview = true;
  int _formRating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  double _normalizeRating(double? value) {
    if (value == null || value.isNaN || value.isInfinite) return 0.0;
    final clamped = value.clamp(0.0, 5.0);
    return (clamped * 2).round() / 2.0;
  }

  @override
  void initState() {
    super.initState();
    _inWishlist = false;
    _loadWishlistStatus();
    _loadProductFromBackend();
    _loadReviews();
    _loadMyReview();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Product get _displayProduct => _backendProduct ?? widget.product;

  Future<void> _loadProductFromBackend() async {
    final fetchedProduct = await _productService.fetchProductById(
      widget.product.id,
    );

    if (!mounted) return;
    setState(() {
      _backendProduct = fetchedProduct ?? widget.product;
      _isLoadingProduct = false;
      if (_backendProduct!.averageRating != null) {
        _avgRating = _normalizeRating(_backendProduct!.averageRating!);
        _ratingCount = _backendProduct!.ratingCount;
      }
    });
  }

  Future<void> _loadReviews() async {
    try {
      final productId = int.tryParse(widget.product.id) ?? 0;
      final reviews = await _reviewService.fetchProductReviews(productId);
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingReviews = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load reviews: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  

  Future<void> _loadMyReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoadingMyReview = false);
      return;
    }
    final productId = int.tryParse(widget.product.id) ?? 0;
    final review = await _reviewService.fetchMyReview(productId);
    if (mounted) {
      setState(() {
        _myReview = review;
        _isLoadingMyReview = false;
      });
    }
  }

  Future<void> _submitReview() async {
    final comment = _commentController.text.trim();
    if (_formRating == 0 && comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please provide a rating or a comment.'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final productId = int.tryParse(widget.product.id) ?? 0;
      final review = await _reviewService.createReview(
        productId: productId,
        rating: _formRating > 0 ? _formRating : null,
        comment: comment.isNotEmpty ? comment : null,
      );
      if (mounted) {
        setState(() {
          _myReview = review;
          _isSubmitting = false;
          _formRating = 0;
          _commentController.clear();
        });
        _loadProductFromBackend();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        final message = e.toString().contains('purchased')
            ? 'You can only review products you have purchased and received.'
            : 'Failed to submit review. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  void _changeQuantity(int newQuantity) {
    final maxQuantity = _displayProduct.stockQuantity;
    int validQuantity = newQuantity.clamp(1, maxQuantity > 0 ? maxQuantity : 1);

    setState(() {
      _selectedQuantity = validQuantity;
      _quantityController.text = validQuantity.toString();
    });
  }

  Future<void> _addToCart() async {
    final product = _displayProduct;
    if (product.stockQuantity <= 0) return;

    final quantityToAdd = _selectedQuantity;

    if (!_cartService.canAddMore(product.id, quantityToAdd)) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Max stock reached for this item.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ));
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$quantityToAdd x ${product.name} added to cart.'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      await _cartService.addItems(product.id, quantityToAdd);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add ${product.name}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _loadWishlistStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null || token.isEmpty) return;
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/wishlist/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final ids = data.map<int>((item) => item['product']['id'] as int).toSet();
        if (mounted) setState(() => _inWishlist = ids.contains(int.parse(widget.product.id)));
      }
    } catch (_) {}
  }

  Future<void> _toggleWishlist() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showAuthDialog();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null || token.isEmpty) {
      _showAuthDialog();
      return;
    }

    final productId = int.parse(_displayProduct.id);
    final wasInWishlist = _inWishlist;

    // OPTIMISTIC UI
    setState(() => _inWishlist = !wasInWishlist);
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(!wasInWishlist ? '${_displayProduct.name} added to wishlist!' : '${_displayProduct.name} removed from wishlist'),
      duration: const Duration(seconds: 1),
    ));

    try {
      if (wasInWishlist) {
        await http.delete(
          Uri.parse('$_baseUrl/wishlist/$productId/'),
          headers: {'Authorization': 'Bearer $token'},
        );
      } else {
        await http.post(
          Uri.parse('$_baseUrl/wishlist/'),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          body: jsonEncode({'product_id': productId}),
        );
      }
    } catch (_) {
      // REVERT ON FAILURE
      if (mounted) {
        setState(() => _inWishlist = wasInWishlist);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to update wishlist'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  void _showAuthDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _offWhite,
          title: const Text(
            'Log in to your account',
            style: TextStyle(
              color: _dark,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            'You need to be logged in to add items to your wishlist.',
            style: TextStyle(color: _medium, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/signup');
              },
              child: const Text(
                'Sign Up',
                style: TextStyle(color: _dark, fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _dark,
                foregroundColor: _offWhite,
              ),
              child: const Text('Log In'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = _displayProduct;
    final hasStock = product.stockQuantity > 0;

    return Scaffold(
      backgroundColor: _offWhite,
      appBar: AppBar(
        backgroundColor: _dark,
        foregroundColor: _offWhite,
        title: const Text('Product Detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined, color: _offWhite),
            tooltip: 'Cart',
            onPressed: () => Navigator.pushNamed(context, '/cart'),
          ),
          IconButton(
            icon: const Icon(Icons.favorite_border, color: _offWhite),
            tooltip: 'Wishlist',
            onPressed: () => Navigator.pushNamed(context, '/wishlist'),
          ),
          StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              final user = snapshot.data;
              return PopupMenuButton(
                color: _offWhite,
                itemBuilder: (context) {
                  if (user != null) {
                    return [
                      PopupMenuItem(
                        enabled: false,
                        child: Text(
                          'Hi, ${user.displayName ?? 'User'}!',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _dark,
                          ),
                        ),
                      ),
                      PopupMenuItem(
                        child: const Text(
                          'Profile',
                          style: TextStyle(color: _dark),
                        ),
                        onTap: () => Navigator.pushNamed(context, '/profile'),
                      ),
                      PopupMenuItem(
                        child: const Text(
                          'Logout',
                          style: TextStyle(color: Colors.red),
                        ),
                        onTap: () async => await AuthService().signOut(),
                      ),
                    ];
                  } else {
                    return [
                      PopupMenuItem(
                        child: const Text(
                          'Login',
                          style: TextStyle(color: _dark),
                        ),
                        onTap: () => Navigator.pushNamed(context, '/login'),
                      ),
                      PopupMenuItem(
                        child: const Text(
                          'Sign Up',
                          style: TextStyle(color: _dark),
                        ),
                        onTap: () => Navigator.pushNamed(context, '/signup'),
                      ),
                    ];
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.0),
                  child: Icon(Icons.account_circle, size: 30, color: _offWhite),
                ),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 760;

                final imagePanel = Container(
                  constraints: BoxConstraints(
                    minHeight: isWide ? 420 : 300,
                    minWidth: isWide ? 360 : constraints.maxWidth,
                  ),
                  decoration: BoxDecoration(
                    color: _taupe.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _taupe),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Image.network(
                    (product.imageUrl != null && product.imageUrl!.isNotEmpty)
                        ? product.imageUrl!
                        : _coverUrl(product.name),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Center(
                      child: Icon(
                        Icons.menu_book_rounded,
                        size: 110,
                        color: _medium,
                      ),
                    ),
                  ),
                );

                final detailPanel = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isLoadingProduct)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: LinearProgressIndicator(
                          minHeight: 2,
                          color: _dark,
                          backgroundColor: _taupe,
                        ),
                      ),
                    Text(
                      product.name,
                      style: const TextStyle(
                        color: _dark,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        if (product.discountedPrice != null && product.discountedPrice! < product.price) ...[
                          Text(
                            '\$${product.discountedPrice!.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '\$${product.price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 18,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${((product.price - product.discountedPrice!) / product.price * 100).round()}% OFF',
                              style: TextStyle(
                                color: Colors.red.shade800,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ] else ...[
                          Text(
                            '\$${product.price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: _dark,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                        const SizedBox(width: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: hasStock
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: hasStock
                                  ? Colors.green.shade300
                                  : Colors.red.shade300,
                            ),
                          ),
                          child: Text(
                            hasStock
                                ? '${product.stockQuantity} in stock'
                                : 'Out of stock',
                            style: TextStyle(
                              color: hasStock
                                  ? Colors.green.shade800
                                  : Colors.red.shade700,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            product.description,
                            style: const TextStyle(
                              color: _medium,
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildStarIndicator(_avgRating),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildCartControls(hasStock),
                    const SizedBox(height: 48),
                    _buildReviewsSection(),
                  ],
                );

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 4, child: imagePanel),
                      const SizedBox(width: 28),
                      Expanded(flex: 5, child: detailPanel),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    imagePanel,
                    const SizedBox(height: 24),
                    detailPanel,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCartControls(bool hasStock) {
    if (!hasStock) {
      return SizedBox(
        height: 48,
        width: 220,
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _dark,
            disabledBackgroundColor: _taupe,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Out of Stock',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _QuantityButton(
          icon: Icons.remove,
          onPressed: () {
            int current = int.tryParse(_quantityController.text) ?? 1;
            _changeQuantity(current - 1);
          },
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          height: 48,
          child: TextField(
            controller: _quantityController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            textAlignVertical: TextAlignVertical.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _dark,
            ),
            onChanged: (val) {
              int? parsed = int.tryParse(val);
              if (parsed != null) {
                _selectedQuantity = parsed.clamp(
                  1,
                  _displayProduct.stockQuantity,
                );
              }
            },
            decoration: InputDecoration(
              contentPadding: EdgeInsets.zero,
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: _dark),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: _dark, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _QuantityButton(
          icon: Icons.add,
          onPressed: () {
            int current = int.tryParse(_quantityController.text) ?? 1;
            _changeQuantity(current + 1);
          },
        ),
        const SizedBox(width: 24),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _addToCart,
            style: ElevatedButton.styleFrom(
              backgroundColor: _dark,
              foregroundColor: _offWhite,
              padding: const EdgeInsets.symmetric(horizontal: 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Add to Cart',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 48,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _toggleWishlist,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _inWishlist ? 1.0 : 0.35,
                child: Container(
                  width: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _inWishlist ? Colors.red.shade50 : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _inWishlist ? Colors.red : _dark,
                    ),
                  ),
                  child: Icon(
                    _inWishlist ? Icons.favorite : Icons.favorite_border,
                    color: _inWishlist ? Colors.red : _dark.withOpacity(0.9),
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStarIndicator(double avg) {
    final rounded = _normalizeRating(avg);
    final whole = rounded.floor();
    final hasHalf = (rounded - whole) >= 0.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: List.generate(5, (i) {
            if (i < whole) return const Icon(Icons.star, color: _dark, size: 16);
            if (i == whole && hasHalf) return const Icon(Icons.star_half, color: _dark, size: 16);
            return const Icon(Icons.star_border, color: _dark, size: 16);
          }),
        ),
        const SizedBox(width: 6),
        Text(
          '${avg.toStringAsFixed(1)} ($_ratingCount)',
          style: const TextStyle(color: _dark, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildReviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Comments & Ratings',
          style: TextStyle(color: _dark, fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 24),
        _buildReviewFormOrStatus(),
        const SizedBox(height: 24),
        _buildReviewsList(),
      ],
    );
  }

  Widget _buildReviewFormOrStatus() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _taupe),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: _medium, size: 18),
            const SizedBox(width: 10),
            const Text('Log in to leave a rating or comment.',
                style: TextStyle(color: _medium, fontSize: 13)),
          ],
        ),
      );
    }

    if (_isLoadingMyReview) {
      return const SizedBox(
        height: 40,
        child: Center(child: CircularProgressIndicator(color: _dark, strokeWidth: 2)),
      );
    }

    if (_myReview != null) {
      final status = _myReview!.status;
      if (status == 'pending') {
        return _buildStatusBanner(
          icon: Icons.hourglass_top_rounded,
          color: Colors.orange,
          message: 'Your review is awaiting approval.',
        );
      } else if (status == 'rejected') {
        return _buildStatusBanner(
          icon: Icons.cancel_outlined,
          color: Colors.red,
          message: 'Your review was not approved.',
        );
      }
      return const SizedBox.shrink();
    }

    // No review yet — show the form
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _taupe),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Leave a Review',
              style: TextStyle(color: _dark, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Rating (optional):',
                  style: TextStyle(color: _medium, fontSize: 13)),
              const SizedBox(width: 12),
              Row(
                children: List.generate(5, (i) {
                  return GestureDetector(
                    onTap: () => setState(() => _formRating = i + 1 == _formRating ? 0 : i + 1),
                    child: Icon(
                      i < _formRating ? Icons.star : Icons.star_border,
                      color: _dark,
                      size: 28,
                    ),
                  );
                }),
              ),
              if (_formRating > 0) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _formRating = 0),
                  child: const Text('clear', style: TextStyle(color: _medium, fontSize: 12)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _commentController,
            maxLines: 3,
            style: const TextStyle(color: _dark, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Write a comment (optional)…',
              hintStyle: const TextStyle(color: _medium),
              filled: true,
              fillColor: _offWhite,
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _taupe)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _taupe)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _dark, width: 1.5)),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReview,
              style: ElevatedButton.styleFrom(
                backgroundColor: _dark,
                foregroundColor: _offWhite,
                disabledBackgroundColor: _taupe,
                padding: const EdgeInsets.symmetric(horizontal: 28),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(color: _offWhite, strokeWidth: 2))
                  : const Text('Submit Review'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner({
    required IconData icon,
    required Color color,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Text(message, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  

  Widget _buildReviewsList() {
    if (_isLoadingReviews) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(color: _dark),
      );
    }

    if (_reviews.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _cream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _taupe),
        ),
        child: const Center(
          child: Text(
            'No reviews yet. Be the first to leave one!',
            style: TextStyle(color: _medium, fontSize: 14),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _reviews.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final review = _reviews[index];
        return _buildReviewCard(review);
      },
    );
  }

  Widget _buildReviewCard(ProductReview review) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _offWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _taupe),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    review.customerName,
                    style: const TextStyle(
                      color: _dark,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    review.customerEmail,
                    style: const TextStyle(
                      color: _medium,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (review.rating != null && review.rating! > 0)
                Row(
                  children: List.generate(5, (i) {
                    return Icon(
                      i < review.rating! ? Icons.star : Icons.star_border,
                      color: _dark,
                      size: 16,
                    );
                  }),
                ),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              review.comment!,
              style: const TextStyle(
                color: _dark,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            _formatDate(review.createdAt),
            style: const TextStyle(
              color: _medium,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _QuantityButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          side: const BorderSide(color: _dark),
          foregroundColor: _dark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }
}
