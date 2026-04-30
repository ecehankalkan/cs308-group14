class ProductReview {
  final int id;
  final int product;
  final int customer;
  final String customerName;
  final String customerEmail;
  final int? rating;
  final String? comment;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductReview({
    required this.id,
    required this.product,
    required this.customer,
    required this.customerName,
    required this.customerEmail,
    this.rating,
    this.comment,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProductReview.fromJson(Map<String, dynamic> json) {
    return ProductReview(
      id: json['id'] ?? 0,
      product: json['product'] ?? 0,
      customer: json['customer'] ?? 0,
      customerName: json['customer_name'] ?? 'Anonymous',
      customerEmail: json['customer_email'] ?? '',
      rating: json['rating'],
      comment: json['comment'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product': product,
      'customer': customer,
      'customer_name': customerName,
      'customer_email': customerEmail,
      'rating': rating,
      'comment': comment,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
