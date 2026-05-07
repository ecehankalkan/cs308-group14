import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../models/product.dart';
import 'product_page.dart';

const _dark     = Color(0xFF8D7B68);
const _medium   = Color(0xFFA4907C);
const _taupe    = Color(0xFFC8B6A6);
const _cream    = Color(0xFFF1DEC9);
const _offWhite = Color(0xFFFAF5EF);

const String _baseUrl = 'http://127.0.0.1:8000/api';

// ─── Hardcoded covers for books that need specific/reliable images ─────────────
const Map<String, String> _hardcodedCovers = {
  'The Bible':
      'https://covers.openlibrary.org/b/isbn/9780310446958-M.jpg',
  'The Oxford Dictionary of English':
      'https://covers.openlibrary.org/b/isbn/9780199571123-M.jpg',
  'The Encyclopaedia Britannica Vol. 1':
      'https://covers.openlibrary.org/b/isbn/9780852294239-M.jpg',
};

String _coverUrl(String title) {
  if (_hardcodedCovers.containsKey(title)) {
    return _hardcodedCovers[title]!;
  }
  final encoded = Uri.encodeComponent(title);
  return 'https://covers.openlibrary.org/b/title/$encoded-M.jpg';
}

DeweyCategory _categoryFromInt(int? cat) {
  switch (cat) {
    case 1:  return DeweyCategory.generalWorks;
    case 2:  return DeweyCategory.philosophy;
    case 3:  return DeweyCategory.religion;
    case 4:  return DeweyCategory.socialSciences;
    case 5:  return DeweyCategory.language;
    case 6:  return DeweyCategory.pureScience;
    case 7:  return DeweyCategory.technology;
    case 8:  return DeweyCategory.arts;
    case 9:  return DeweyCategory.literature;
    case 10: return DeweyCategory.history;
    default: return DeweyCategory.literature;
  }
}

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
// ─── Home Page ─────────────────────────────────────────────────────────────────

enum _SortOption { none, priceLowHigh, priceHighLow }

// ─── HomePage ─────────────────────────────────────────────────────────────────
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Product>  _allProducts  = [];
  bool           _loadingBooks = true;
  String?        _fetchError;

  String            _searchQuery      = '';
  DeweyCategory?    _selectedCategory;
  double            _minPrice         = 0;
  double            _maxPrice         = 9999;
  _SortOption       _sortOption       = _SortOption.none;
  Set<String>       _wishlistedIds    = {};
  final ScrollController _scrollController = ScrollController();
  final GlobalKey        _searchKey        = GlobalKey();

  Future<void> _fetchWishlist() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null || token.isEmpty) return;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/wishlist/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final ids = data.map<String>((item) => (item['product']['id'] as int).toString()).toSet();
        if (mounted) setState(() => _wishlistedIds = ids);
      }
    } catch (_) {}
  }

  Future<void> _toggleWishlist(Product product) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Please log in to use your wishlist.'),
          backgroundColor: _dark,
          action: SnackBarAction(
            label: 'Login',
            textColor: _cream,
            onPressed: () => Navigator.pushNamed(context, '/login'),
          ),
        ));
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null || token.isEmpty) return;

    final pid = product.id;
    final isAdd = !_wishlistedIds.contains(pid);

    // OPTIMISTIC UI
    setState(() {
      if (isAdd) _wishlistedIds.add(pid);
      else _wishlistedIds.remove(pid);
    });

    try {
      if (isAdd) {
        await http.post(
          Uri.parse('$_baseUrl/wishlist/'),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          body: jsonEncode({'product_id': int.parse(pid)}),
        );
      } else {
        await http.delete(
          Uri.parse('$_baseUrl/wishlist/$pid/'),
          headers: {'Authorization': 'Bearer $token'},
        );
      }
    } catch (e) {
      // REVERT ON FAILURE
      if (mounted) {
        setState(() {
          if (isAdd) _wishlistedIds.remove(pid);
          else _wishlistedIds.add(pid);
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to update wishlist'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    _fetchWishlist();
    // Refresh wishlist if user logs in/out
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) _fetchWishlist();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts() async {
    setState(() { _loadingBooks = true; _fetchError = null; });
    try {
      final response = await http.get(Uri.parse('$_baseUrl/products/'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _allProducts = data.map((e) {
            final map = e as Map<String, dynamic>;
            return Product(
              id:            map['id'].toString(),
              name:          map['name'] as String? ?? '',
              description:   map['description'] as String? ?? '',
              price:         double.tryParse(map['price'].toString()) ?? 0.0,
              discountedPrice: map['discounted_price'] != null
                  ? double.tryParse(map['discounted_price'].toString())
                  : null,
              warrantyInfo:  map['warranty_status'] == true ? 'Available' : 'None',
              distributor:   map['distributor_info']?.toString() ?? '',
              stockQuantity: map['stock_quantity'] as int? ?? 0,
              category:      _categoryFromInt(map['category'] as int?),
            );
          }).toList();
          _loadingBooks = false;
        });
      } else {
        setState(() { _fetchError = 'Failed to load books.'; _loadingBooks = false; });
      }
    } catch (e) {
      setState(() { _fetchError = 'Could not connect to server.'; _loadingBooks = false; });
    }
  }

  void _scrollToSearch() {
    final ctx = _searchKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut);
    }
  }

  List<Product> get _filteredProducts {
    List<Product> result = _allProducts.where((p) {
      final q             = _searchQuery.toLowerCase();
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
      _selectedCategory = _selectedCategory == cat ? null : cat;
    });
    final ctx = _searchKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut);
    }
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
            icon: const Icon(Icons.favorite_border, color: _offWhite),
            tooltip: 'Wishlist',
            onPressed: () => Navigator.pushNamed(context, '/wishlist'),
          ),
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
                        child: const Text('Profile', style: TextStyle(color: _dark)),
                        onTap: () => Navigator.pushNamed(context, '/profile'),
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
                        onTap: () => Navigator.pushNamed(context, '/login'),
                      ),
                      PopupMenuItem(
                        child: const Text('Sign Up',
                            style: TextStyle(color: _dark)),
                        onTap: () => Navigator.pushNamed(context, '/signup'),
                      ),
                    ];
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.0),
                  child: Icon(Icons.account_circle, size: 30, color: _offWhite),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeroSection(onBrowseTapped: _scrollToSearch),
            _FeaturesSection(),
            _SearchFilterBar(
              key: _searchKey,
              searchQuery: _searchQuery,
              onSearchChanged: (val) => setState(() => _searchQuery = val),
              sortOption: _sortOption,
              onSortChanged: (val) => setState(() => _sortOption = val!),
              minPrice: _minPrice,
              maxPrice: _maxPrice,
              onMinPriceChanged: (val) => setState(() => _minPrice = val),
              onMaxPriceChanged: (val) => setState(() => _maxPrice = val),
            ),
            _FeaturedBooksSection(
              products: _filteredProducts,
              wishlistedIds: _wishlistedIds,
              onToggleWishlist: _toggleWishlist,
              loading: _loadingBooks,
              error: _fetchError,
              onRetry: _fetchProducts,
            ),
            _CategoriesSection(
              selectedCategory: _selectedCategory,
              onCategoryTapped: _onCategoryTapped,
            ),
            _Footer(),
          ],
        ),
      ),
    );
  }
}

// ─── Hero Section ─────────────────────────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  final VoidCallback onBrowseTapped;
  const _HeroSection({required this.onBrowseTapped});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/library.jpg'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Color(0xAA000000), BlendMode.darken),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 100, horizontal: 48),
      child: Column(
        children: [
          const Text(
            '"There is no friend\nas loyal as a book."',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _offWhite, fontSize: 48,
              fontWeight: FontWeight.w800, letterSpacing: 1, height: 1.2,
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
            onPressed: onBrowseTapped,
            style: ElevatedButton.styleFrom(
              backgroundColor: _dark,
              foregroundColor: _offWhite,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('Browse Books',
                style: TextStyle(fontSize: 16, letterSpacing: 1)),
          ),
        ],
      ),
    );
  }
}

// ─── Features Section ─────────────────────────────────────────────────────────
class _FeaturesSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final features = [
      (Icons.local_shipping_outlined, 'Free Shipping', 'On all orders over \$30'),
      (Icons.verified_outlined, 'Curated Selection', 'Hand-picked titles across every genre'),
      (Icons.replay_outlined, 'Easy Returns', '30-day hassle-free return policy'),
      (Icons.headset_mic_outlined, '24/7 Support', 'We\'re here whenever you need us'),
    ];
    return Container(
      color: _offWhite,
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 48),
      child: Wrap(
        spacing: 32, runSpacing: 32, alignment: WrapAlignment.center,
        children: features.map((f) => SizedBox(
          width: 220,
          child: Column(children: [
            Icon(f.$1, color: _medium, size: 36),
            const SizedBox(height: 12),
            Text(f.$2, style: const TextStyle(color: _dark, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(f.$3, textAlign: TextAlign.center, style: const TextStyle(color: _medium, fontSize: 13)),
          ]),
        )).toList(),
      ),
    );
  }
}

// ─── Search + Filter Bar ──────────────────────────────────────────────────────
class _SearchFilterBar extends StatefulWidget {
  final String                     searchQuery;
  final ValueChanged<String>       onSearchChanged;
  final _SortOption                sortOption;
  final ValueChanged<_SortOption?> onSortChanged;
  final double                     minPrice;
  final double                     maxPrice;
  final ValueChanged<double>       onMinPriceChanged;
  final ValueChanged<double>       onMaxPriceChanged;

  const _SearchFilterBar({
    super.key,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.sortOption,
    required this.onSortChanged,
    required this.minPrice,
    required this.maxPrice,
    required this.onMinPriceChanged,
    required this.onMaxPriceChanged,
  });

  @override
  State<_SearchFilterBar> createState() => _SearchFilterBarState();
}

class _SearchFilterBarState extends State<_SearchFilterBar> {
  late TextEditingController _minController;
  late TextEditingController _maxController;

  @override
  void initState() {
    super.initState();
    _minController = TextEditingController(
        text: widget.minPrice == 0 ? '' : widget.minPrice.toStringAsFixed(0));
    _maxController = TextEditingController(
        text: widget.maxPrice == 9999 ? '' : widget.maxPrice.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  void _onMinSubmitted(String val) {
    final parsed = double.tryParse(val);
    if (parsed != null && parsed >= 0) {
      widget.onMinPriceChanged(parsed);
    } else if (val.isEmpty) {
      widget.onMinPriceChanged(0);
    }
  }

  void _onMaxSubmitted(String val) {
    final parsed = double.tryParse(val);
    if (parsed != null && parsed >= 0) {
      widget.onMaxPriceChanged(parsed);
    } else if (val.isEmpty) {
      widget.onMaxPriceChanged(9999);
    }
  }

  InputDecoration _priceFieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _medium, fontSize: 13),
      prefixText: '\$ ',
      prefixStyle: const TextStyle(color: _dark, fontSize: 13),
      filled: true,
      fillColor: _offWhite,
      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _dark, width: 1.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _cream,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Search bar ────────────────────────────────────────────────
          TextField(
            onChanged: widget.onSearchChanged,
            style: const TextStyle(color: _dark),
            decoration: InputDecoration(
              hintText: 'Search by title or description…',
              hintStyle: const TextStyle(color: _medium),
              prefixIcon: const Icon(Icons.search, color: _medium),
              suffixIcon: widget.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: _medium),
                      onPressed: () => widget.onSearchChanged(''))
                  : null,
              filled: true,
              fillColor: _offWhite,
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: _dark, width: 1.5)),
            ),
          ),

          const SizedBox(height: 20),

          // ── Sort + price inputs row ───────────────────────────────────
          Wrap(
            spacing: 24, runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Sort dropdown
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Sort by price:',
                      style: TextStyle(color: _dark, fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(width: 10),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<_SortOption>(
                      value: widget.sortOption,
                      dropdownColor: _offWhite,
                      style: const TextStyle(color: _dark, fontSize: 13),
                      borderRadius: BorderRadius.circular(6),
                      items: const [
                        DropdownMenuItem(value: _SortOption.none,         child: Text('Default')),
                        DropdownMenuItem(value: _SortOption.priceLowHigh, child: Text('Low → High')),
                        DropdownMenuItem(value: _SortOption.priceHighLow, child: Text('High → Low')),
                      ],
                      onChanged: widget.onSortChanged,
                    ),
                  ),
                ],
              ),

              // Price range inputs
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Price:',
                      style: TextStyle(color: _dark, fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 90,
                    child: TextField(
                      controller: _minController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: _dark, fontSize: 13),
                      decoration: _priceFieldDecoration('Min'),
                      onSubmitted: _onMinSubmitted,
                      onEditingComplete: () => _onMinSubmitted(_minController.text),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('–', style: TextStyle(color: _dark, fontWeight: FontWeight.w700)),
                  ),
                  SizedBox(
                    width: 90,
                    child: TextField(
                      controller: _maxController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: _dark, fontSize: 13),
                      decoration: _priceFieldDecoration('Max'),
                      onSubmitted: _onMaxSubmitted,
                      onEditingComplete: () => _onMaxSubmitted(_maxController.text),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Apply button
                  ElevatedButton(
                    onPressed: () {
                      _onMinSubmitted(_minController.text);
                      _onMaxSubmitted(_maxController.text);
                      FocusScope.of(context).unfocus();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _dark,
                      foregroundColor: _offWhite,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Apply', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Featured Books Section ───────────────────────────────────────────────────
class _FeaturedBooksSection extends StatelessWidget {
  final List<Product> products;
  final Set<String>    wishlistedIds;
  final Function(Product) onToggleWishlist;
  final bool          loading;
  final String?       error;
  final VoidCallback  onRetry;

  const _FeaturedBooksSection({
    required this.products,
    required this.wishlistedIds,
    required this.onToggleWishlist,
    required this.loading,
    this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _cream,
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 48),
      child: Column(
        children: [
          const Text('Featured Books',
              style: TextStyle(color: _dark, fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 8),
          const Text('Handpicked favourites from our collection',
              style: TextStyle(color: _medium, fontSize: 15)),
          const SizedBox(height: 40),

          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: CircularProgressIndicator(color: _dark),
            )
          else if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  Icon(Icons.wifi_off_rounded, color: _taupe, size: 64),
                  const SizedBox(height: 16),
                  Text(error!,
                      style: const TextStyle(color: _dark, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: onRetry,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _dark, foregroundColor: _offWhite),
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            )
          else if (products.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  Icon(Icons.search_off_rounded, color: _taupe, size: 64),
                  const SizedBox(height: 16),
                  const Text('No products found.',
                      style: TextStyle(color: _dark, fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Text('Try a different search term, category, or price range.',
                      style: TextStyle(color: _medium, fontSize: 14)),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                const cardWidth   = 200.0;
                const cardSpacing = 20.0;
                final columns = ((constraints.maxWidth + cardSpacing) / (cardWidth + cardSpacing)).floor();
                final effectiveColumns = columns.clamp(1, 6);
                return Wrap(
                  spacing: cardSpacing,
                  runSpacing: cardSpacing,
                  alignment: WrapAlignment.start,
                  children: products.map((p) => SizedBox(
                    width: (constraints.maxWidth - (effectiveColumns - 1) * cardSpacing) / effectiveColumns,
                    child: _ProductCard(
                      product: p,
                      isWishlisted: wishlistedIds.contains(p.id),
                      onToggleWishlist: () => onToggleWishlist(p),
                    ),
                  )).toList(),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ─── Product Card ─────────────────────────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  final Product product;
  final bool isWishlisted;
  final VoidCallback onToggleWishlist;

  const _ProductCard({
    required this.product,
    required this.isWishlisted,
    required this.onToggleWishlist,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProductPage(product: product),
        ),
      ),
      borderRadius: BorderRadius.circular(8),
      child: Container(
      decoration: BoxDecoration(
        color: _offWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _categoryColors[product.category]!, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                child: CachedNetworkImage(
                  imageUrl: _coverUrl(product.name),
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 200,
                    color: _taupe,
                    child: const Center(
                      child: CircularProgressIndicator(color: _offWhite, strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 200,
                    color: _taupe,
                    child: const Center(
                      child: Icon(Icons.menu_book, color: _offWhite, size: 64),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8, right: 8,
                child: GestureDetector(
                  onTap: onToggleWishlist,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _offWhite.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isWishlisted ? Icons.favorite : Icons.favorite_border,
                      color: Colors.red,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 40,
                  child: Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _categoryColors[product.category],
                      fontSize: 13, fontWeight: FontWeight.w700, height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 54,
                  child: Text(
                    product.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _medium, fontSize: 11, height: 1.4),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('\$${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(color: _dark, fontSize: 15, fontWeight: FontWeight.w800)),
                    Text(
                      product.stockQuantity > 0 ? 'In stock' : 'Out of stock',
                      style: TextStyle(
                        color: product.stockQuantity > 0
                            ? Colors.green.shade700
                            : Colors.red.shade400,
                        fontSize: 11, fontWeight: FontWeight.w600,
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
                            // Instant Feedback
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('${product.name} added to cart!'),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 1),
                            ));
                            
                            // Background API call
                            CartService().updateQuantity(
                                productId: product.id, requestedQuantity: 1
                            ).catchError((e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text('Failed to add ${product.name}'),
                                    backgroundColor: Colors.red,
                                  ));
                                }
                                return const CartUpdateResult(items: [], adjustedToStock: false);
                            });
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _dark,
                      foregroundColor: _offWhite,
                      disabledBackgroundColor: _taupe,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    child: const Text('Add to Cart', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  }
}

// ─── Categories Section ───────────────────────────────────────────────────────
class _CategoriesSection extends StatelessWidget {
  final DeweyCategory?              selectedCategory;
  final ValueChanged<DeweyCategory> onCategoryTapped;

  const _CategoriesSection({
    required this.selectedCategory,
    required this.onCategoryTapped,
  });

  @override
  Widget build(BuildContext context) {
    final categories = [
      (DeweyCategory.generalWorks,   '000s · General Works',       Icons.public_outlined,                  const Color(0xFF5C7A9E)),
      (DeweyCategory.philosophy,     '100s · Philosophy',          Icons.psychology_outlined,              const Color(0xFF7B5EA7)),
      (DeweyCategory.religion,       '200s · Religion',            Icons.temple_hindu_outlined,            const Color(0xFFB07D4A)),
      (DeweyCategory.socialSciences, '300s · Social Sciences',     Icons.groups_outlined,                  const Color(0xFF4A8B6F)),
      (DeweyCategory.language,       '400s · Language',            Icons.translate_outlined,               const Color(0xFF3A8FA8)),
      (DeweyCategory.pureScience,    '500s · Pure Science',        Icons.science_outlined,                 const Color(0xFF2E7D6B)),
      (DeweyCategory.technology,     '600s · Technology',          Icons.precision_manufacturing_outlined, const Color(0xFF5A6E8A)),
      (DeweyCategory.arts,           '700s · Arts & Recreation',   Icons.palette_outlined,                 const Color(0xFFC0534A)),
      (DeweyCategory.literature,     '800s · Literature',          Icons.auto_stories_outlined,            const Color(0xFF8D7B68)),
      (DeweyCategory.history,        '900s · History & Geography', Icons.travel_explore_outlined,          const Color(0xFF7A6E4A)),
    ];

    return Container(
      color: _offWhite,
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 48),
      child: Column(
        children: [
          const Text('Browse by Category',
              style: TextStyle(color: _dark, fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 8),
          const Text('Tap a category to filter the books above',
              style: TextStyle(color: _medium, fontSize: 14)),
          const SizedBox(height: 40),
          Wrap(
            spacing: 20, runSpacing: 20, alignment: WrapAlignment.center,
            children: categories.map((cat) {
              final isSelected = selectedCategory == cat.$1;
              return InkWell(
                onTap: () => onCategoryTapped(cat.$1),
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 160, height: 130,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? cat.$4.withValues(alpha: 0.25)
                        : cat.$4.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? cat.$4 : cat.$4.withValues(alpha: 0.4),
                      width: isSelected ? 2.5 : 1.5,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: cat.$4.withValues(alpha: 0.30), blurRadius: 8, offset: const Offset(0, 3))]
                        : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(cat.$3, color: cat.$4, size: isSelected ? 40 : 36),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(cat.$2,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: cat.$4, fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                          ),
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(height: 6),
                        Text('Tap to clear',
                            style: TextStyle(color: cat.$4.withValues(alpha: 0.7), fontSize: 10)),
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

// ─── Footer ───────────────────────────────────────────────────────────────────
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
