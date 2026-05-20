import 'dart:convert';
import 'package:http/http.dart' as http;

class PendingReview {
  final int id;
  final int productId;
  final int customerId;
  final String customerName;
  final String customerEmail;
  final int? rating;
  final String? comment;
  final String status; // 'pending' | 'accepted' | 'rejected'
  final DateTime createdAt;

  PendingReview({
    required this.id,
    required this.productId,
    required this.customerId,
    required this.customerName,
    required this.customerEmail,
    required this.rating,
    required this.comment,
    required this.status,
    required this.createdAt,
  });

  factory PendingReview.fromJson(Map<String, dynamic> j) => PendingReview(
        id:            j['id'] as int,
        productId:     j['product'] as int,
        customerId:    j['customer'] as int,
        customerName:  (j['customer_name'] ?? '') as String,
        customerEmail: (j['customer_email'] ?? '') as String,
        rating:        j['rating'] as int?,
        comment:       j['comment'] as String?,
        status:        (j['status'] ?? 'pending') as String,
        createdAt:     DateTime.tryParse((j['created_at'] ?? '') as String) ?? DateTime.now(),
      );
}

class ReviewAdminService {
  static const String _baseUrl = 'http://127.0.0.1:8000';

  /// Fetches reviews. Pass [statusFilter] = null for pending only,
  /// or one of 'pending' | 'accepted' | 'rejected' | 'all'.
  Future<List<PendingReview>> fetchReviews({String? statusFilter}) async {
    try {
      final Uri uri;
      if (statusFilter == null || statusFilter == 'pending') {
        uri = Uri.parse('$_baseUrl/api/manager/reviews/pending/');
      } else if (statusFilter == 'all') {
        uri = Uri.parse('$_baseUrl/api/manager/reviews/');
      } else {
        uri = Uri.parse('$_baseUrl/api/manager/reviews/?status=$statusFilter');
      }
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        return data
            .map((e) => PendingReview.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// [decision] must be 'approve' or 'reject'.
  Future<bool> moderate(int reviewId, String decision) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/manager/reviews/$reviewId/moderate/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'decision': decision}),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}