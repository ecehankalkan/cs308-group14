// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../services/order_service.dart';
import '../services/product_service.dart';

const _nonRevenueStatuses = {'refunded', 'cancelled', 'refund-requested'};

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
    _tabController = TabController(length: 4, vsync: this);
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
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
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
    final totalRevenue = _orders
        .where((o) => !_nonRevenueStatuses.contains(o.status))
        .fold(0.0, (sum, o) => sum + o.totalAmount);

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
            Tab(icon: Icon(Icons.bar_chart_outlined), text: 'Revenue'),
            Tab(icon: Icon(Icons.assignment_return_outlined), text: 'Refunds'),
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
          _RevenueTab(
            loading: _loadingOrders,
            orders: _orders,
            onRefresh: _loadOrders,
          ),
          _RefundsTab(
            loading: _loadingOrders,
            orders: _orders,
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
  DateTimeRange? _dateRange;

  List<Order> get _filtered {
    return widget.orders.where((o) {
      final matchesStatus = _statusFilter == 'all' || o.status == _statusFilter;
      final q = _search.toLowerCase();
      final matchesSearch = q.isEmpty ||
          (o.customerName?.toLowerCase().contains(q) ?? false) ||
          (o.customerEmail?.toLowerCase().contains(q) ?? false) ||
          o.orderId.contains(q);
      final matchesDate = _dateRange == null ||
          (!o.createdAt.isBefore(_dateRange!.start) &&
           !o.createdAt.isAfter(DateTime(
             _dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day, 23, 59, 59)));
      return matchesStatus && matchesSearch && matchesDate;
    }).toList();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _dateRange ??
          DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
    );
    if (picked != null) setState(() => _dateRange = picked);
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

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
                OutlinedButton.icon(
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(_dateRange == null
                      ? 'All dates'
                      : '${_fmtDate(_dateRange!.start)} – ${_fmtDate(_dateRange!.end)}'),
                  onPressed: _pickRange,
                ),
                if (_dateRange != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Clear date filter',
                    onPressed: () => setState(() => _dateRange = null),
                  ),
                ],
                const SizedBox(width: 12),
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
            if (_statusFilter != 'all' || _search.isNotEmpty || _dateRange != null)
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
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: ListView.builder(
        itemCount: orders.length,
        itemBuilder: (_, i) => _OrderCard(order: orders[i], isOdd: i.isOdd),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final bool isOdd;
  const _OrderCard({required this.order, required this.isOdd});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (order.status) {
      'delivered'  => Colors.green.shade700,
      'in-transit' => Colors.blue.shade700,
      'processing' => Colors.orange.shade700,
      _            => Colors.grey,
    };
    final dateStr =
        '${order.createdAt.day.toString().padLeft(2, '0')}/'
        '${order.createdAt.month.toString().padLeft(2, '0')}/'
        '${order.createdAt.year}';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isOdd ? Colors.grey.shade50 : Colors.white,
        border: const Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        backgroundColor: isOdd ? Colors.grey.shade50 : Colors.white,
        collapsedBackgroundColor: isOdd ? Colors.grey.shade50 : Colors.white,
        title: Row(
          children: [
            SizedBox(
              width: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('#${order.orderId}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  Text(dateStr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.customerName ?? '—', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                  Text(order.customerEmail ?? '—', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            Text(
              '\$${order.totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                order.status.isEmpty ? '—' : order.status,
                style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),
          if (order.items.isNotEmpty) ...[
            const Text('Items', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            ...order.items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(child: Text(item.productName, style: const TextStyle(fontSize: 13))),
                    Text('× ${item.quantity}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(width: 24),
                    SizedBox(
                      width: 70,
                      child: Text(
                        '\$${item.unitPrice.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 13),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 90,
                      child: Text(
                        '= \$${item.subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('Preview Invoice'),
                onPressed: () => _openInvoice(context, download: false),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('Download Invoice'),
                onPressed: () => _openInvoice(context, download: true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openInvoice(BuildContext context, {required bool download}) {
    const baseUrl = 'http://127.0.0.1:8000';
    final url = download
        ? '$baseUrl/api/sales/orders/${order.orderId}/invoice/?download=1'
        : '$baseUrl/api/sales/orders/${order.orderId}/invoice/';
    html.window.open(url, '_blank');
  }
}

// ── Revenue tab ───────────────────────────────────────────────────────────────

class _RevenueTab extends StatefulWidget {
  final bool loading;
  final List<Order> orders;
  final Future<void> Function() onRefresh;

  const _RevenueTab({
    required this.loading,
    required this.orders,
    required this.onRefresh,
  });

  @override
  State<_RevenueTab> createState() => _RevenueTabState();
}

class _RevenueTabState extends State<_RevenueTab> {
  String _granularity = 'monthly'; // 'daily' | 'weekly' | 'monthly'
  String _currency = 'USD';        // 'USD' | 'TRY'
  DateTimeRange? _range;

  static const double _tryRate = 38.5; // fixed rate for display

  String get _symbol => _currency == 'TRY' ? '₺' : '\$';
  double _convert(double usd) => _currency == 'TRY' ? usd * _tryRate : usd;

  // ── Data helpers ─────────────────────────────────────────────────────────

  List<Order> get _rangeOrders {
    final base = widget.orders.where((o) => !_nonRevenueStatuses.contains(o.status));
    if (_range == null) return base.toList();
    final end = DateTime(_range!.end.year, _range!.end.month, _range!.end.day, 23, 59, 59);
    return base
        .where((o) => !o.createdAt.isBefore(_range!.start) && !o.createdAt.isAfter(end))
        .toList();
  }

  String _bucket(DateTime dt) {
    switch (_granularity) {
      case 'daily':
        return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      case 'weekly':
        final monday = dt.subtract(Duration(days: dt.weekday - 1));
        return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
      case 'monthly':
      default:
        return '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
    }
  }

  String _label(String key) {
    final p = key.split('-');
    switch (_granularity) {
      case 'daily':
      case 'weekly':
        return '${p[2]}/${p[1]}';
      case 'monthly':
      default:
        const m = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        return '${m[int.parse(p[1])]}\n${p[0]}';
    }
  }

  Map<String, double> get _grouped {
    final map = <String, double>{};
    for (final o in _rangeOrders) {
      final k = _bucket(o.createdAt);
      map[k] = (map[k] ?? 0) + o.totalAmount;
    }
    if (map.isEmpty) return {};
    final sorted = map.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final firstKey = sorted.first.key;
    final lastKey  = sorted.last.key;

    // Fill every period between first and last with 0 if no orders fell in it
    final filled = <String, double>{};
    for (final k in _periodRange(firstKey, lastKey)) {
      filled[k] = map[k] ?? 0;
    }
    return filled;
  }

  List<String> _periodRange(String firstKey, String lastKey) {
    final result = <String>[];
    switch (_granularity) {
      case 'daily':
        var cur = DateTime.parse(firstKey);
        final end = DateTime.parse(lastKey);
        while (!cur.isAfter(end)) {
          result.add(_bucket(cur));
          cur = cur.add(const Duration(days: 1));
        }
      case 'weekly':
        var cur = DateTime.parse(firstKey);
        final end = DateTime.parse(lastKey);
        while (!cur.isAfter(end)) {
          result.add(_bucket(cur));
          cur = cur.add(const Duration(days: 7));
        }
      case 'monthly':
      default:
        final fp = firstKey.split('-');
        final lp = lastKey.split('-');
        var y = int.parse(fp[0]);
        var m = int.parse(fp[1]);
        final ey = int.parse(lp[0]);
        final em = int.parse(lp[1]);
        while (y < ey || (y == ey && m <= em)) {
          result.add('$y-${m.toString().padLeft(2, '0')}');
          m++;
          if (m > 12) { m = 1; y++; }
        }
    }
    return result;
  }

  // ── Date range picker ────────────────────────────────────────────────────

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _range ??
          DateTimeRange(start: now.subtract(const Duration(days: 90)), end: now),
    );
    if (picked != null) setState(() => _range = picked);
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.loading) return const Center(child: CircularProgressIndicator());

    final theme = Theme.of(context);
    final grouped = _grouped;
    final keys = grouped.keys.toList();
    final values = grouped.values.map(_convert).toList();
    final total = values.fold(0.0, (s, v) => s + v);
    final maxY = values.isEmpty ? 100.0 : values.reduce((a, b) => a > b ? a : b) * 1.25;
    final barWidth = keys.length > 20 ? 8.0 : keys.length > 10 ? 14.0 : 22.0;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Controls row ─────────────────────────────────────────────
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'daily',   label: Text('Daily')),
                    ButtonSegment(value: 'weekly',  label: Text('Weekly')),
                    ButtonSegment(value: 'monthly', label: Text('Monthly')),
                  ],
                  selected: {_granularity},
                  onSelectionChanged: (s) => setState(() => _granularity = s.first),
                ),
                ToggleButtons(
                  isSelected: [_currency == 'USD', _currency == 'TRY'],
                  onPressed: (i) => setState(() => _currency = i == 0 ? 'USD' : 'TRY'),
                  borderRadius: BorderRadius.circular(8),
                  constraints: const BoxConstraints(minHeight: 40, minWidth: 72),
                  children: const [Text('\$ USD'), Text('₺ TRY')],
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(_range == null
                      ? 'All time'
                      : '${_fmtDate(_range!.start)} – ${_fmtDate(_range!.end)}'),
                  onPressed: _pickRange,
                ),
                if (_range != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Clear filter',
                    onPressed: () => setState(() => _range = null),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Stat cards ───────────────────────────────────────────────
            Row(
              children: [
                _StatCard(
                  icon: Icons.attach_money,
                  label: 'Total Revenue (filtered)',
                  value: '$_symbol${total.toStringAsFixed(2)}',
                  small: true,
                ),
                const SizedBox(width: 16),
                _StatCard(
                  icon: Icons.bar_chart,
                  label: 'Periods shown',
                  value: '${keys.length}',
                ),
                const SizedBox(width: 16),
                _StatCard(
                  icon: Icons.receipt_long_outlined,
                  label: 'Orders (filtered)',
                  value: '${_rangeOrders.length}',
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ── Charts: Revenue + Profit side by side ─────────────────────
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 720;
                final revenueChart = _ChartCard(
                  title: 'Revenue per ${_granularity[0].toUpperCase()}${_granularity.substring(1)} Period',
                  keys: keys,
                  values: values,
                  maxY: maxY,
                  barWidth: barWidth,
                  symbol: _symbol,
                  barColor: theme.colorScheme.primary,
                  labelOf: _label,
                );
                // Profit is mocked at 50% of revenue.
                final profitValues = values.map((v) => v * 0.5).toList();
                final profitMaxY = maxY * 0.5;
                final profitChart = _ChartCard(
                  title: 'Profit per ${_granularity[0].toUpperCase()}${_granularity.substring(1)} Period (50% of revenue)',
                  keys: keys,
                  values: profitValues,
                  maxY: profitMaxY,
                  barWidth: barWidth,
                  symbol: _symbol,
                  barColor: Colors.green.shade700,
                  labelOf: _label,
                );

                if (keys.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Text('No orders in the selected range.'),
                    ),
                  );
                }

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: revenueChart),
                      const SizedBox(width: 16),
                      Expanded(child: profitChart),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    revenueChart,
                    const SizedBox(height: 16),
                    profitChart,
                  ],
                );
              },
            ),
                  
            const SizedBox(height: 36),

            // ── Breakdown rows ───────────────────────────────────────────
            Text(
              '${_granularity[0].toUpperCase()}${_granularity.substring(1)} Breakdown',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    child: const Row(
                      children: [
                        Expanded(child: Text('Period', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                        Text('Revenue', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
                    ),
                  ),
                  if (keys.isEmpty)
                    const Padding(padding: EdgeInsets.all(20), child: Text('No data.'))
                  else
                    ...List.generate(keys.length, (i) {
                      final pct = total > 0 ? values[i] / total : 0.0;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: i.isOdd ? Colors.grey.shade50 : Colors.white,
                          border: const Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _label(keys[i]).replaceAll('\n', ' '),
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                  const SizedBox(height: 5),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: pct,
                                      minHeight: 5,
                                      backgroundColor: Colors.grey.shade200,
                                      valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '$_symbol${values[i].toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                                Text(
                                  '${(pct * 100).toStringAsFixed(1)}%',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
            if (_currency == 'TRY')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '* TRY amounts use a fixed display rate of 1 USD = ${_tryRate.toStringAsFixed(1)} ₺',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
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

// ── Reusable chart card (used by Revenue tab for both Revenue and Profit) ────

class _ChartCard extends StatelessWidget {
  final String title;
  final List<String> keys;
  final List<double> values;
  final double maxY;
  final double barWidth;
  final String symbol;
  final Color barColor;
  final String Function(String) labelOf;

  const _ChartCard({
    required this.title,
    required this.keys,
    required this.values,
    required this.maxY,
    required this.barWidth,
    required this.symbol,
    required this.barColor,
    required this.labelOf,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 300,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => Colors.blueGrey.shade800,
                  getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                    '${labelOf(keys[group.x]).replaceAll('\n', ' ')}'
                    '\n$symbol${rod.toY.toStringAsFixed(2)}',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (x, _) {
                      final i = x.toInt();
                      if (i < 0 || i >= keys.length) return const SizedBox();
                      if (keys.length > 15 && i % ((keys.length / 7).ceil()) != 0) {
                        return const SizedBox();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          labelOf(keys[i]),
                          style: const TextStyle(fontSize: 10),
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 64,
                    getTitlesWidget: (y, _) => Text(
                      '$symbol${y >= 1000 ? '${(y / 1000).toStringAsFixed(1)}k' : y.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ),
              ),
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: Colors.grey.shade200, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              barGroups: [
                for (int i = 0; i < keys.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: values[i],
                        color: barColor,
                        width: barWidth,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Refunds tab ──────────────────────────────────────────────────────────────

class _RefundsTab extends StatelessWidget {
  final bool loading;
  final List<Order> orders;
  final Future<void> Function() onRefresh;

  const _RefundsTab({
    required this.loading,
    required this.orders,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    final pending = orders.where((o) => o.status == 'refund-requested').toList();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stat card
            Row(
              children: [
                _StatCard(
                  icon: Icons.assignment_return_outlined,
                  label: 'Pending Refunds',
                  value: '${pending.length}',
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Pending Refund Requests',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (pending.isEmpty)
              const Expanded(
                child: Center(child: Text('No pending refund requests.')),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: pending.length,
                  itemBuilder: (ctx, i) {
                    final order = pending[i];
                    return _RefundRequestCard(
                      order: order,
                      onRefresh: onRefresh,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RefundRequestCard extends StatefulWidget {
  final Order order;
  final Future<void> Function() onRefresh;
  const _RefundRequestCard({required this.order, required this.onRefresh});

  @override
  State<_RefundRequestCard> createState() => _RefundRequestCardState();
}

class _RefundRequestCardState extends State<_RefundRequestCard> {
  bool _loading = false;

  Future<void> _resolve(String decision) async {
    setState(() => _loading = true);
    final ok = await OrderService().resolveRefundRequest(widget.order.orderId, decision);
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? (decision == 'accept' ? 'Refund accepted.' : 'Refund rejected.')
          : 'Action failed. Please try again.'),
      backgroundColor: ok ? Colors.green : Colors.red,
    ));
    if (ok) widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #${order.orderId}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Customer: ${order.customerEmail ?? order.customerName ?? 'Unknown'}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  Text(
                    'Total: \$${order.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ],
              ),
            ),
            if (_loading)
              const SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else ...[
              OutlinedButton(
                onPressed: () => _resolve('reject'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Reject'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _resolve('accept'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Accept'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
