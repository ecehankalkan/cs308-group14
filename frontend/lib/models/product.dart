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
  final String warrantyInfo;
  final String distributor;
  final int stockQuantity;
  final DeweyCategory category;

  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.warrantyInfo,
    required this.distributor,
    required this.stockQuantity,
    required this.category,
  });

  // TODO: replace with Firestore: Product.fromFirestore(DocumentSnapshot doc)
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'].toString(),
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      price: double.tryParse(map['price'].toString()) ?? 0.0,
      warrantyInfo: (map['warranty_status'] is bool)
          ? (map['warranty_status'] ? 'Available' : 'None')
          : (map['warranty_status']?.toString() ?? map['warrantyInfo']?.toString() ?? 'Standard Warranty'),
      distributor: map['distributor_info']?.toString() ?? map['distributor']?.toString() ?? 'Default Distributor',
      stockQuantity: map['stock_quantity'] as int? ?? map['stockQuantity'] as int? ?? 0,
      category: _parseCategory(map['category']),
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
