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
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      price: (map['price'] as num).toDouble(),
      warrantyInfo: map['warrantyInfo'] as String,
      distributor: map['distributor'] as String,
      stockQuantity: map['stockQuantity'] as int,
      category: DeweyCategory.values.byName(map['category'] as String),
    );
  }
}
