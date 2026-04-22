import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/order.dart';
import '../services/user_service.dart';
import '../services/payment_service.dart';

const _dark = Color(0xFF8D7B68);
const _medium = Color(0xFFA4907C);
const _taupe = Color(0xFFC8B6A6);
const _cream = Color(0xFFF1DEC9);
const _offWhite = Color(0xFFFAF5EF);

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final UserService _userService = UserService();
  final _addressController = TextEditingController();

  bool _isLoading = true;
  bool _isSavingAddress = false;

  String? _taxId;
  String? _homeAddress;
  List<Order> _orders = [];
  List<Map<String, dynamic>> _savedAddresses = [];
  List<Map<String, dynamic>> _savedCards = [];

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final profile = await _userService.fetchProfile();
    final orders = await _userService.fetchOrderHistory();
    final addresses = await PaymentService.fetchAddresses();
    final cards = await PaymentService.fetchPaymentCards();
    if (!mounted) return;
    setState(() {
      _taxId = profile?['tax_id'] as String?;
      _homeAddress = profile?['home_address'] as String?;
      _addressController.text = _homeAddress ?? '';
      _orders = orders;
      _savedAddresses = addresses;
      _savedCards = cards;
      _isLoading = false;
    });
  }

  Future<void> _saveAddress() async {
    setState(() => _isSavingAddress = true);
    final success =
        await _userService.updateAddress(_addressController.text.trim());
    if (!mounted) return;
    setState(() {
      _isSavingAddress = false;
      if (success) _homeAddress = _addressController.text.trim();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            success ? 'Address updated.' : 'Failed to update address.'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _deleteAddress(int id) async {
    final success = await PaymentService.deleteAddress(id);
    if (!mounted) return;
    if (success) {
      setState(() {
        _savedAddresses.removeWhere((addr) => addr['id'] == id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Address deleted.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete address.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteCard(int id) async {
    final success = await PaymentService.deletePaymentCard(id);
    if (!mounted) return;
    if (success) {
      setState(() {
        _savedCards.removeWhere((card) => card['id'] == id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Card deleted.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete card.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _setAddressDefault(int id) async {
    final success = await PaymentService.setAddressDefault(id);
    if (!mounted) return;
    if (success) {
      setState(() {
        for (var addr in _savedAddresses) {
          addr['is_default'] = (addr['id'] == id);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Default address updated.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update default address.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _setCardDefault(int id) async {
    final success = await PaymentService.setCardDefault(id);
    if (!mounted) return;
    if (success) {
      setState(() {
        for (var card in _savedCards) {
          card['is_default'] = (card['id'] == id);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Default card updated.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update default card.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _offWhite,
      appBar: AppBar(
        backgroundColor: _dark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _offWhite),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Account',
          style: TextStyle(
            color: _offWhite,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _dark))
          : Builder(builder: (context) {
              final user = _user;
              if (user == null) return _buildNotLoggedIn(context);
              return _buildContent(context, user);
            }),
    );
  }

  Widget _buildNotLoggedIn(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.account_circle_outlined, size: 80, color: _taupe),
          const SizedBox(height: 20),
          const Text(
            'You are not logged in.',
            style: TextStyle(
                color: _dark, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _dark,
              foregroundColor: _offWhite,
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('Log In'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, User user) {
    final nameParts = (user.displayName ?? '').trim().split(' ');
    final initials = nameParts.length >= 2
        ? '${nameParts.first[0]}${nameParts.last[0]}'.toUpperCase()
        : (user.displayName?.isNotEmpty == true
            ? user.displayName![0].toUpperCase()
            : '?');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── User info card ─────────────────────────────────────────
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: _taupe,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: _offWhite,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        user.displayName ?? 'User',
                        style: const TextStyle(
                          color: _dark,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(color: _taupe, height: 1),
                const SizedBox(height: 14),
                _InfoRow(label: 'User ID', value: user.uid),
                _InfoRow(label: 'Email', value: user.email ?? '—'),
                _InfoRow(label: 'Tax ID', value: _taxId ?? '—'),
                _InfoRow(
                    label: 'Home Address', value: _homeAddress ?? '—'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Address editing ────────────────────────────────────────
          const _SectionTitle('Delivery Address'),
          const SizedBox(height: 12),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _addressController,
                  maxLines: 3,
                  style: const TextStyle(color: _dark, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Enter your delivery address...',
                    hintStyle: const TextStyle(color: _taupe),
                    filled: true,
                    fillColor: _offWhite,
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _taupe),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _taupe),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: _dark, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSavingAddress ? null : _saveAddress,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _dark,
                      foregroundColor: _offWhite,
                      disabledBackgroundColor: _taupe,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: _isSavingAddress
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              color: _offWhite,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Save Address',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Saved Addresses ────────────────────────────────────────
          const _SectionTitle('Saved Addresses'),
          const SizedBox(height: 12),
          if (_savedAddresses.isEmpty)
            _SectionCard(
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Column(
                    children: [
                      Icon(Icons.location_on_outlined, size: 48, color: _taupe),
                      SizedBox(height: 12),
                      Text(
                        'No saved addresses yet.',
                        style: TextStyle(color: _medium, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ..._savedAddresses.map(
              (addr) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AddressCard(address: addr, onDelete: _deleteAddress, onSetDefault: _setAddressDefault),
              ),
            ),
          const SizedBox(height: 28),

          // ── Saved Payment Cards ────────────────────────────────────
          const _SectionTitle('Saved Payment Cards'),
          const SizedBox(height: 12),
          if (_savedCards.isEmpty)
            _SectionCard(
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Column(
                    children: [
                      Icon(Icons.credit_card_outlined, size: 48, color: _taupe),
                      SizedBox(height: 12),
                      Text(
                        'No saved cards yet.',
                        style: TextStyle(color: _medium, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ..._savedCards.map(
              (card) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CardCard(card: card, onDelete: _deleteCard, onSetDefault: _setCardDefault),
              ),
            ),
          const SizedBox(height: 28),

          // ── Order history ──────────────────────────────────────────
          const _SectionTitle('Order History'),
          const SizedBox(height: 12),
          if (_orders.isEmpty)
            _SectionCard(
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 48, color: _taupe),
                      SizedBox(height: 12),
                      Text(
                        'No orders yet.',
                        style: TextStyle(color: _medium, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ..._orders.map(
              (order) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _OrderCard(order: order),
              ),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Shared sub-widgets
// ─────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _dark,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cream,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _taupe),
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: _medium,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: _dark,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Expandable order card
// ─────────────────────────────────────────────────────────────────

class _OrderCard extends StatefulWidget {
  final Order order;
  const _OrderCard({required this.order});

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _expanded = false;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  String _formatDate(DateTime dt) =>
      '${_months[dt.month - 1]} ${dt.day}, ${dt.year}';

  String _formatDateTime(DateTime dt) {
    final h = dt.hour > 12
        ? dt.hour - 12
        : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${_formatDate(dt)}  $h:$min $period';
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        width: double.infinity,
        decoration: BoxDecoration(
          color: _cream,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _expanded ? _dark : _taupe,
            width: _expanded ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Summary row (always visible) ──────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #${order.orderId}',
                          style: const TextStyle(
                            color: _dark,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _formatDate(order.createdAt),
                          style:
                              const TextStyle(color: _medium, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${order.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: _dark,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${order.items.length} item${order.items.length == 1 ? '' : 's'}',
                        style:
                            const TextStyle(color: _medium, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: _medium,
                  ),
                ],
              ),
            ),

            // ── Expanded details ──────────────────────────────────
            if (_expanded) ...[
              const Divider(
                  color: _taupe, height: 1, indent: 16, endIndent: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailRow(
                        'Date & Time', _formatDateTime(order.createdAt)),
                    _DetailRow(
                      'Delivery Address',
                      order.deliveryAddress.isEmpty
                          ? '—'
                          : order.deliveryAddress,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Items',
                      style: TextStyle(
                        color: _dark,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...order.items.map((item) => _OrderItemRow(item: item)),
                    const SizedBox(height: 10),
                    const Divider(color: _taupe, height: 1),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            color: _dark,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '\$${order.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: _dark,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                  color: _medium,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: _dark, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  final OrderItem item;
  const _OrderItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _offWhite,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _taupe),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.productName,
            style: const TextStyle(
                color: _dark, fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              Text('ID: ${item.productId}',
                  style:
                      const TextStyle(color: _medium, fontSize: 11)),
              Text('Qty: ${item.quantity}',
                  style:
                      const TextStyle(color: _medium, fontSize: 11)),
              Text('\$${item.unitPrice.toStringAsFixed(2)} each',
                  style:
                      const TextStyle(color: _medium, fontSize: 11)),
              Text(
                'Subtotal: \$${item.subtotal.toStringAsFixed(2)}',
                style: const TextStyle(
                    color: _dark,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Address and Card display cards
// ─────────────────────────────────────────────────────────────────

class _AddressCard extends StatelessWidget {
  final Map<String, dynamic> address;
  final Function(int) onDelete;
  final Function(int)? onSetDefault;
  const _AddressCard({required this.address, required this.onDelete, this.onSetDefault});

  @override
  Widget build(BuildContext context) {
    final isDefault = address['is_default'] == true;
    final label = address['label'] ?? '';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cream,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDefault ? _dark : _taupe, width: isDefault ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (label.isNotEmpty)
                      Text(
                        label,
                        style: const TextStyle(
                          color: _dark,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    Text(
                      address['recipient_name'] ?? '',
                      style: TextStyle(
                        color: _dark,
                        fontSize: 15,
                        fontWeight: label.isEmpty ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _dark,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'DEFAULT',
                    style: TextStyle(
                      color: _offWhite,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: _medium, size: 20),
                onPressed: () => onDelete(address['id']),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${address['street']}',
            style: const TextStyle(color: _dark, fontSize: 13),
          ),
          Text(
            '${address['city']}, ${address['zip_code']}',
            style: const TextStyle(color: _dark, fontSize: 13),
          ),
          Text(
            '${address['country']}',
            style: const TextStyle(color: _dark, fontSize: 13),
          ),
          if (!isDefault && onSetDefault != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => onSetDefault!(address['id']),
              icon: const Icon(Icons.check_circle_outline, size: 16, color: _dark),
              label: const Text(
                'Set as Default',
                style: TextStyle(color: _dark, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                backgroundColor: _offWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: const BorderSide(color: _taupe),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CardCard extends StatelessWidget {
  final Map<String, dynamic> card;
  final Function(int) onDelete;
  final Function(int)? onSetDefault;
  const _CardCard({required this.card, required this.onDelete, this.onSetDefault});

  @override
  Widget build(BuildContext context) {
    final isDefault = card['is_default'] == true;
    final cardNumber = card['card_number'] ?? '';
    final last4 = cardNumber.length >= 4 ? cardNumber.substring(cardNumber.length - 4) : cardNumber;
    final label = card['label'] ?? '';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cream,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDefault ? _dark : _taupe, width: isDefault ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.credit_card, color: _dark, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (label.isNotEmpty)
                      Text(
                        label,
                        style: const TextStyle(
                          color: _dark,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    Text(
                      card['holder_name'] ?? '',
                      style: TextStyle(
                        color: _dark,
                        fontSize: 15,
                        fontWeight: label.isEmpty ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '•••• •••• •••• $last4',
                      style: const TextStyle(color: _medium, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _dark,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'DEFAULT',
                    style: TextStyle(
                      color: _offWhite,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: _medium, size: 20),
                onPressed: () => onDelete(card['id']),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Expires: ${card['expiry_date']}',
            style: const TextStyle(color: _medium, fontSize: 12),
          ),
          if (!isDefault && onSetDefault != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => onSetDefault!(card['id']),
              icon: const Icon(Icons.check_circle_outline, size: 16, color: _dark),
              label: const Text(
                'Set as Default',
                style: TextStyle(color: _dark, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                backgroundColor: _offWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: const BorderSide(color: _taupe),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
