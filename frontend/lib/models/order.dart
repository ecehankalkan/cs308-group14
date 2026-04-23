class OrderItem {
  final String productName;
  final int quantity;
  final double unitPrice;

  const OrderItem({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  double get subtotal => unitPrice * quantity;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productName: json['product_name'] as String? ?? 'Unknown Product',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: double.tryParse(json['unit_price']?.toString() ?? '') ?? 0.0,
    );
  }
}

class Order {
  final String orderId;
  final DateTime createdAt;
  final List<OrderItem> items;
  final double totalAmount;
  final String deliveryAddress;
  final String status;

  const Order({
    required this.orderId,
    required this.createdAt,
    required this.items,
    required this.totalAmount,
    required this.deliveryAddress,
    this.status = '',
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List<dynamic>? ?? [];
    return Order(
      orderId: json['id']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      items: itemsJson
          .map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
          .toList(),
      totalAmount: double.tryParse(json['total_amount']?.toString() ?? '') ?? 0.0,
      deliveryAddress: json['delivery_address'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }
}
