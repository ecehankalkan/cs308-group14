import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class PaymentService {
  static const String _baseUrl = 'http://127.0.0.1:8000';

  // Fetch all saved delivery addresses
  static Future<List<Map<String, dynamic>>> fetchAddresses() async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/api/addresses/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      print('Error fetching addresses: $e');
    }
    return [];
  }

  // Save a new delivery address
  static Future<Map<String, dynamic>?> saveAddress({
    required String recipientName,
    required String street,
    required String city,
    required String zipCode,
    required String country,
    bool isDefault = false,
  }) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/api/addresses/'),
        headers: headers,
        body: jsonEncode({
          'recipient_name': recipientName,
          'street': street,
          'city': city,
          'zip_code': zipCode,
          'country': country,
          'is_default': isDefault,
        }),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error saving address: $e');
    }
    return null;
  }

  // Fetch all saved payment cards
  static Future<List<Map<String, dynamic>>> fetchPaymentCards() async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/api/payment-cards/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      print('Error fetching cards: $e');
    }
    return [];
  }

  // Save a new payment card (MOCK DATA ONLY)
  static Future<Map<String, dynamic>?> savePaymentCard({
    required String cardNumber,
    required String holderName,
    required String expiryDate,
    bool isDefault = false,
  }) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/api/payment-cards/'),
        headers: headers,
        body: jsonEncode({
          'card_number': cardNumber,
          'holder_name': holderName,
          'expiry_date': expiryDate,
          'is_default': isDefault,
        }),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error saving card: $e');
    }
    return null;
  }

  // Delete an address
  static Future<bool> deleteAddress(int addressId) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/addresses/$addressId/'),
        headers: headers,
      );
      return response.statusCode == 204;
    } catch (e) {
      print('Error deleting address: $e');
      return false;
    }
  }

  // Delete a card
  static Future<bool> deletePaymentCard(int cardId) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/payment-cards/$cardId/'),
        headers: headers,
      );
      return response.statusCode == 204;
    } catch (e) {
      print('Error deleting card: $e');
      return false;
    }
  }
}
