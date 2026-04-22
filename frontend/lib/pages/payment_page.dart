import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../services/payment_service.dart';
import 'payment_success_page.dart';

const _dark = Color(0xFF8D7B68);
const _medium = Color(0xFFA4907C);
const _taupe = Color(0xFFC8B6A6);
const _cream = Color(0xFFF1DEC9);
const _offWhite = Color(0xFFFAF5EF);

class DeliveryAddress {
  final String id;
  final String label;
  final String recipientName;
  final String street;
  final String city;
  final String zipCode;
  final String country;
  final bool isDefault;

  const DeliveryAddress({
    required this.id,
    this.label = '',
    required this.recipientName,
    required this.street,
    required this.city,
    required this.zipCode,
    required this.country,
    this.isDefault = false,
  });

  String get fullAddress => '$street, $city $zipCode, $country';
  String get displayName => label.isNotEmpty ? label : recipientName;
}

class PaymentCard {
  final String id;
  final String label;
  final String cardNumber;
  final String holderName;
  final String expiryDate;
  final bool isDefault;

  const PaymentCard({
    required this.id,
    this.label = '',
    required this.cardNumber,
    required this.holderName,
    required this.expiryDate,
    this.isDefault = false,
  });

  String get maskedNumber =>
      '**** **** **** ${cardNumber.substring(cardNumber.length - 4)}';
  String get displayName => label.isNotEmpty ? label : holderName;
}

class PaymentPage extends StatefulWidget {
  final double totalAmount;

  const PaymentPage({super.key, required this.totalAmount});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  List<DeliveryAddress> _savedAddresses = [];
  String? _selectedAddressId;
  bool _showAddAddress = false;

  List<PaymentCard> _savedCards = [];
  String? _selectedCardId;
  bool _showAddCard = false;

  final _addressFormKey = GlobalKey<FormState>();
  final _addressLabelController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _countryController = TextEditingController();
  bool _saveAddress = false;

  final _cardFormKey = GlobalKey<FormState>();
  final _cardLabelController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _holderNameController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  bool _saveCard = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    try {
      final addresses = await PaymentService.fetchAddresses();
      final cards = await PaymentService.fetchPaymentCards();

      if (mounted) {
        setState(() {
          _savedAddresses = addresses.map((data) => DeliveryAddress(
            id: data['id'].toString(),
            label: data['label'] ?? '',
            recipientName: data['recipient_name'] ?? '',
            street: data['street'] ?? '',
            city: data['city'] ?? '',
            zipCode: data['zip_code'] ?? '',
            country: data['country'] ?? '',
            isDefault: data['is_default'] ?? false,
          )).toList();

          _savedCards = cards.map((data) => PaymentCard(
            id: data['id'].toString(),
            label: data['label'] ?? '',
            cardNumber: data['card_number'] ?? '',
            holderName: data['holder_name'] ?? '',
            expiryDate: data['expiry_date'] ?? '',
            isDefault: data['is_default'] ?? false,
          )).toList();

          if (_savedAddresses.isNotEmpty) {
            _selectedAddressId = _savedAddresses.firstWhere((a) => a.isDefault, orElse: () => _savedAddresses.first).id;
          }
          if (_savedCards.isNotEmpty) {
            _selectedCardId = _savedCards.firstWhere((c) => c.isDefault, orElse: () => _savedCards.first).id;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {});
      }
    }
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

  Future<void> _handlePayment() async {
    if (_savedAddresses.isEmpty && !_showAddAddress) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a delivery address'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_showAddAddress) {
      if (!_addressFormKey.currentState!.validate()) return;
    } else if (_selectedAddressId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a delivery address'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_savedCards.isEmpty && !_showAddCard) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a payment method'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_showAddCard) {
      if (!_cardFormKey.currentState!.validate()) return;
    } else if (_selectedCardId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a card'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Save address to backend if requested
      if (_showAddAddress && _saveAddress) {
        final savedData = await PaymentService.saveAddress(
          label: _addressLabelController.text.trim(),
          recipientName: _recipientNameController.text,
          street: _streetController.text,
          city: _cityController.text,
          zipCode: _zipCodeController.text,
          country: _countryController.text,
          isDefault: _savedAddresses.isEmpty,
        );
        
        if (savedData != null) {
          final newAddress = DeliveryAddress(
            id: savedData['id'].toString(),
            label: savedData['label'] ?? '',
            recipientName: savedData['recipient_name'],
            street: savedData['street'],
            city: savedData['city'],
            zipCode: savedData['zip_code'],
            country: savedData['country'],
            isDefault: savedData['is_default'],
          );
          setState(() {
            _savedAddresses.add(newAddress);
            _selectedAddressId = newAddress.id;
            _showAddAddress = false;
          });
        } else {
          throw Exception('Failed to save address');
        }
      }

      // Save card to backend if requested (MOCK DATA ONLY)
      if (_showAddCard && _saveCard) {
        final savedData = await PaymentService.savePaymentCard(
          label: _cardLabelController.text.trim(),
          cardNumber: _cardNumberController.text.replaceAll(' ', ''),
          holderName: _holderNameController.text,
          expiryDate: _expiryController.text,
          isDefault: _savedCards.isEmpty,
        );
        
        if (savedData != null) {
          final newCard = PaymentCard(
            id: savedData['id'].toString(),
            label: savedData['label'] ?? '',
            cardNumber: savedData['card_number'],
            holderName: savedData['holder_name'],
            expiryDate: savedData['expiry_date'],
            isDefault: savedData['is_default'],
          );
          setState(() {
            _savedCards.add(newCard);
            _selectedCardId = newCard.id;
            _showAddCard = false;
          });
        } else {
          throw Exception('Failed to save card');
        }
      }

      // Get Django JWT token from AuthService
      final headers = await AuthService.getAuthHeaders();
      
      // Build shipping address string
      String shippingAddress;
      if (_showAddAddress) {
        shippingAddress = '${_recipientNameController.text}, ${_streetController.text}, ${_cityController.text} ${_zipCodeController.text}, ${_countryController.text}';
      } else {
        final selectedAddress = _savedAddresses.firstWhere((a) => a.id == _selectedAddressId);
        shippingAddress = '${selectedAddress.recipientName}, ${selectedAddress.fullAddress}';
      }
      
      // Get card last 4 digits
      String cardLastFour;
      if (_showAddCard) {
        cardLastFour = _cardNumberController.text.replaceAll(' ', '').substring(12);
      } else {
        final selectedCard = _savedCards.firstWhere((c) => c.id == _selectedCardId);
        cardLastFour = selectedCard.cardNumber.substring(selectedCard.cardNumber.length - 4);
      }
      
      // Call backend checkout API
      final Map<String, dynamic> payload = {
        'shipping_address': shippingAddress,
        'card_last_four': cardLastFour,
      };
      
      // Include IDs if using saved address/card (to mark as default)
      if (!_showAddAddress && _selectedAddressId != null) {
        payload['address_id'] = _selectedAddressId!;
      }
      if (!_showAddCard && _selectedCardId != null) {
        payload['card_id'] = _selectedCardId!;
      }
      
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/checkout/'),
        headers: headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Payment successful!'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => PaymentSuccessPage(
              orderNumber: data['order_number'] ?? 'N/A',
              totalAmount: data['total_amount']?.toDouble() ?? 0.0,
            ),
          ),
        );
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Payment failed');
      }
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
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
          'Payment',
          style: TextStyle(
            color: _offWhite,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAmountCard(),
            const SizedBox(height: 24),
            if (_savedAddresses.isNotEmpty && !_showAddAddress) ...[
              _buildSavedAddressesSection(),
              const SizedBox(height: 20),
            ],
            if (_showAddAddress) ...[
              _buildAddAddressForm(),
              const SizedBox(height: 20),
            ],
            if (!_showAddAddress) _buildAddAddressButton(),
            const SizedBox(height: 32),
            const Divider(color: _taupe, thickness: 1),
            const SizedBox(height: 32),
            if (_savedCards.isNotEmpty && !_showAddCard) ...[
              _buildSavedCardsSection(),
              const SizedBox(height: 20),
            ],
            if (_showAddCard) ...[
              _buildAddCardForm(),
              const SizedBox(height: 20),
            ],
            if (!_showAddCard) _buildAddCardButton(),
            const SizedBox(height: 24),
            _buildPayButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _taupe, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Total Amount',
            style: TextStyle(
              color: _medium,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '\$${widget.totalAmount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: _dark,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedAddressesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Delivery Address',
          style: TextStyle(
            color: _dark,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ..._savedAddresses.map(
          (address) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildAddressTile(address),
          ),
        ),
      ],
    );
  }

  Widget _buildAddressTile(DeliveryAddress address) {
    final isSelected = _selectedAddressId == address.id;
    return GestureDetector(
      onTap: () => setState(() => _selectedAddressId = address.id),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? _cream : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? _dark : _taupe,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.location_on_outlined,
              color: isSelected ? _dark : _medium,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    address.recipientName,
                    style: const TextStyle(
                      color: _dark,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address.fullAddress,
                    style: const TextStyle(
                      color: _medium,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: _dark, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildAddAddressButton() {
    return OutlinedButton.icon(
      onPressed: () => setState(() => _showAddAddress = true),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: BorderSide(color: _dark, width: 1.5),
        foregroundColor: _dark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: const Icon(Icons.add, size: 20),
      label: const Text(
        'Add New Address',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
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
                  style: TextStyle(
                    color: _dark,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: _medium),
                  onPressed: () {
                    setState(() {
                      _showAddAddress = false;
                      _addressFormKey.currentState?.reset();
                    });
                  },
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
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter recipient name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _streetController,
              label: 'Street Address',
              hint: '123 Main Street',
              icon: Icons.home_outlined,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter street address';
                }
                return null;
              },
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
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
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
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
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
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter country';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _cream.withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: _saveAddress,
                    activeColor: _dark,
                    onChanged: (value) {
                      setState(() => _saveAddress = value ?? false);
                    },
                  ),
                  const Expanded(
                    child: Text(
                      'Save this address for future orders',
                      style: TextStyle(color: _dark, fontSize: 14),
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

  Widget _buildSavedCardsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Saved Payment Methods',
          style: TextStyle(
            color: _dark,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ..._savedCards.map(
          (card) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildCardTile(card),
          ),
        ),
      ],
    );
  }

  Widget _buildCardTile(PaymentCard card) {
    final isSelected = _selectedCardId == card.id;
    return GestureDetector(
      onTap: () => setState(() => _selectedCardId = card.id),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? _cream : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? _dark : _taupe,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.credit_card,
              color: isSelected ? _dark : _medium,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.holderName,
                    style: TextStyle(
                      color: _dark,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    card.maskedNumber,
                    style: const TextStyle(color: _medium, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Expires ${card.expiryDate}',
                    style: const TextStyle(color: _medium, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: _dark, size: 24),
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
        side: BorderSide(color: _dark, width: 1.5),
        foregroundColor: _dark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: const Icon(Icons.add, size: 20),
      label: const Text(
        'Add New Card',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
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
                  style: TextStyle(
                    color: _dark,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: _medium),
                  onPressed: () {
                    setState(() {
                      _showAddCard = false;
                      _cardFormKey.currentState?.reset();
                    });
                  },
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
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter cardholder name';
                }
                return null;
              },
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
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter card number';
                }
                final digits = value.replaceAll(' ', '');
                if (digits.length != 16) {
                  return 'Card number must be 16 digits';
                }
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
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      final parts = value.split('/');
                      if (parts.length != 2) return 'Invalid format';

                      final month = int.tryParse(parts[0]);
                      final year = int.tryParse(parts[1]);

                      if (month == null || month < 1 || month > 12) {
                        return 'Invalid month';
                      }

                      if (year == null) return 'Invalid year';

                      final now = DateTime.now();
                      final currentYear = now.year % 100;
                      final currentMonth = now.month;

                      if (year < currentYear ||
                          (year == currentYear && month < currentMonth)) {
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
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (value.length != 3) {
                        return 'Must be 3 digits';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _cream.withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: _saveCard,
                    activeColor: _dark,
                    onChanged: (value) {
                      setState(() => _saveCard = value ?? false);
                    },
                  ),
                  const Expanded(
                    child: Text(
                      'Save this card for future purchases',
                      style: TextStyle(color: _dark, fontSize: 14),
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
        Text(
          label,
          style: const TextStyle(
            color: _dark,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
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
            fillColor: _cream.withOpacity(0.3),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: _taupe),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: _taupe),
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

  Widget _buildPayButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _handlePayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: _dark,
          foregroundColor: _offWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
          disabledBackgroundColor: _medium,
        ),
        child: _isProcessing
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(_offWhite),
                ),
              )
            : Text(
                'Pay \$${widget.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
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
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll('/', '');
    if (text.length <= 2) {
      return newValue.copyWith(text: text);
    }
    return newValue.copyWith(
      text: '${text.substring(0, 2)}/${text.substring(2)}',
      selection: TextSelection.collapsed(offset: text.length + 1),
    );
  }
}
