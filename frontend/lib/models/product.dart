enum DeweyCategory {
  generalWorks,   // 000s
  philosophy,     // 100s
  religion,       // 200s
  socialSciences, // 300s
  language,       // 400s
  pureScience,    // 500s
  technology,     // 600s
  arts,           // 700s
  literature,     // 800s
  history,        // 900s
}

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final double? discountedPrice;
  final String warrantyInfo;
  final String distributor;
  final int stockQuantity;
  final DeweyCategory category;
  final double? averageRating;
  final int ratingCount;

  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.discountedPrice,
    required this.warrantyInfo,
    required this.distributor,
    required this.stockQuantity,
    required this.category,
    this.averageRating,
    this.ratingCount = 0,
  });

  // TODO: replace with Firestore: Product.fromFirestore(DocumentSnapshot doc)
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'].toString(),
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      price: double.tryParse(map['price'].toString()) ?? 0.0,
      discountedPrice: map['discounted_price'] != null
          ? double.tryParse(map['discounted_price'].toString())
          : null,
      warrantyInfo: (map['warranty_status'] is bool)
          ? (map['warranty_status'] ? 'Available' : 'None')
          : (map['warranty_status']?.toString() ?? map['warrantyInfo']?.toString() ?? 'Standard Warranty'),
      distributor: map['distributor_info']?.toString() ?? map['distributor']?.toString() ?? 'Default Distributor',
      stockQuantity: map['stock_quantity'] as int? ?? map['stockQuantity'] as int? ?? 0,
      category: _parseCategory(map['category']),
      averageRating: map['average_rating'] != null
          ? double.tryParse(map['average_rating'].toString())
          : null,
      ratingCount: map['rating_count'] as int? ?? 0,
    );
  }

  static DeweyCategory _parseCategory(dynamic cat) {
    if (cat == null) return DeweyCategory.literature;
    for (var value in DeweyCategory.values) {
      if (value.name == cat) return value;
    }
    return DeweyCategory.literature;
  }
}
