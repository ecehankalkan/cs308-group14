import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/product.dart';
import '../models/review.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/product_service.dart';
import '../services/wishlist_service.dart';
import '../services/review_service.dart';

const _dark = Color(0xFF8D7B68);
const _medium = Color(0xFFA4907C);
const _taupe = Color(0xFFC8B6A6);
const _cream = Color(0xFFF1DEC9);
const _offWhite = Color(0xFFFAF5EF);

class ProductPage extends StatefulWidget {
  final Product product;

  const ProductPage({super.key, required this.product});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final CartService _cartService = CartService();
  final ProductService _productService = ProductService();
  final WishlistService _wishlistService = WishlistService();
  final ReviewService _reviewService = ReviewService();
  final TextEditingController _quantityController = TextEditingController(
    text: '1',
  );

  Product? _backendProduct;
  int _selectedQuantity = 1;
  bool _isLoadingProduct = true;
  List<ProductReview> _reviews = [];
  bool _isLoadingReviews = true;
  double _avgRating = 0.0;

  double _normalizeRating(double? value) {
    if (value == null || value.isNaN || value.isInfinite) return 0.0;
    final clamped = value.clamp(0.0, 5.0);
    return (clamped * 2).round() / 2.0;
  }

  @override
  void initState() {
    super.initState();
    _loadProductFromBackend();
    _loadReviews();
  }

  @override
  void dispose() {
    _quantityController.dispose();
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
    });
  }

  Future<void> _loadReviews() async {
    try {
      final productId = int.tryParse(widget.product.id) ?? 0;
      final reviews = await _reviewService.fetchProductReviews(productId);
      if (mounted) {
        setState(() {
          _reviews = reviews;
          // compute average rating rounded to nearest 0.5
          final ratings = _reviews.where((r) => r.rating != null).map((r) => r.rating!.toDouble()).toList();
          if (ratings.isEmpty) {
            _avgRating = 0.0;
          } else {
            final sum = ratings.reduce((a, b) => a + b);
            final avg = sum / ratings.length;
            _avgRating = _normalizeRating(avg);
          }
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
                    color: _cream,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _taupe),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.menu_book_rounded,
                      size: 110,
                      color: _medium,
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
                        Text(
                          '\$${product.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: _dark,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
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
          child: OutlinedButton(
            onPressed: () {
              _wishlistService.add(_displayProduct);
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${_displayProduct.name} added to wishlist!'),
                  backgroundColor: _dark,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: _dark,
              side: const BorderSide(color: _dark),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Add to Wishlist',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
          avg.toStringAsFixed(1),
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
          style: TextStyle(
            color: _dark,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 24),
        const SizedBox(height: 8),
        _buildReviewsList(),
      ],
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
