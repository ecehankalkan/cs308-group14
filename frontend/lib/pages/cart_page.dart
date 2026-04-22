import 'package:flutter/material.dart';
import '../services/cart_service.dart';
import 'payment_page.dart';
import 'product_page.dart';

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
  bool _isPaymentConfirmed = false;
  bool _showPaymentConfirmationWarning = false;
  List<CartItem> _items = [];
  List<CartItem> _initialItems = [];
  final Map<int, TextEditingController> _stepControllers = {};

  @override
  void dispose() {
    for (var controller in _stepControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  Future<void> _loadCart() async {
    await _cartService.waitForPending();
    final items = await _cartService.fetchCartItems();
    if (!mounted) {
      return;
    }
    setState(() {
      _items = List.from(items);
      _initialItems = List.from(items);
      _isLoading = false;
    });
  }

  void _changeQuantity(CartItem item, int nextQuantity) {
    setState(() {
      if (nextQuantity <= 0) {
        _items.removeWhere((i) => i.cartItemId == item.cartItemId);
      } else {
        final index = _items.indexWhere((i) => i.cartItemId == item.cartItemId);
        if (index != -1) {
          _items[index] = _items[index].copyWith(quantity: nextQuantity);
        }
      }
    });
  }

  Future<void> _syncCartWithBackend() async {
    setState(() => _isLoading = true);
    for (final initialItem in _initialItems) {
      final currentMatch = _items.where((i) => i.cartItemId == initialItem.cartItemId).firstOrNull;
      if (currentMatch == null) {
        try { await _cartService.updateQuantity(productId: initialItem.product.id, requestedQuantity: 0); } catch (_) {}
      } else if (currentMatch.quantity != initialItem.quantity) {
        try { await _cartService.updateQuantity(productId: initialItem.product.id, requestedQuantity: currentMatch.quantity); } catch (_) {}
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
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

  Future<void> _handlePaymentPress() async {
    final isAuthed = await _cartService.isLoggedIn();
    if (!isAuthed) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: _cream,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text('Account Required', style: TextStyle(color: _dark, fontWeight: FontWeight.w800)),
            content: const Text('Please login or create a new account to proceed to checkout.', style: TextStyle(color: _dark)),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/login');
                },
                child: const Text('Login', style: TextStyle(color: _dark, fontWeight: FontWeight.w700)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _dark,
                  foregroundColor: _offWhite,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/signup');
                },
                child: const Text('Sign Up'),
              ),
            ],
          );
        },
      );
      return;
    }

    if (!_isPaymentConfirmed) {
      setState(() {
        _showPaymentConfirmationWarning = true;
      });
      return;
    }

    setState(() {
      _showPaymentConfirmationWarning = false;
    });

    await _syncCartWithBackend();
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PaymentPage(totalAmount: _cartTotal),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _syncCartWithBackend();
        if (context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: _offWhite,
        appBar: AppBar(
          backgroundColor: _dark,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: _offWhite),
            onPressed: () async {
              await _syncCartWithBackend();
              if (context.mounted) Navigator.pop(context);
            },
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
      ),
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

              if (!_stepControllers.containsKey(item.cartItemId)) {
                _stepControllers[item.cartItemId] = TextEditingController();
              }
              final controller = _stepControllers[item.cartItemId]!;

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProductPage(
                        product: product,
                      ),
                    ),
                  );
                },
                child: Container(
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: _taupe.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.inventory_2_outlined, color: _dark),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
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
                                const SizedBox(height: 4),
                                Text(
                                  'ID: ${product.id}',
                                  style: const TextStyle(color: _medium, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _changeQuantity(item, 0),
                          ),
                        ],
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
                            'Qty: ${item.quantity}',
                            style: const TextStyle(
                              color: _dark,
                              fontWeight: FontWeight.w700,
                            ),
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
                            onPressed: () {
                                    int step = int.tryParse(controller.text) ?? 1;
                                    step = step <= 0 ? 1 : step;
                                    _changeQuantity(item, item.quantity - step);
                                  },
                          ),
                          Container(
                            width: 60,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: TextField(
                              controller: controller,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _dark),
                              decoration: const InputDecoration(
                                hintText: '1',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 8),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          _QuantityButton(
                            icon: Icons.add,
                            onPressed: () {
                                    int step = int.tryParse(controller.text) ?? 1;
                                    step = step <= 0 ? 1 : step;
                                    _changeQuantity(item, item.quantity + step);
                                  },
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
              const SizedBox(height: 20),
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
                  onPressed: _isPaymentConfirmed ? _handlePaymentPress : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isPaymentConfirmed ? _dark : _taupe,
                    disabledBackgroundColor: _taupe,
                    foregroundColor: _offWhite,
                    disabledForegroundColor: _offWhite.withOpacity(0.7),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    'Continue',
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
