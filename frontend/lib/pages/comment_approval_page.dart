import 'package:flutter/material.dart';
import '../services/review_admin_service.dart';

class CommentApprovalPage extends StatefulWidget {
  const CommentApprovalPage({super.key});

  @override
  State<CommentApprovalPage> createState() => _CommentApprovalPageState();
}

class _CommentApprovalPageState extends State<CommentApprovalPage> {
  final ReviewAdminService _service = ReviewAdminService();
  List<PendingReview> _reviews = [];
  bool _loading = true;
  String _filter = 'pending'; // 'pending' | 'accepted' | 'rejected' | 'all'

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _service.fetchReviews(statusFilter: _filter);
    if (!mounted) return;
    setState(() {
      _reviews = list;
      _loading = false;
    });
  }

  Future<void> _moderate(PendingReview review, String decision) async {
    final ok = await _service.moderate(review.id, decision);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? (decision == 'approve' ? 'Comment approved.' : 'Comment rejected.')
          : 'Action failed. Please try again.'),
      backgroundColor: ok ? Colors.green : Colors.red,
    ));
    if (ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comment Approval'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Customer Comments',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'pending',  label: Text('Pending')),
                    ButtonSegment(value: 'accepted', label: Text('Approved')),
                    ButtonSegment(value: 'rejected', label: Text('Rejected')),
                    ButtonSegment(value: 'all',      label: Text('All')),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (s) {
                    setState(() => _filter = s.first);
                    _load();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _reviews.isEmpty
                      ? Center(
                          child: Text(
                            _filter == 'pending'
                                ? 'No pending comments. 🎉'
                                : 'No comments to show.',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            itemCount: _reviews.length,
                            itemBuilder: (_, i) => _ReviewCard(
                              review: _reviews[i],
                              onApprove: () => _moderate(_reviews[i], 'approve'),
                              onReject:  () => _moderate(_reviews[i], 'reject'),
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

class _ReviewCard extends StatelessWidget {
  final PendingReview review;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ReviewCard({
    required this.review,
    required this.onApprove,
    required this.onReject,
  });

  Color _statusColor() {
    switch (review.status) {
      case 'accepted': return Colors.green.shade700;
      case 'rejected': return Colors.red.shade700;
      default:         return Colors.orange.shade700;
    }
  }

  String _statusLabel() {
    switch (review.status) {
      case 'accepted': return 'Approved';
      case 'rejected': return 'Rejected';
      default:         return 'Pending';
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final isPending = review.status == 'pending';
    final color = _statusColor();
    final hasComment = (review.comment ?? '').trim().isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.customerName.isNotEmpty ? review.customerName : 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        review.customerEmail,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (review.rating != null) ...[
                  Row(
                    children: List.generate(5, (i) {
                      return Icon(
                        i < review.rating! ? Icons.star : Icons.star_border,
                        size: 18,
                        color: Colors.amber.shade700,
                      );
                    }),
                  ),
                  const SizedBox(width: 12),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _statusLabel(),
                    style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Product #${review.productId}  ·  ${_fmtDate(review.createdAt)}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            if (hasComment) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(review.comment!, style: const TextStyle(fontSize: 14, height: 1.4)),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                '(rating only, no written comment)',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
            if (isPending) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: onReject,
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: onApprove,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}