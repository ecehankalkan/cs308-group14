import '../models/product.dart';

class CartItem {
  final Product product;
  final int quantity;

  const CartItem({
    required this.product,
    required this.quantity,
  });

  double get subtotal => product.price * quantity;

  CartItem copyWith({
    Product? product,
    int? quantity,
  }) {
    return CartItem(
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

class MockCartService {
  MockCartService();

  final Map<String, Product> _products = {
    for (final product in _mockProducts) product.id: product,
  };

  final Map<String, int> _cartQuantities = {
    'book-1': 1,
    'book-2': 2,
  };

  Future<List<CartItem>> fetchCartItems() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return _buildItems();
  }

  Future<CartUpdateResult> updateQuantity({
    required String productId,
    required int requestedQuantity,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 140));

    final product = _products[productId];
    if (product == null) {
      return CartUpdateResult(items: _buildItems(), adjustedToStock: false);
    }

    // Simulates backend stock validation on each quantity update.
    final safeQuantity = requestedQuantity.clamp(0, product.stockQuantity);
    final adjusted = safeQuantity != requestedQuantity;

    if (safeQuantity == 0) {
      _cartQuantities.remove(productId);
    } else {
      _cartQuantities[productId] = safeQuantity;
    }

    return CartUpdateResult(items: _buildItems(), adjustedToStock: adjusted);
  }

  List<CartItem> _buildItems() {
    final items = <CartItem>[];

    for (final entry in _cartQuantities.entries) {
      final product = _products[entry.key];
      if (product == null) {
        continue;
      }

      final quantity = entry.value.clamp(0, product.stockQuantity);
      if (quantity <= 0 || product.stockQuantity <= 0) {
        continue;
      }

      items.add(CartItem(product: product, quantity: quantity));
    }

    return items;
  }
}

const List<Product> _mockProducts = [
  Product(
    id: 'book-1',
    name: 'The Midnight Library',
    description: 'Matt Haig\'s novel about second chances.',
    price: 14.99,
    warrantyInfo: '30-day satisfaction guarantee.',
    distributor: 'Penguin Random House',
    stockQuantity: 5,
    category: DeweyCategory.literature,
  ),
  Product(
    id: 'book-2',
    name: 'Atomic Habits',
    description: 'James Clear\'s guide to building better habits.',
    price: 16.99,
    warrantyInfo: '30-day satisfaction guarantee.',
    distributor: 'Avery',
    stockQuantity: 3,
    category: DeweyCategory.philosophy,
  ),
];