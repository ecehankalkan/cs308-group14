import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../models/product.dart';

const _dark = Color(0xFF8D7B68);
const _medium = Color(0xFFA4907C);
const _taupe = Color(0xFFC8B6A6);
const _cream = Color(0xFFF1DEC9);
const _offWhite = Color(0xFFFAF5EF);

// TODO: replace with Firestore query
const List<Product> _placeholderProducts = [
  Product(
    id: '1',
    name: 'The Midnight Library',
    description: 'A novel about infinite possibilities and second chances, by Matt Haig.',
    price: 14.99,
    warrantyInfo: 'Satisfaction guaranteed or full refund within 30 days.',
    distributor: 'Penguin Random House',
    stockQuantity: 42,
    category: DeweyCategory.literature,
  ),
  Product(
    id: '2',
    name: 'Atomic Habits',
    description: 'An easy and proven way to build good habits and break bad ones, by James Clear.',
    price: 16.99,
    warrantyInfo: 'Satisfaction guaranteed or full refund within 30 days.',
    distributor: 'Penguin Random House',
    stockQuantity: 78,
    category: DeweyCategory.philosophy,
  ),
  Product(
    id: '3',
    name: 'Dune',
    description: 'Frank Herbert\'s epic science fiction saga set on the desert planet Arrakis.',
    price: 12.99,
    warrantyInfo: 'Satisfaction guaranteed or full refund within 30 days.',
    distributor: 'Ace Books',
    stockQuantity: 55,
    category: DeweyCategory.pureScience,
  ),
  Product(
    id: '4',
    name: '1984',
    description: 'George Orwell\'s haunting vision of a totalitarian future society.',
    price: 10.99,
    warrantyInfo: 'Satisfaction guaranteed or full refund within 30 days.',
    distributor: 'Signet Classic',
    stockQuantity: 91,
    category: DeweyCategory.socialSciences,
  ),
  Product(
    id: '5',
    name: 'The Alchemist',
    description: 'Paulo Coelho\'s beloved novel about following your dreams and listening to your heart.',
    price: 11.99,
    warrantyInfo: 'Satisfaction guaranteed or full refund within 30 days.',
    distributor: 'HarperCollins',
    stockQuantity: 63,
    category: DeweyCategory.literature,
  ),
  Product(
    id: '6',
    name: 'Sapiens',
    description: 'A brief history of humankind by Yuval Noah Harari.',
    price: 17.99,
    warrantyInfo: 'Satisfaction guaranteed or full refund within 30 days.',
    distributor: 'Harper Perennial',
    stockQuantity: 37,
    category: DeweyCategory.history,
  ),
];

const Map<DeweyCategory, Color> _categoryColors = {
  DeweyCategory.generalWorks:   Color(0xFF5C7A9E),
  DeweyCategory.philosophy:     Color(0xFF7B5EA7),
  DeweyCategory.religion:       Color(0xFFB07D4A),
  DeweyCategory.socialSciences: Color(0xFF4A8B6F),
  DeweyCategory.language:       Color(0xFF3A8FA8),
  DeweyCategory.pureScience:    Color(0xFF2E7D6B),
  DeweyCategory.technology:     Color(0xFF5A6E8A),
  DeweyCategory.arts:           Color(0xFFC0534A),
  DeweyCategory.literature:     Color(0xFF8D7B68),
  DeweyCategory.history:        Color(0xFF7A6E4A),
};

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _offWhite,
      appBar: AppBar(
        backgroundColor: _dark,
        elevation: 0,
        title: const Text(
          'inkcloud',
          style: TextStyle(
            color: _offWhite,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined, color: _offWhite),
            tooltip: 'Cart',
            onPressed: () => Navigator.pushNamed(context, '/cart'),
          ),
          StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              final user = snapshot.data;
              return PopupMenuButton(
                color: _offWhite,
                itemBuilder: (context) {
                  if (user != null) {
                    return [
                      PopupMenuItem(
                        enabled: false,
                        child: Text(
                          'Hi, ${user.displayName ?? 'User'}!',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: _dark),
                        ),
                      ),
                      PopupMenuItem(
                        child: const Text('My Account',
                            style: TextStyle(color: _dark)),
                        onTap: () =>
                            Navigator.pushNamed(context, '/profile'),
                      ),
                      PopupMenuItem(
                        child: const Text('Logout',
                            style: TextStyle(color: Colors.red)),
                        onTap: () async => await AuthService().signOut(),
                      ),
                    ];
                  } else {
                    return [
                      PopupMenuItem(
                        child: const Text('Login',
                            style: TextStyle(color: _dark)),
                        onTap: () =>
                            Navigator.pushNamed(context, '/login'),
                      ),
                      PopupMenuItem(
                        child: const Text('Sign Up',
                            style: TextStyle(color: _dark)),
                        onTap: () =>
                            Navigator.pushNamed(context, '/signup'),
                      ),
                    ];
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.0),
                  child: Icon(Icons.account_circle,
                      size: 30, color: _offWhite),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeroSection(),
            _FeaturesSection(),
            _FeaturedBooksSection(),
            _CategoriesSection(),
            _Footer(),
          ],
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/library.jpg'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Color(0xAA000000),
            BlendMode.darken,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 100, horizontal: 48),
      child: Column(
        children: [
          const Text(
            '"There is no friend\nas loyal as a book."',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _offWhite,
              fontSize: 48,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '— Ernest Hemingway\n\nDiscover your next favourite read. Thousands of titles,\ndelivered to your door.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _cream, fontSize: 18, height: 1.6),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: _dark,
              foregroundColor: _offWhite,
              padding: const EdgeInsets.symmetric(
                  horizontal: 40, vertical: 18),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('Browse Books',
                style: TextStyle(fontSize: 16, letterSpacing: 1)),
          ),
        ],
      ),
    );
  }
}

class _FeaturesSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final features = [
      (Icons.local_shipping_outlined, 'Free Shipping',
          'On all orders over \$30'),
      (Icons.verified_outlined, 'Curated Selection',
          'Hand-picked titles across every genre'),
      (Icons.replay_outlined, 'Easy Returns',
          '30-day hassle-free return policy'),
      (Icons.headset_mic_outlined, '24/7 Support',
          'We\'re here whenever you need us'),
    ];

    return Container(
      color: _offWhite,
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 48),
      child: Wrap(
        spacing: 32,
        runSpacing: 32,
        alignment: WrapAlignment.center,
        children: features
            .map((f) => SizedBox(
                  width: 220,
                  child: Column(
                    children: [
                      Icon(f.$1, color: _medium, size: 36),
                      const SizedBox(height: 12),
                      Text(f.$2,
                          style: const TextStyle(
                              color: _dark,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(f.$3,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: _medium, fontSize: 13)),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _FeaturedBooksSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: _cream,
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 48),
      child: Column(
        children: [
          const Text(
            'Featured Books',
            style: TextStyle(
              color: _dark,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Handpicked favourites from our collection',
            style: TextStyle(color: _medium, fontSize: 15),
          ),
          const SizedBox(height: 40),
          Wrap(
            spacing: 24,
            runSpacing: 24,
            alignment: WrapAlignment.center,
            children: _placeholderProducts
                .map((p) => _ProductCard(product: p))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: _offWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: _categoryColors[product.category]!, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Book cover placeholder
          Container(
            height: 180,
            decoration: const BoxDecoration(
              color: _taupe,
              borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: const Center(
              child: Icon(Icons.menu_book, color: _offWhite, size: 64),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _categoryColors[product.category],
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  product.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _medium, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '\$${product.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: _dark,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      product.stockQuantity > 0
                          ? 'In stock'
                          : 'Out of stock',
                      style: TextStyle(
                        color: product.stockQuantity > 0
                            ? Colors.green.shade700
                            : Colors.red.shade400,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: product.stockQuantity > 0 ? () async {
                      try {
                        await CartService().updateQuantity(productId: product.id, requestedQuantity: 1);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${product.name} added to cart!'), backgroundColor: Colors.green));
                        }
                      } catch (e) {
                         if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add ${product.name} '), backgroundColor: Colors.red));
                         }
                      }
                    } : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _dark,
                      foregroundColor: _offWhite,
                      disabledBackgroundColor: _taupe,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                    ),
                    child: const Text('Add to Cart',
                        style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoriesSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final categories = [
      ('000s · General Works',  Icons.public_outlined,                 const Color(0xFF5C7A9E)),
      ('100s · Philosophy',     Icons.psychology_outlined,             const Color(0xFF7B5EA7)),
      ('200s · Religion',       Icons.temple_hindu_outlined,           const Color(0xFFB07D4A)),
      ('300s · Social Sciences',Icons.groups_outlined,                 const Color(0xFF4A8B6F)),
      ('400s · Language',       Icons.translate_outlined,              const Color(0xFF3A8FA8)),
      ('500s · Pure Science',   Icons.science_outlined,                const Color(0xFF2E7D6B)),
      ('600s · Technology',     Icons.precision_manufacturing_outlined,const Color(0xFF5A6E8A)),
      ('700s · Arts & Recreation',Icons.palette_outlined,              const Color(0xFFC0534A)),
      ('800s · Literature',     Icons.auto_stories_outlined,           const Color(0xFF8D7B68)),
      ('900s · History & Geography',Icons.travel_explore_outlined,     const Color(0xFF7A6E4A)),
    ];

    return Container(
      color: _offWhite,
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 48),
      child: Column(
        children: [
          const Text(
            'Browse by Category',
            style: TextStyle(
              color: _dark,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 40),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            alignment: WrapAlignment.center,
            children: categories
                .map((cat) => InkWell(
                      onTap: () {},
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 160,
                        height: 130,
                        decoration: BoxDecoration(
                          color: cat.$3.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: cat.$3.withValues(alpha: 0.4), width: 1.5),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(cat.$2, color: cat.$3, size: 36),
                            const SizedBox(height: 12),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                cat.$1,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: cat.$3,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: _dark,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 48),
      child: const Text(
        '© 2026 inkcloud. All rights reserved.',
        textAlign: TextAlign.center,
        style: TextStyle(color: _taupe, fontSize: 13),
      ),
    );
  }
}
