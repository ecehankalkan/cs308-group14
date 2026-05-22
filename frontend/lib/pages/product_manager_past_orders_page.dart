// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import '../models/order.dart';
import '../services/product_admin_service.dart';

class ProductManagerPastOrdersPage extends StatefulWidget {
  const ProductManagerPastOrdersPage({super.key});

  @override
  State<ProductManagerPastOrdersPage> createState() =>
      _ProductManagerPastOrdersPageState();
}

class _ProductManagerPastOrdersPageState
    extends State<ProductManagerPastOrdersPage> {
  List<Order> _orders = [];
  bool _loading = false;
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    final orders = await ProductAdminService.fetchAllOrders();
    if (mounted) {
      setState(() {
        _orders = orders;
        _loading = false;
      });
    }
  }

  List<Order> get _filtered {
    if (_statusFilter == 'all') return _orders;
    return _orders.where((o) => o.status == _statusFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Past Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order Management',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'View all orders, update delivery status, and download invoices.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text('Filter by status: ',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _statusFilter,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(
                        value: 'processing', child: Text('Preparing')),
                    DropdownMenuItem(
                        value: 'in-transit', child: Text('In Transit')),
                    DropdownMenuItem(
                        value: 'delivered', child: Text('Delivered')),
                    DropdownMenuItem(
                        value: 'cancelled', child: Text('Cancelled')),
                    DropdownMenuItem(
                        value: 'refund-requested',
                        child: Text('Refund Requested')),
                    DropdownMenuItem(
                        value: 'refunded', child: Text('Refunded')),
                  ],
                  onChanged: (v) =>
                      setState(() => _statusFilter = v ?? 'all'),
                ),
                const Spacer(),
                Text(
                  '${filtered.length} order${filtered.length == 1 ? '' : 's'}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? const Center(child: Text('No orders found.'))
                      : RefreshIndicator(
                          onRefresh: _loadOrders,
                          child: ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, i) => _OrderCard(
                              order: filtered[i],
                              onStatusUpdated: _loadOrders,
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Order Card ────────────────────────────────────────────────────────────────

class _OrderCard extends StatefulWidget {
  final Order order;
  final VoidCallback onStatusUpdated;

  const _OrderCard({required this.order, required this.onStatusUpdated});

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _updatingStatus = false;

  static const Map<String, String> _labels = {
    'processing': 'Preparing',
    'in-transit': 'In Transit',
    'delivered': 'Delivered',
    'cancelled': 'Cancelled',
    'refund-requested': 'Refund Requested',
    'refunded': 'Refunded',
    'refund-rejected': 'Refund Rejected',
  };

  static const _updatableStatuses = ['processing', 'in-transit', 'delivered'];

  bool get _canUpdate => _updatableStatuses.contains(widget.order.status);

  Color _statusColor(String s) => switch (s) {
        'delivered' => Colors.green.shade700,
        'in-transit' => Colors.blue.shade700,
        'processing' => Colors.orange.shade700,
        'cancelled' => Colors.grey.shade600,
        'refund-requested' => Colors.red.shade400,
        'refunded' => Colors.teal.shade700,
        _ => Colors.red.shade700,
      };

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _updatingStatus = true);
    final ok = await ProductAdminService.updateDeliveryStatus(
        widget.order.orderId, newStatus);
    if (!mounted) return;
    setState(() => _updatingStatus = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Status updated to "${_labels[newStatus] ?? newStatus}"'
          : 'Failed to update status. Please try again.'),
      backgroundColor: ok ? Colors.green : Colors.red,
    ));
    if (ok) widget.onStatusUpdated();
  }

  void _downloadInvoice() {
    const baseUrl = 'http://127.0.0.1:8000';
    html.window.open(
      '$baseUrl/api/sales/orders/${widget.order.orderId}/invoice/?download=1',
      '_blank',
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final statusColor = _statusColor(order.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            // Order ID + date
            SizedBox(
              width: 90,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('#${order.orderId}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                  Text(_fmt(order.createdAt),
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Customer
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.customerName ?? '—',
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 13)),
                  Text(order.customerEmail ?? '—',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            // Total
            Text(
              '\$${order.totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(width: 12),
            // Status badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _labels[order.status] ?? order.status,
                style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),

          // ── Delivery address ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on_outlined,
                  size: 15, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  order.deliveryAddress.isNotEmpty
                      ? order.deliveryAddress
                      : '—',
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Items ──
          if (order.items.isNotEmpty) ...[
            const Text('Items',
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      if (item.productId != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'ID: ${item.productId}',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(item.productName,
                            style: const TextStyle(fontSize: 13)),
                      ),
                      Text('× ${item.quantity}',
                          style: const TextStyle(
                              fontSize: 13, color: Colors.grey)),
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
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 12),
          ],

          // ── Actions row ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Delivery status update
              if (_canUpdate)
                Row(
                  children: [
                    const Text('Delivery status:',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    if (_updatingStatus)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      DropdownButton<String>(
                        value: order.status,
                        underline: const SizedBox(),
                        isDense: true,
                        items: const [
                          DropdownMenuItem(
                              value: 'processing',
                              child: Text('Preparing')),
                          DropdownMenuItem(
                              value: 'in-transit',
                              child: Text('In Transit')),
                          DropdownMenuItem(
                              value: 'delivered',
                              child: Text('Delivered')),
                        ],
                        onChanged: (v) {
                          if (v != null && v != order.status) {
                            _updateStatus(v);
                          }
                        },
                      ),
                  ],
                )
              else
                Text(
                  'Status: ${_labels[order.status] ?? order.status}',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic),
                ),

              // Invoice download
              FilledButton.icon(
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('Download Invoice'),
                onPressed: _downloadInvoice,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
