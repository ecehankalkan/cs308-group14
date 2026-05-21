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
  final bool isActive;
  final String? imageUrl;

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
    this.isActive = true,
    this.imageUrl,
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
      isActive: map['is_active'] as bool? ?? true,
      imageUrl: map['image_url'] as String?,
    );
  }

  static DeweyCategory _parseCategory(dynamic cat) {
    if (cat == null) return DeweyCategory.literature;
    for (var value in DeweyCategory.values) {
      if (value.name == cat) return value;
    }
    return DeweyCategory.literature;
  }

  Product copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    double? discountedPrice,
    String? warrantyInfo,
    String? distributor,
    int? stockQuantity,
    DeweyCategory? category,
    double? averageRating,
    int? ratingCount,
    bool? isActive,
    String? imageUrl,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      discountedPrice: discountedPrice ?? this.discountedPrice,
      warrantyInfo: warrantyInfo ?? this.warrantyInfo,
      distributor: distributor ?? this.distributor,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      category: category ?? this.category,
      averageRating: averageRating ?? this.averageRating,
      ratingCount: ratingCount ?? this.ratingCount,
      isActive: isActive ?? this.isActive,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
