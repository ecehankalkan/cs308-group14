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

// ─── ISBN-based covers (reliable) for all known products ──────────────────────
const Map<String, String> _hardcodedCovers = {
  '1984':                                       'https://covers.openlibrary.org/b/isbn/9780451524935-M.jpg',
  'The Art of War':                             'https://covers.openlibrary.org/b/isbn/9781599869773-M.jpg',
  'Dune':                                       'https://covers.openlibrary.org/b/isbn/9780441013593-M.jpg',
  'Atomic Habits':                              'https://covers.openlibrary.org/b/isbn/9780735211292-M.jpg',
  'The Alchemist':                              'https://covers.openlibrary.org/b/isbn/9780062315007-M.jpg',
  'Thinking, Fast and Slow':                    'https://covers.openlibrary.org/b/isbn/9780374533557-M.jpg',
  'The Midnight Library':                       'https://covers.openlibrary.org/b/isbn/9780525559474-M.jpg',
  'Sapiens':                                    'https://covers.openlibrary.org/b/isbn/9780062316097-M.jpg',
  'To Kill a Mockingbird':                      'https://covers.openlibrary.org/b/isbn/9780061935466-M.jpg',
  'Homo Deus':                                  'https://covers.openlibrary.org/b/isbn/9780062464316-M.jpg',
  "The Hitchhiker's Guide to the Galaxy":       'https://covers.openlibrary.org/b/isbn/9780345391803-M.jpg',
  'Guns, Germs, and Steel':                     'https://covers.openlibrary.org/b/isbn/9780393317558-M.jpg',
  'The Bible':                                  'https://covers.openlibrary.org/b/isbn/9780310446958-M.jpg',
  'The Oxford Dictionary of English':           'https://covers.openlibrary.org/b/isbn/9780199571123-M.jpg',
  'Introduction to Algorithms':                 'https://covers.openlibrary.org/b/isbn/9780262033848-M.jpg',
  'The Story of Art':                           'https://covers.openlibrary.org/b/isbn/9780714832470-M.jpg',
  'Freakonomics':                               'https://covers.openlibrary.org/b/isbn/9780060731335-M.jpg',
  'The Communist Manifesto':                    'https://covers.openlibrary.org/b/isbn/9780140447576-M.jpg',
  'The Elements of Style':                      'https://covers.openlibrary.org/b/isbn/9780205309023-M.jpg',
  'The Encyclopaedia Britannica Vol. 1':        'https://covers.openlibrary.org/b/isbn/9780852294239-M.jpg',
  'Crime and Punishment':                       'https://covers.openlibrary.org/b/isbn/9780140449136-M.jpg',
  'The Joy of Music':                           'https://covers.openlibrary.org/b/isbn/9781574670134-M.jpg',
  'Educated':                                   'https://covers.openlibrary.org/b/isbn/9780399590504-M.jpg',
  'The Power of Now':                           'https://covers.openlibrary.org/b/isbn/9781577314806-M.jpg',
  'The Lean Startup':                           'https://covers.openlibrary.org/b/isbn/9780307887894-M.jpg',
  'A Brief History of Time':                    'https://covers.openlibrary.org/b/isbn/9780553380163-M.jpg',
  'Clean Code':                                 'https://covers.openlibrary.org/b/isbn/9780132350884-M.jpg',
  'The Great Gatsby':                           'https://covers.openlibrary.org/b/isbn/9780743273565-M.jpg',
  'The Selfish Gene':                           'https://covers.openlibrary.org/b/isbn/9780198788607-M.jpg',
  "Harry Potter and the Philosopher's Stone":   'https://covers.openlibrary.org/b/isbn/9780439708180-M.jpg',
};

String _coverUrl(String title) {
  if (_hardcodedCovers.containsKey(title)) {
    return _hardcodedCovers[title]!;
  }
  final encoded = Uri.encodeComponent(title);
  return 'https://covers.openlibrary.org/b/title/$encoded-M.jpg';
}

// ─── Home Page ─────────────────────────────────────────────────────────────────// ─── Home Page ─────────────────────────────────────────────────────────────────

enum _SortOption { none, priceLowHigh, priceHighLow, popularity }

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
  int?              _selectedCategory;
  List<Map<String, dynamic>> _dynamicCategories = [];
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
    _fetchCategories();
    _fetchProducts();
    _fetchWishlist();
    // Refresh wishlist if user logs in/out
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) _fetchWishlist();
    });
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/categories/'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        if (mounted) {
          setState(() {
            _dynamicCategories = data
                .map((e) => e as Map<String, dynamic>)
                .where((c) => c['is_active'] == true)
                .toList();
          });
        }
      }
    } catch (_) {}
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
              categoryId:    map['category'] as int?,
              averageRating: map['average_rating'] != null
                  ? double.tryParse(map['average_rating'].toString())
                  : null,
              ratingCount:   map['rating_count'] as int? ?? 0,
              imageUrl:      map['image_url'] as String?,
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
          _selectedCategory == null || p.categoryId == _selectedCategory;
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
      case _SortOption.popularity:
        result.sort((a, b) => (b.averageRating ?? 0.0).compareTo(a.averageRating ?? 0.0));
        break;
      case _SortOption.none:
        break;
    }
    return result;
  }

  void _onCategoryTapped(int catId) {
    setState(() {
      _selectedCategory = _selectedCategory == catId ? null : catId;
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
            onPressed: () => Navigator.pushNamed(context, '/cart').then((_) => _fetchProducts()),
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
              categories: _dynamicCategories,
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
                  const Text('Sort by:',
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
                        DropdownMenuItem(value: _SortOption.popularity,   child: Text('Popularity')),
                        DropdownMenuItem(value: _SortOption.priceLowHigh, child: Text('Price: Low → High')),
                        DropdownMenuItem(value: _SortOption.priceHighLow, child: Text('Price: High → Low')),
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
                      onReturn: onRetry,
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
  final VoidCallback onReturn;

  const _ProductCard({
    required this.product,
    required this.isWishlisted,
    required this.onToggleWishlist,
    required this.onReturn,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProductPage(product: product),
        ),
      ).then((_) => onReturn()),
      borderRadius: BorderRadius.circular(8),
      child: Container(
      decoration: BoxDecoration(
        color: _offWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _medium, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                child: CachedNetworkImage(
                  imageUrl: (product.imageUrl != null && product.imageUrl!.isNotEmpty) 
                      ? product.imageUrl! 
                      : _coverUrl(product.name),
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
                    style: const TextStyle(
                      color: _dark,
                      fontSize: 13, fontWeight: FontWeight.w700, height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Row(
                      children: List.generate(5, (i) {
                        final avg = product.averageRating ?? 0.0;
                        final whole = avg.floor();
                        final hasHalf = (avg - whole) >= 0.5;
                        if (i < whole) return const Icon(Icons.star, color: _dark, size: 14);
                        if (i == whole && hasHalf) return const Icon(Icons.star_half, color: _dark, size: 14);
                        return const Icon(Icons.star_border, color: _dark, size: 14);
                      }),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      product.averageRating != null ? '${product.averageRating!.toStringAsFixed(1)} (${product.ratingCount})' : 'No ratings',
                      style: const TextStyle(color: _dark, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
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
                    if (product.discountedPrice != null && product.discountedPrice! < product.price) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '\$${product.discountedPrice!.toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '\$${product.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${((product.price - product.discountedPrice!) / product.price * 100).round()}% OFF',
                              style: TextStyle(color: Colors.red.shade800, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text('\$${product.price.toStringAsFixed(2)}',
                          style: const TextStyle(color: _dark, fontSize: 15, fontWeight: FontWeight.w800)),
                    ],
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
                            if (!CartService().canAddMore(product.id, 1)) {
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text('Max stock reached for this item.'),
                                backgroundColor: Colors.orange,
                                duration: Duration(seconds: 2),
                              ));
                              return;
                            }

                            // Instant Feedback
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('${product.name} added to cart!'),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 1),
                            ));
                            
                            // Background API call
                            CartService().addOrIncrementItem(product.id).catchError((e) {
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
  final int?                          selectedCategory;
  final ValueChanged<int>             onCategoryTapped;
  final List<Map<String, dynamic>>    categories;

  const _CategoriesSection({
    required this.selectedCategory,
    required this.onCategoryTapped,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    // We use a fixed palette for dynamically fetched categories
    final List<Color> palette = [
      const Color(0xFF5C7A9E), const Color(0xFF7B5EA7), const Color(0xFFB07D4A),
      const Color(0xFF4A8B6F), const Color(0xFF3A8FA8), const Color(0xFF2E7D6B),
      const Color(0xFF5A6E8A), const Color(0xFFC0534A), const Color(0xFF8D7B68),
      const Color(0xFF7A6E4A),
    ];

    if (categories.isEmpty) return const SizedBox();

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
            children: categories.map((catMap) {
              final catId = catMap['id'] as int;
              final catName = catMap['name'] as String;
              final isSelected = selectedCategory == catId;
              final color = palette[catId % palette.length];

              return InkWell(
                onTap: () => onCategoryTapped(catId),
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 160, height: 130,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.25)
                        : color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? color : color.withValues(alpha: 0.4),
                      width: isSelected ? 2.5 : 1.5,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: color.withValues(alpha: 0.30), blurRadius: 8, offset: const Offset(0, 3))]
                        : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.category_outlined, color: color, size: isSelected ? 40 : 36),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(catName,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: color, fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                          ),
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(height: 6),
                        Text('Tap to clear',
                            style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 10)),
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
