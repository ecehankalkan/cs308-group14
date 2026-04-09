import 'package:flutter/material.dart';
import '../services/cart_service.dart';

const _dark = Color(0xFF8D7B68);
const _medium = Color(0xFFA4907C);
const _taupe = Color(0xFFC8B6A6);
const _cream = Color(0xFFF1DEC9);
const _offWhite = Color(0xFFFAF5EF);

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final CartService _cartService = CartService();
  bool _isLoading = true;
  bool _isUpdating = false;
  bool _isPaymentConfirmed = false;
  bool _showPaymentConfirmationWarning = false;
  List<CartItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  Future<void> _loadCart() async {
    final items = await _cartService.fetchCartItems();
    if (!mounted) {
      return;
    }
    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  Future<void> _changeQuantity(CartItem item, int nextQuantity) async {
    if (_isUpdating) {
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    final result = await _cartService.updateQuantity(
      productId: item.product.id,
      requestedQuantity: nextQuantity,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _items = result.items;
      _isUpdating = false;
    });

    if (result.adjustedToStock) {
      _showCenteredRedSnackBar('Quantity adjusted to available stock.');
    }
  }

  double get _cartTotal {
    return _items.fold<double>(0, (sum, item) => sum + item.subtotal);
  }

  void _showCenteredRedSnackBar(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF8B0000),
              fontWeight: FontWeight.w700,
            ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFFFE6E6),
          elevation: 0,
          margin: EdgeInsets.fromLTRB(
            20,
            MediaQuery.of(context).size.height * 0.42,
            20,
            MediaQuery.of(context).size.height * 0.42,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Colors.red, width: 2),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _handlePaymentPress() {
    if (!_isPaymentConfirmed) {
      setState(() {
        _showPaymentConfirmationWarning = true;
      });
      return;
    }

    setState(() {
      _showPaymentConfirmationWarning = false;
    });

    _showCenteredRedSnackBar('Payment flow will be connected soon.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _offWhite,
      appBar: AppBar(
        backgroundColor: _dark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _offWhite),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Your Cart',
          style: TextStyle(
            color: _offWhite,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _dark),
            )
          : _items.isEmpty
              ? _buildEmptyState(context)
              : _buildCartContent(context),
    );
  }

  Widget _buildCartContent(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            itemCount: _items.length,
            separatorBuilder: (_, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = _items[index];
              final product = item.product;

              return Container(
                decoration: BoxDecoration(
                  color: _cream,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _taupe),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          color: _dark,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 18,
                        runSpacing: 8,
                        children: [
                          Text(
                            'Unit: \$${product.price.toStringAsFixed(2)}',
                            style: const TextStyle(color: _medium),
                          ),
                          Text(
                            'Stock: ${product.stockQuantity}',
                            style: const TextStyle(color: _medium),
                          ),
                          Text(
                            'Subtotal: \$${item.subtotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: _dark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _QuantityButton(
                            icon: Icons.remove,
                            onPressed: _isUpdating
                                ? null
                                : () => _changeQuantity(item, item.quantity - 1),
                          ),
                          Container(
                            width: 46,
                            alignment: Alignment.center,
                            child: Text(
                              '${item.quantity}',
                              style: const TextStyle(
                                color: _dark,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          _QuantityButton(
                            icon: Icons.add,
                            onPressed: _isUpdating
                                ? null
                                : () => _changeQuantity(item, item.quantity + 1),
                          ),
                          const Spacer(),
                          if (item.quantity >= product.stockQuantity)
                            const Text(
                              'Max stock reached',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          decoration: const BoxDecoration(
            color: _offWhite,
            border: Border(top: BorderSide(color: _taupe)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Cost',
                    style: TextStyle(
                      color: _dark,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '\$${_cartTotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: _dark,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Stock validation is simulated on every update.',
                  style: TextStyle(color: _medium, fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: _isPaymentConfirmed,
                    activeColor: _dark,
                    onChanged: (value) {
                      setState(() {
                        _isPaymentConfirmed = value ?? false;
                        if (_isPaymentConfirmed) {
                          _showPaymentConfirmationWarning = false;
                        }
                      });
                    },
                  ),
                  const Expanded(
                    child: Text(
                      'I confirm that I reviewed my order details.',
                      style: TextStyle(color: _medium, fontSize: 13),
                    ),
                  ),
                ],
              ),
              if (_showPaymentConfirmationWarning)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: 12, bottom: 8),
                    child: Text(
                      'Please check the confirmation box to continue.',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handlePaymentPress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isPaymentConfirmed ? _dark : _taupe,
                    foregroundColor: _offWhite,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    'Go to Payment',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shopping_cart_outlined, size: 80, color: _taupe),
            const SizedBox(height: 20),
            const Text(
              'Your cart is empty',
              style: TextStyle(
                color: _dark,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add a book from the home page to continue.',
              style: TextStyle(color: _medium),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _dark,
                foregroundColor: _offWhite,
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text('Continue Shopping'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _QuantityButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          side: const BorderSide(color: _dark),
          foregroundColor: _dark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}
