import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/product_service.dart';
import '../models/product.dart';
import 'product_page.dart';

const _dark = Color(0xFF8D7B68);
const _medium = Color(0xFFA4907C);
const _taupe = Color(0xFFC8B6A6);
const _cream = Color(0xFFF1DEC9);
const _offWhite = Color(0xFFFAF5EF);

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

// ─── Sort options ────────────────────────────────────────────────────────────
enum _SortOption { none, priceLowHigh, priceHighLow }

// ─── HomePage (now StatefulWidget) ───────────────────────────────────────────
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Products from backend
  List<Product> _allProducts = [];
  bool _isLoading = true;
  final ProductService _productService = ProductService();

  // Search
  String _searchQuery = '';

  // Category filter — null means "all"
  DeweyCategory? _selectedCategory;

  // Price filter
  double _minPrice = 0;
  double _maxPrice = 100;
  final double _absoluteMin = 0;
  final double _absoluteMax = 100;

  // Sort
  _SortOption _sortOption = _SortOption.none;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final products = await _productService.fetchAllProducts();
      if (mounted) {
        setState(() {
          _allProducts = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load products: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Filtered + sorted product list
  List<Product> get _filteredProducts {
    List<Product> result = _allProducts.where((p) {
      final q = _searchQuery.toLowerCase();
      final matchesSearch = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q);
      final matchesCategory =
          _selectedCategory == null || p.category == _selectedCategory;
      final matchesPrice = p.price >= _minPrice && p.price <= _maxPrice;
      return matchesSearch && matchesCategory && matchesPrice;
    }).toList();

    switch (_sortOption) {
      case _SortOption.priceLowHigh:
        result.sort((a, b) => a.price.compareTo(b.price));
        break;
      case _SortOption.priceHighLow:
        result.sort((a, b) => b.price.compareTo(a.price));
        break;
      case _SortOption.none:
        break;
    }

    return result;
  }

  void _onCategoryTapped(DeweyCategory cat) {
    setState(() {
      // Tapping the same category a second time deselects it
      _selectedCategory = _selectedCategory == cat ? null : cat;
    });
    // Scroll down so the user sees the results update
  }

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
                        child: const Text('Profile',
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _dark),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
            _HeroSection(),
            _FeaturesSection(),
            Container(
              color: _offWhite,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, _taupe],
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Icon(Icons.auto_stories_outlined, color: _taupe, size: 20),
                  ),
                  Expanded(
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_taupe, Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── Categories section — tapping filters the books below ──────
                  _CategoriesSection(
                    selectedCategory: _selectedCategory,
                    onCategoryTapped: _onCategoryTapped,
                  ),
            // ── Search + filter bar ───────────────────────────────────────
            _SearchFilterBar(
              searchQuery: _searchQuery,
              onSearchChanged: (val) => setState(() => _searchQuery = val),
              sortOption: _sortOption,
              onSortChanged: (val) => setState(() => _sortOption = val!),
              minPrice: _minPrice,
              maxPrice: _maxPrice,
              absoluteMin: _absoluteMin,
              absoluteMax: _absoluteMax,
              onPriceChanged: (values) => setState(() {
                _minPrice = values.start;
                _maxPrice = values.end;
              }),
            ),
            // ── Featured books now receives the filtered list ─────────────
            _FeaturedBooksSection(products: _filteredProducts),
                  _Footer(),
                ],
              ),
            ),
    );
  }
}

// ─── Search + Filter Bar ─────────────────────────────────────────────────────
class _SearchFilterBar extends StatelessWidget {
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final _SortOption sortOption;
  final ValueChanged<_SortOption?> onSortChanged;
  final double minPrice;
  final double maxPrice;
  final double absoluteMin;
  final double absoluteMax;
  final ValueChanged<RangeValues> onPriceChanged;

  const _SearchFilterBar({
    required this.searchQuery,
    required this.onSearchChanged,
    required this.sortOption,
    required this.onSortChanged,
    required this.minPrice,
    required this.maxPrice,
    required this.absoluteMin,
    required this.absoluteMax,
    required this.onPriceChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _cream,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Search bar ──────────────────────────────────────────────────
          TextField(
            onChanged: onSearchChanged,
            style: const TextStyle(color: _dark),
            decoration: InputDecoration(
              hintText: 'Search by title or description…',
              hintStyle: const TextStyle(color: _medium),
              prefixIcon: const Icon(Icons.search, color: _medium),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: _medium),
                      onPressed: () => onSearchChanged(''),
                    )
                  : null,
              filled: true,
              fillColor: _offWhite,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: _dark, width: 1.5),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Sort dropdown + price slider row ────────────────────────────
          Wrap(
            spacing: 24,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Sort dropdown
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Sort by price:',
                      style: TextStyle(
                          color: _dark,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  const SizedBox(width: 10),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<_SortOption>(
                      value: sortOption,
                      dropdownColor: _offWhite,
                      style: const TextStyle(color: _dark, fontSize: 13),
                      borderRadius: BorderRadius.circular(6),
                      items: const [
                        DropdownMenuItem(
                          value: _SortOption.none,
                          child: Text('Default'),
                        ),
                        DropdownMenuItem(
                          value: _SortOption.priceLowHigh,
                          child: Text('Low → High'),
                        ),
                        DropdownMenuItem(
                          value: _SortOption.priceHighLow,
                          child: Text('High → Low'),
                        ),
                      ],
                      onChanged: onSortChanged,
                    ),
                  ),
                ],
              ),

              // Price range slider
              SizedBox(
                width: 340,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Price range:  \$${minPrice.toStringAsFixed(0)} – \$${maxPrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: _dark,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: _dark,
                        inactiveTrackColor: _taupe,
                        thumbColor: _dark,
                        overlayColor: _dark.withValues(alpha: 0.15),
                        rangeThumbShape: const RoundRangeSliderThumbShape(
                            enabledThumbRadius: 7),
                      ),
                      child: RangeSlider(
                        min: absoluteMin,
                        max: absoluteMax,
                        values: RangeValues(minPrice, maxPrice),
                        onChanged: onPriceChanged,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Featured Books Section ───────────────────────────────────────────────────
// Now accepts a filtered product list instead of using the constant directly.
class _FeaturedBooksSection extends StatelessWidget {
  final List<Product> products;

  const _FeaturedBooksSection({required this.products});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _cream,
      padding: const EdgeInsets.only(top: 24, bottom: 64, left: 48, right: 48),
      child: Column(
        children: [
          const SizedBox(height: 0),

          // ── Empty state ─────────────────────────────────────────────────
          if (products.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  Icon(Icons.search_off_rounded, color: _taupe, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'No products found.',
                    style: TextStyle(
                        color: _dark,
                        fontSize: 20,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Try a different search term, category, or price range.',
                    style: TextStyle(color: _medium, fontSize: 14),
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: 24,
              runSpacing: 24,
              alignment: WrapAlignment.center,
              children: products
                  .map((p) => _ProductCard(product: p))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

// ─── Product Card (unchanged) ─────────────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  final Product product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProductPage(product: product),
            ),
          );
        },
        child: Container(
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
                        onPressed: product.stockQuantity > 0
                            ? () {
                                // Prevent card tap when pressing CTA.
                                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text('${product.name} added to cart!'),
                                        backgroundColor: Colors.green,
                                        duration: const Duration(seconds: 2)));

                                // Fire and forget, correctly incrementing quantity.
                                CartService()
                                  .addOrIncrementItem(product.id)
                                  .catchError((e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text('Failed to add ${product.name}'),
                                            backgroundColor: Colors.red,
                                            duration: const Duration(seconds: 2)));
                                  }
                                });
                              }
                            : null,
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
        ),
      ),
    );
  }
}

// ─── Categories Section ───────────────────────────────────────────────────────
// Now accepts selectedCategory + callback so tapping filters the books.
class _CategoriesSection extends StatelessWidget {
  final DeweyCategory? selectedCategory;
  final ValueChanged<DeweyCategory> onCategoryTapped;

  const _CategoriesSection({
    required this.selectedCategory,
    required this.onCategoryTapped,
  });

  @override
  Widget build(BuildContext context) {
    final categories = [
      (DeweyCategory.generalWorks,   '000s · General Works',         Icons.public_outlined,                  const Color(0xFF5C7A9E)),
      (DeweyCategory.philosophy,     '100s · Philosophy',            Icons.psychology_outlined,              const Color(0xFF7B5EA7)),
      (DeweyCategory.religion,       '200s · Religion',              Icons.temple_hindu_outlined,            const Color(0xFFB07D4A)),
      (DeweyCategory.socialSciences, '300s · Social Sciences',       Icons.groups_outlined,                  const Color(0xFF4A8B6F)),
      (DeweyCategory.language,       '400s · Language',              Icons.translate_outlined,               const Color(0xFF3A8FA8)),
      (DeweyCategory.pureScience,    '500s · Pure Science',          Icons.science_outlined,                 const Color(0xFF2E7D6B)),
      (DeweyCategory.technology,     '600s · Technology',            Icons.precision_manufacturing_outlined, const Color(0xFF5A6E8A)),
      (DeweyCategory.arts,           '700s · Arts & Recreation',     Icons.palette_outlined,                 const Color(0xFFC0534A)),
      (DeweyCategory.literature,     '800s · Literature',            Icons.auto_stories_outlined,            const Color(0xFF8D7B68)),
      (DeweyCategory.history,        '900s · History & Geography',   Icons.travel_explore_outlined,          const Color(0xFF7A6E4A)),
    ];

    return Container(
      color: _offWhite,
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
            'Browse through our handpicked favourites',
            style: TextStyle(color: _medium, fontSize: 14),
          ),
          const SizedBox(height: 40),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            alignment: WrapAlignment.center,
            children: categories.map((cat) {
              final isSelected = selectedCategory == cat.$1;
              return InkWell(
                onTap: () => onCategoryTapped(cat.$1),
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 160,
                  height: 130,
                  decoration: BoxDecoration(
                    // Solid background when selected, tinted when not
                    color: isSelected
                        ? cat.$4.withValues(alpha: 0.25)
                        : cat.$4.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? cat.$4
                          : cat.$4.withValues(alpha: 0.4),
                      width: isSelected ? 2.5 : 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: cat.$4.withValues(alpha: 0.30),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(cat.$3, color: cat.$4, size: isSelected ? 40 : 36),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          cat.$2,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: cat.$4,
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w700,
                          ),
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Tap to clear',
                          style: TextStyle(
                              color: cat.$4.withValues(alpha: 0.7),
                              fontSize: 10),
                        ),
                      ]
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Hero Section (unchanged) ─────────────────────────────────────────────────
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
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

// ─── Features Section (unchanged) ────────────────────────────────────────────
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
                          style:
                              const TextStyle(color: _medium, fontSize: 13)),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ─── Footer (unchanged) ───────────────────────────────────────────────────────
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
