import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/product.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/product_service.dart';

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

  Product? _backendProduct;
  int _quantityInCart = 0;
  bool _isBusy = true;
  bool _isLoadingProduct = true;

  @override
  void initState() {
    super.initState();
    _loadProductFromBackend();
    _loadCurrentQuantity();
  }

  Product get _displayProduct => _backendProduct ?? widget.product;

  Future<void> _loadProductFromBackend() async {
    final fetchedProduct = await _productService.fetchProductById(widget.product.id);

    if (!mounted) return;
    setState(() {
      _backendProduct = fetchedProduct ?? widget.product;
      _isLoadingProduct = false;
    });
  }

  Future<void> _loadCurrentQuantity() async {
    final items = await _cartService.fetchCartItems();
    final matched = items.where((i) => i.product.id == _displayProduct.id).firstOrNull;

    if (!mounted) return;
    setState(() {
      _quantityInCart = matched?.quantity ?? 0;
      _isBusy = false;
    });
  }

  Future<void> _addFirstItem() async {
    final product = _displayProduct;
    if (product.stockQuantity <= 0 || _isBusy) return;

    setState(() => _isBusy = true);
    await _cartService.addOrIncrementItem(product.id);
    await _loadCurrentQuantity();

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} added to cart.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _changeQuantityBy(int delta) async {
    if (_isBusy) return;

    final product = _displayProduct;

    final nextQuantity = (_quantityInCart + delta).clamp(0, product.stockQuantity);
    if (nextQuantity == _quantityInCart) return;

    setState(() => _isBusy = true);
    final result = await _cartService.updateQuantity(
      productId: product.id,
      requestedQuantity: nextQuantity,
    );

    final matched = result.items.where((i) => i.product.id == product.id).firstOrNull;

    if (!mounted) return;
    setState(() {
      _quantityInCart = matched?.quantity ?? 0;
      _isBusy = false;
    });
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
                              fontWeight: FontWeight.bold, color: _dark),
                        ),
                      ),
                      PopupMenuItem(
                        child: const Text('Profile',
                            style: TextStyle(color: _dark)),
                        onTap: () => Navigator.pushNamed(context, '/profile'),
                      ),
                      PopupMenuItem(
                        child: const Text('Logout',
                            style: TextStyle(color: Colors.red)),
                        onTap: () async => await AuthService().signOut(),
                      ),
                    ];
                  } else {
                    return [
                      PopupMenuItem(
                        child: const Text('Login',
                            style: TextStyle(color: _dark)),
                        onTap: () => Navigator.pushNamed(context, '/login'),
                      ),
                      PopupMenuItem(
                        child: const Text('Sign Up',
                            style: TextStyle(color: _dark)),
                        onTap: () => Navigator.pushNamed(context, '/signup'),
                      ),
                    ];
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.0),
                  child: Icon(Icons.account_circle,
                      size: 30, color: _offWhite),
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
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: hasStock ? Colors.green.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: hasStock ? Colors.green.shade300 : Colors.red.shade300,
                            ),
                          ),
                          child: Text(
                            hasStock
                                ? '${product.stockQuantity} in stock'
                                : 'Out of stock',
                            style: TextStyle(
                              color: hasStock ? Colors.green.shade800 : Colors.red.shade700,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      product.description,
                      style: const TextStyle(
                        color: _medium,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _buildCartControls(hasStock),
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
    if (_isBusy) {
      return const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator(color: _dark)),
      );
    }

    if (_quantityInCart <= 0) {
      return SizedBox(
        height: 48,
        width: 220,
        child: ElevatedButton(
          onPressed: hasStock ? _addFirstItem : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _dark,
            foregroundColor: _offWhite,
            disabledBackgroundColor: _taupe,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(hasStock ? 'Add to Cart' : 'Out of Stock'),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _QuantityButton(
          icon: Icons.remove,
          onPressed: () => _changeQuantityBy(-1),
        ),
        Container(
          width: 64,
          height: 44,
          alignment: Alignment.center,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _cream,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _taupe),
          ),
          child: Text(
            '$_quantityInCart',
            style: const TextStyle(
              color: _dark,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ),
        _QuantityButton(
          icon: Icons.add,
          onPressed: _quantityInCart >= widget.product.stockQuantity
              ? null
              : () => _changeQuantityBy(1),
        ),
      ],
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _QuantityButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
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
