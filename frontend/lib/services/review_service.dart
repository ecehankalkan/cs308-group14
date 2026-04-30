import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/review.dart';

class ReviewService {
  final String baseUrl = 'http://localhost:8000/api';
  final http.Client _httpClient = http.Client();

  Future<List<ProductReview>> fetchProductReviews(int productId) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/products/$productId/reviews/'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);
        return jsonData.map((json) => ProductReview.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load reviews');
      }
    } catch (e) {
      throw Exception('Error fetching reviews: $e');
    }
  }

  Future<ProductReview> createReview({
    required int productId,
    int? rating,
    String? comment,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // At least one of rating or comment must be provided
      if ((rating == null || rating == 0) && (comment == null || comment.isEmpty)) {
        throw Exception('Please provide either a rating or a comment');
      }

      final idToken = await user.getIdToken();

      final requestBody = {
        'product': productId,
        'rating': rating != null && rating > 0 ? rating : null,
        'comment': comment != null && comment.isNotEmpty ? comment : null,
      };

      final response = await _httpClient.post(
        Uri.parse('$baseUrl/products/$productId/reviews/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 201) {
        return ProductReview.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 400) {
        throw Exception('Bad request: ${response.body}');
      } else {
        throw Exception('Failed to create review');
      }
    } catch (e) {
      throw Exception('Error creating review: $e');
    }
  }

  Future<ProductReview> updateReview({
    required int reviewId,
    int? rating,
    String? comment,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      if ((rating == null || rating == 0) && (comment == null || comment.isEmpty)) {
        throw Exception('Please provide either a rating or a comment');
      }

      final idToken = await user.getIdToken();

      final requestBody = {
        'rating': rating != null && rating > 0 ? rating : null,
        'comment': comment != null && comment.isNotEmpty ? comment : null,
      };

      final response = await _httpClient.put(
        Uri.parse('$baseUrl/reviews/$reviewId/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        return ProductReview.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to update review');
      }
    } catch (e) {
      throw Exception('Error updating review: $e');
    }
  }

  Future<void> deleteReview(int reviewId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final idToken = await user.getIdToken();

      final response = await _httpClient.delete(
        Uri.parse('$baseUrl/reviews/$reviewId/'),
        headers: {
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode != 204) {
        throw Exception('Failed to delete review');
      }
    } catch (e) {
      throw Exception('Error deleting review: $e');
    }
  }
}
