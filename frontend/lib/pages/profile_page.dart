import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  bool _isLoading = true;

  String? _taxId;
  List<Order> _orders = [];
  List<Map<String, dynamic>> _savedAddresses = [];
  List<Map<String, dynamic>> _savedCards = [];

  // Add address form
  bool _showAddAddress = false;
  bool _isSavingAddress = false;
  final _addressFormKey = GlobalKey<FormState>();
  final _addressLabelController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _countryController = TextEditingController();

  // Add card form
  bool _showAddCard = false;
  bool _isSavingCard = false;
  final _cardFormKey = GlobalKey<FormState>();
  final _cardLabelController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _holderNameController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();

  User? get _user => FirebaseAuth.instance.currentUser;

  String? get _homeAddress {
    for (final addr in _savedAddresses) {
      if (addr['is_default'] == true) {
        final street = addr['street'] ?? '';
        final city = addr['city'] ?? '';
        final zip = addr['zip_code'] ?? '';
        final country = addr['country'] ?? '';
        return '$street, $city $zip, $country';
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _addressLabelController.dispose();
    _recipientNameController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _zipCodeController.dispose();
    _countryController.dispose();
    _cardLabelController.dispose();
    _cardNumberController.dispose();
    _holderNameController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
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
      _orders = orders;
      _savedAddresses = addresses;
      _savedCards = cards;
      _isLoading = false;
    });
  }

  Future<void> _addAddress() async {
    if (!_addressFormKey.currentState!.validate()) return;
    setState(() => _isSavingAddress = true);
    final savedData = await PaymentService.saveAddress(
      label: _addressLabelController.text.trim(),
      recipientName: _recipientNameController.text.trim(),
      street: _streetController.text.trim(),
      city: _cityController.text.trim(),
      zipCode: _zipCodeController.text.trim(),
      country: _countryController.text.trim(),
      isDefault: _savedAddresses.isEmpty,
    );
    if (!mounted) return;
    setState(() => _isSavingAddress = false);
    if (savedData != null) {
      setState(() {
        _savedAddresses.add(savedData);
        _showAddAddress = false;
        _addressLabelController.clear();
        _recipientNameController.clear();
        _streetController.clear();
        _cityController.clear();
        _zipCodeController.clear();
        _countryController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Address saved.'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save address.'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _addCard() async {
    if (!_cardFormKey.currentState!.validate()) return;
    setState(() => _isSavingCard = true);
    final savedData = await PaymentService.savePaymentCard(
      label: _cardLabelController.text.trim(),
      cardNumber: _cardNumberController.text.replaceAll(' ', ''),
      holderName: _holderNameController.text.trim(),
      expiryDate: _expiryController.text,
      isDefault: _savedCards.isEmpty,
    );
    if (!mounted) return;
    setState(() => _isSavingCard = false);
    if (savedData != null) {
      setState(() {
        _savedCards.add(savedData);
        _showAddCard = false;
        _cardLabelController.clear();
        _cardNumberController.clear();
        _holderNameController.clear();
        _expiryController.clear();
        _cvvController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Card saved.'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save card.'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteAddress(int id) async {
    final success = await PaymentService.deleteAddress(id);
    if (!mounted) return;
    if (success) {
      setState(() => _savedAddresses.removeWhere((addr) => addr['id'] == id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Address deleted.'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete address.'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteCard(int id) async {
    final success = await PaymentService.deletePaymentCard(id);
    if (!mounted) return;
    if (success) {
      setState(() => _savedCards.removeWhere((card) => card['id'] == id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Card deleted.'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete card.'), backgroundColor: Colors.red),
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
        const SnackBar(content: Text('Default address updated.'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update default address.'), backgroundColor: Colors.red),
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
        const SnackBar(content: Text('Default card updated.'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update default card.'), backgroundColor: Colors.red),
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
            style: TextStyle(color: _dark, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _dark,
              foregroundColor: _offWhite,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
                _InfoRow(label: 'Home Address', value: _homeAddress ?? '—'),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Saved Addresses ────────────────────────────────────────
          const _SectionTitle('Saved Addresses'),
          const SizedBox(height: 12),
          if (_savedAddresses.isEmpty && !_showAddAddress)
            _SectionCard(
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Column(
                    children: [
                      Icon(Icons.location_on_outlined, size: 48, color: _taupe),
                      SizedBox(height: 12),
                      Text('No saved addresses yet.', style: TextStyle(color: _medium, fontSize: 15)),
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
          if (_showAddAddress) ...[
            const SizedBox(height: 12),
            _buildAddAddressForm(),
          ],
          const SizedBox(height: 12),
          if (!_showAddAddress)
            SizedBox(
              width: double.infinity,
              child: _buildAddAddressButton(),
            ),
          const SizedBox(height: 28),

          // ── Saved Payment Cards ────────────────────────────────────
          const _SectionTitle('Saved Payment Cards'),
          const SizedBox(height: 12),
          if (_savedCards.isEmpty && !_showAddCard)
            _SectionCard(
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Column(
                    children: [
                      Icon(Icons.credit_card_outlined, size: 48, color: _taupe),
                      SizedBox(height: 12),
                      Text('No saved cards yet.', style: TextStyle(color: _medium, fontSize: 15)),
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
          if (_showAddCard) ...[
            const SizedBox(height: 12),
            _buildAddCardForm(),
          ],
          const SizedBox(height: 12),
          if (!_showAddCard)
            SizedBox(
              width: double.infinity,
              child: _buildAddCardButton(),
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
                      Icon(Icons.receipt_long_outlined, size: 48, color: _taupe),
                      SizedBox(height: 12),
                      Text('No orders yet.', style: TextStyle(color: _medium, fontSize: 15)),
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

  Widget _buildAddAddressButton() {
    return OutlinedButton.icon(
      onPressed: () => setState(() => _showAddAddress = true),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: const BorderSide(color: _dark, width: 1.5),
        foregroundColor: _dark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: const Icon(Icons.add, size: 20),
      label: const Text('Add New Address', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildAddAddressForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _taupe, width: 1.5),
      ),
      child: Form(
        key: _addressFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add New Address',
                  style: TextStyle(color: _dark, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: _medium),
                  onPressed: () => setState(() {
                    _showAddAddress = false;
                    _addressFormKey.currentState?.reset();
                    _addressLabelController.clear();
                    _recipientNameController.clear();
                    _streetController.clear();
                    _cityController.clear();
                    _zipCodeController.clear();
                    _countryController.clear();
                  }),
                  splashRadius: 20,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _addressLabelController,
              label: 'Label (Optional)',
              hint: 'e.g., Home, Work, School',
              icon: Icons.label_outline,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _recipientNameController,
              label: 'Recipient Name',
              hint: 'John Doe',
              icon: Icons.person_outline,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter recipient name' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _streetController,
              label: 'Street Address',
              hint: '123 Main Street',
              icon: Icons.home_outlined,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter street address' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _cityController,
                    label: 'City',
                    hint: 'New York',
                    icon: Icons.location_city_outlined,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _zipCodeController,
                    label: 'ZIP Code',
                    hint: '10001',
                    icon: Icons.markunread_mailbox_outlined,
                    keyboardType: TextInputType.number,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _countryController,
              label: 'Country',
              hint: 'United States',
              icon: Icons.public,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter country' : null,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSavingAddress ? null : _addAddress,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _dark,
                  foregroundColor: _offWhite,
                  disabledBackgroundColor: _taupe,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isSavingAddress
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(color: _offWhite, strokeWidth: 2),
                      )
                    : const Text('Save Address', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddCardButton() {
    return OutlinedButton.icon(
      onPressed: () => setState(() => _showAddCard = true),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: const BorderSide(color: _dark, width: 1.5),
        foregroundColor: _dark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: const Icon(Icons.add, size: 20),
      label: const Text('Add New Card', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildAddCardForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _taupe, width: 1.5),
      ),
      child: Form(
        key: _cardFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add New Card',
                  style: TextStyle(color: _dark, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: _medium),
                  onPressed: () => setState(() {
                    _showAddCard = false;
                    _cardFormKey.currentState?.reset();
                    _cardLabelController.clear();
                    _cardNumberController.clear();
                    _holderNameController.clear();
                    _expiryController.clear();
                    _cvvController.clear();
                  }),
                  splashRadius: 20,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _cardLabelController,
              label: 'Label (Optional)',
              hint: 'e.g., Personal, Business',
              icon: Icons.label_outline,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _holderNameController,
              label: 'Cardholder Name',
              hint: 'John Doe',
              icon: Icons.person_outline,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter cardholder name' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _cardNumberController,
              label: 'Card Number',
              hint: '1234 5678 9012 3456',
              icon: Icons.credit_card,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(16),
                _CardNumberFormatter(),
              ],
              validator: (v) {
                if (v == null || v.isEmpty) return 'Please enter card number';
                if (v.replaceAll(' ', '').length != 16) return 'Card number must be 16 digits';
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _expiryController,
                    label: 'Expiry Date',
                    hint: 'MM/YY',
                    icon: Icons.calendar_today,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                      _ExpiryDateFormatter(),
                    ],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      final parts = v.split('/');
                      if (parts.length != 2) return 'Invalid format';
                      final month = int.tryParse(parts[0]);
                      final year = int.tryParse(parts[1]);
                      if (month == null || month < 1 || month > 12) return 'Invalid month';
                      if (year == null) return 'Invalid year';
                      final now = DateTime.now();
                      final currentYear = now.year % 100;
                      final currentMonth = now.month;
                      if (year < currentYear || (year == currentYear && month < currentMonth)) {
                        return 'Card expired';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _cvvController,
                    label: 'CVV',
                    hint: '123',
                    icon: Icons.lock_outline,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (v.length != 3) return 'Must be 3 digits';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSavingCard ? null : _addCard,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _dark,
                  foregroundColor: _offWhite,
                  disabledBackgroundColor: _taupe,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isSavingCard
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(color: _offWhite, strokeWidth: 2),
                      )
                    : const Text('Save Card', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _dark, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          obscureText: obscureText,
          validator: validator,
          style: const TextStyle(fontSize: 15, color: _dark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _medium),
            prefixIcon: Icon(icon, size: 20, color: _medium),
            filled: true,
            fillColor: _cream.withValues(alpha: 0.3),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              borderSide: const BorderSide(color: _dark, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
          ),
        ),
      ],
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
              style: const TextStyle(color: _dark, fontSize: 13),
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
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
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
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(order.createdAt),
                          style: const TextStyle(color: _medium, fontSize: 12),
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
                        style: const TextStyle(color: _medium, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: _medium),
                ],
              ),
            ),
            if (_expanded) ...[
              const Divider(color: _taupe, height: 1, indent: 16, endIndent: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailRow('Date & Time', _formatDateTime(order.createdAt)),
                    _DetailRow(
                      'Delivery Address',
                      order.deliveryAddress.isEmpty ? '—' : order.deliveryAddress,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Items',
                      style: TextStyle(color: _dark, fontSize: 13, fontWeight: FontWeight.w700),
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
                          style: TextStyle(color: _dark, fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '\$${order.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(color: _dark, fontSize: 16, fontWeight: FontWeight.w800),
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
              style: const TextStyle(color: _medium, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: _dark, fontSize: 12)),
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
            style: const TextStyle(color: _dark, fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              Text('Qty: ${item.quantity}', style: const TextStyle(color: _medium, fontSize: 11)),
              Text('\$${item.unitPrice.toStringAsFixed(2)} each', style: const TextStyle(color: _medium, fontSize: 11)),
              Text(
                'Subtotal: \$${item.subtotal.toStringAsFixed(2)}',
                style: const TextStyle(color: _dark, fontSize: 11, fontWeight: FontWeight.w700),
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
                        style: const TextStyle(color: _dark, fontSize: 13, fontWeight: FontWeight.w600),
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
                  decoration: BoxDecoration(color: _dark, borderRadius: BorderRadius.circular(4)),
                  child: const Text(
                    'DEFAULT',
                    style: TextStyle(color: _offWhite, fontSize: 10, fontWeight: FontWeight.w700),
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
          Text('${address['street']}', style: const TextStyle(color: _dark, fontSize: 13)),
          Text('${address['city']}, ${address['zip_code']}', style: const TextStyle(color: _dark, fontSize: 13)),
          Text('${address['country']}', style: const TextStyle(color: _dark, fontSize: 13)),
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
                        style: const TextStyle(color: _dark, fontSize: 13, fontWeight: FontWeight.w600),
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
                    Text('•••• •••• •••• $last4', style: const TextStyle(color: _medium, fontSize: 13)),
                  ],
                ),
              ),
              if (isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: _dark, borderRadius: BorderRadius.circular(4)),
                  child: const Text(
                    'DEFAULT',
                    style: TextStyle(color: _offWhite, fontSize: 10, fontWeight: FontWeight.w700),
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
          Text('Expires: ${card['expiry_date']}', style: const TextStyle(color: _medium, fontSize: 12)),
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

// ─────────────────────────────────────────────────────────────────
// Input formatters
// ─────────────────────────────────────────────────────────────────

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(text[i]);
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll('/', '');
    if (text.length <= 2) return newValue.copyWith(text: text);
    return newValue.copyWith(
      text: '${text.substring(0, 2)}/${text.substring(2)}',
      selection: TextSelection.collapsed(offset: text.length + 1),
    );
  }
}
