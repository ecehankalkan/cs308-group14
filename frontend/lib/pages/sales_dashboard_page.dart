import 'package:flutter/material.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../services/order_service.dart';
import '../services/product_service.dart';

class SalesDashboardPage extends StatefulWidget {
  const SalesDashboardPage({super.key});

  @override
  State<SalesDashboardPage> createState() => _SalesDashboardPageState();
}

class _SalesDashboardPageState extends State<SalesDashboardPage>
    with SingleTickerProviderStateMixin {
  final ProductService _productService = ProductService();
  final OrderService _orderService = OrderService();

  List<Product> _products = [];
  List<Order> _orders = [];
  bool _loadingProducts = true;
  bool _loadingOrders = true;
  String _productSearch = '';

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProducts();
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _loadingProducts = true);
    final products = await _productService.fetchAllProducts();
    if (mounted) setState(() { _products = products; _loadingProducts = false; });
  }

  Future<void> _loadOrders() async {
    setState(() => _loadingOrders = true);
    final orders = await _orderService.fetchAllOrders();
    if (mounted) setState(() { _orders = orders; _loadingOrders = false; });
  }

  void _handleLogout(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  List<Product> get _filteredProducts {
    if (_productSearch.isEmpty) return _products;
    final q = _productSearch.toLowerCase();
    return _products.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

  void _openEditDialog(Product product) {
    showDialog(
      context: context,
      builder: (_) => _EditPriceDialog(
        product: product,
        productService: _productService,
        onSaved: (updated) {
          setState(() {
            final idx = _products.indexWhere((p) => p.id == updated.id);
            if (idx != -1) _products[idx] = updated;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final discountedCount = _products.where((p) => p.discountedPrice != null).length;
    final totalRevenue = _orders.fold(0.0, (sum, o) => sum + o.totalAmount);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        title: const Text('Sales Manager Dashboard'),
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Products'),
            Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Orders'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ProductsTab(
            loading: _loadingProducts,
            products: _filteredProducts,
            allProducts: _products,
            discountedCount: discountedCount,
            search: _productSearch,
            onSearchChanged: (v) => setState(() => _productSearch = v),
            onEdit: _openEditDialog,
            onRefresh: _loadProducts,
          ),
          _OrdersTab(
            loading: _loadingOrders,
            orders: _orders,
            totalRevenue: totalRevenue,
            onRefresh: _loadOrders,
          ),
        ],
      ),
    );
  }
}

// ── Products tab ─────────────────────────────────────────────────────────────

class _ProductsTab extends StatelessWidget {
  final bool loading;
  final List<Product> products;
  final List<Product> allProducts;
  final int discountedCount;
  final String search;
  final void Function(String) onSearchChanged;
  final void Function(Product) onEdit;
  final Future<void> Function() onRefresh;

  const _ProductsTab({
    required this.loading,
    required this.products,
    required this.allProducts,
    required this.discountedCount,
    required this.search,
    required this.onSearchChanged,
    required this.onEdit,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatCard(icon: Icons.inventory_2_outlined, label: 'Products', value: '${allProducts.length}'),
                const SizedBox(width: 16),
                _StatCard(icon: Icons.local_offer_outlined, label: 'Discounted', value: '$discountedCount'),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text('Products', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                SizedBox(
                  width: 240,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search products…',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                    onChanged: onSearchChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: products.isEmpty
                  ? const Center(child: Text('No products found.'))
                  : _ProductTable(products: products, onEdit: onEdit),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Orders tab ───────────────────────────────────────────────────────────────

class _OrdersTab extends StatefulWidget {
  final bool loading;
  final List<Order> orders;
  final double totalRevenue;
  final Future<void> Function() onRefresh;

  const _OrdersTab({
    required this.loading,
    required this.orders,
    required this.totalRevenue,
    required this.onRefresh,
  });

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> {
  String _statusFilter = 'all';
  String _search = '';

  List<Order> get _filtered {
    return widget.orders.where((o) {
      final matchesStatus = _statusFilter == 'all' || o.status == _statusFilter;
      final q = _search.toLowerCase();
      final matchesSearch = q.isEmpty ||
          (o.customerName?.toLowerCase().contains(q) ?? false) ||
          (o.customerEmail?.toLowerCase().contains(q) ?? false) ||
          o.orderId.contains(q);
      return matchesStatus && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.loading) return const Center(child: CircularProgressIndicator());

    final filteredRevenue = _filtered.fold(0.0, (s, o) => s + o.totalAmount);
    final avgOrder = widget.orders.isEmpty ? 0.0 : widget.totalRevenue / widget.orders.length;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatCard(
                  icon: Icons.receipt_long_outlined,
                  label: 'Total Orders',
                  value: '${widget.orders.length}',
                ),
                const SizedBox(width: 16),
                _StatCard(
                  icon: Icons.attach_money,
                  label: 'Total Revenue',
                  value: '\$${widget.totalRevenue.toStringAsFixed(2)}',
                  small: true,
                ),
                const SizedBox(width: 16),
                _StatCard(
                  icon: Icons.trending_up,
                  label: 'Avg Order',
                  value: '\$${avgOrder.toStringAsFixed(2)}',
                  small: true,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text('Order History', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                DropdownButton<String>(
                  value: _statusFilter,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All statuses')),
                    DropdownMenuItem(value: 'processing', child: Text('Processing')),
                    DropdownMenuItem(value: 'in-transit', child: Text('In Transit')),
                    DropdownMenuItem(value: 'delivered', child: Text('Delivered')),
                  ],
                  onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 200,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search customer…',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
              ],
            ),
            if (_statusFilter != 'all' || _search.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${_filtered.length} orders · \$${filteredRevenue.toStringAsFixed(2)} revenue',
                  style: TextStyle(color: theme.colorScheme.primary, fontSize: 13),
                ),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(child: Text('No orders found.'))
                  : _OrderList(orders: _filtered),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  final List<Order> orders;
  const _OrderList({required this.orders});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Table(
          columnWidths: const {
            0: FixedColumnWidth(72),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(2.5),
            3: FlexColumnWidth(1.5),
            4: FlexColumnWidth(1.2),
            5: FlexColumnWidth(1.2),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.08)),
              children: const [
                _HeaderCell('Order #'),
                _HeaderCell('Customer'),
                _HeaderCell('Email'),
                _HeaderCell('Date'),
                _HeaderCell('Total'),
                _HeaderCell('Status'),
              ],
            ),
            for (int i = 0; i < orders.length; i++)
              _buildOrderRow(orders[i], i),
          ],
        ),
      ),
    );
  }

  TableRow _buildOrderRow(Order o, int i) {
    final statusColor = switch (o.status) {
      'delivered'  => Colors.green.shade700,
      'in-transit' => Colors.blue.shade700,
      'processing' => Colors.orange.shade700,
      _            => Colors.grey,
    };
    final dateStr =
        '${o.createdAt.day.toString().padLeft(2, '0')}/${o.createdAt.month.toString().padLeft(2, '0')}/${o.createdAt.year}';

    return TableRow(
      decoration: BoxDecoration(color: i.isOdd ? Colors.grey.shade50 : Colors.white),
      children: [
        _Cell('#${o.orderId}', bold: true),
        _Cell(o.customerName ?? '—'),
        _Cell(o.customerEmail ?? '—'),
        _Cell(dateStr),
        _Cell('\$${o.totalAmount.toStringAsFixed(2)}', bold: true),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              o.status.isEmpty ? '—' : o.status,
              style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Edit price dialog ─────────────────────────────────────────────────────────

class _EditPriceDialog extends StatefulWidget {
  final Product product;
  final ProductService productService;
  final void Function(Product) onSaved;

  const _EditPriceDialog({
    required this.product,
    required this.productService,
    required this.onSaved,
  });

  @override
  State<_EditPriceDialog> createState() => _EditPriceDialogState();
}

class _EditPriceDialogState extends State<_EditPriceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _priceCtrl;
  late final TextEditingController _discountCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _priceCtrl = TextEditingController(text: widget.product.price.toStringAsFixed(2));
    double currentPct = 0;
    if (widget.product.discountedPrice != null && widget.product.price > 0) {
      currentPct = (1 - widget.product.discountedPrice! / widget.product.price) * 100;
    }
    _discountCtrl = TextEditingController(text: currentPct.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final price = double.parse(_priceCtrl.text.trim());
    final pct   = double.parse(_discountCtrl.text.trim());

    final updated = await widget.productService.updateProductPrice(
      widget.product.id,
      price: price,
      discountPercentage: pct,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (updated != null) {
      widget.onSaved(updated);
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save. Is the server running?'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final price   = double.tryParse(_priceCtrl.text) ?? widget.product.price;
    final pct     = double.tryParse(_discountCtrl.text) ?? 0.0;
    final preview = pct > 0 ? price * (1 - pct / 100) : null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Edit Pricing', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 340,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.product.name, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 20),
              TextFormField(
                controller: _priceCtrl,
                decoration: const InputDecoration(
                  labelText: 'Base Price (\$)',
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final n = double.tryParse(v?.trim() ?? '');
                  if (n == null || n <= 0) return 'Enter a valid price';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _discountCtrl,
                decoration: const InputDecoration(
                  labelText: 'Discount %',
                  prefixIcon: Icon(Icons.local_offer_outlined),
                  border: OutlineInputBorder(),
                  hintText: '0 = no discount',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final n = double.tryParse(v?.trim() ?? '');
                  if (n == null || n < 0 || n > 100) return 'Enter 0–100';
                  return null;
                },
              ),
              if (preview != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Discounted price: \$${preview.toStringAsFixed(2)}',
                        style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }
}

// ── Product table ─────────────────────────────────────────────────────────────

class _ProductTable extends StatelessWidget {
  final List<Product> products;
  final void Function(Product) onEdit;
  const _ProductTable({required this.products, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(3),
            1: FlexColumnWidth(1.5),
            2: FlexColumnWidth(1.5),
            3: FlexColumnWidth(1.2),
            4: FlexColumnWidth(1),
            5: FixedColumnWidth(52),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.08)),
              children: const [
                _HeaderCell('Product'),
                _HeaderCell('Base Price'),
                _HeaderCell('Discounted Price'),
                _HeaderCell('Discount %'),
                _HeaderCell('Stock'),
                _HeaderCell(''),
              ],
            ),
            for (int i = 0; i < products.length; i++)
              _buildRow(products[i], i),
          ],
        ),
      ),
    );
  }

  TableRow _buildRow(Product p, int i) {
    double? pct;
    if (p.discountedPrice != null && p.price > 0) {
      pct = (1 - p.discountedPrice! / p.price) * 100;
    }

    return TableRow(
      decoration: BoxDecoration(color: i.isOdd ? Colors.grey.shade50 : Colors.white),
      children: [
        _Cell(p.name, bold: true),
        _Cell('\$${p.price.toStringAsFixed(2)}'),
        _Cell(
          p.discountedPrice != null ? '\$${p.discountedPrice!.toStringAsFixed(2)}' : '—',
          color: p.discountedPrice != null ? Colors.green.shade700 : null,
        ),
        _Cell(
          pct != null ? '${pct.toStringAsFixed(1)}%' : '0%',
          color: pct != null && pct > 0 ? Colors.orange.shade700 : null,
        ),
        _Cell('${p.stockQuantity}'),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: 'Edit pricing',
            onPressed: () => onEdit(p),
          ),
        ),
      ],
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _HeaderCell extends StatelessWidget {
  final String text;
  const _HeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }
}

class _Cell extends StatelessWidget {
  final String text;
  final bool bold;
  final Color? color;
  const _Cell(this.text, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text,
        style: TextStyle(fontWeight: bold ? FontWeight.w600 : FontWeight.normal, fontSize: 13, color: color),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool small;
  const _StatCard({required this.icon, required this.label, required this.value, this.small = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 28, color: theme.colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                value,
                style: small
                    ? theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
                    : theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(label, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
