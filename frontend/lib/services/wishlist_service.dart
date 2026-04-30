import '../models/product.dart';

class WishlistService {
  static final Map<String, Product> _items = {};

  List<Product> get items => List.unmodifiable(_items.values);

  bool contains(String productId) => _items.containsKey(productId);

  void add(Product product) {
    _items[product.id] = product;
  }

  void remove(String productId) {
    _items.remove(productId);
  }

  void clear() {
    _items.clear();
  }
}
