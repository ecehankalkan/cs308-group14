from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from ..models import ProductReview
from ..serializers import ProductReviewSerializer


class PendingReviewsListView(generics.ListAPIView):
    """GET /api/manager/reviews/pending/ — Product Manager: list reviews awaiting approval"""
    serializer_class   = ProductReviewSerializer
    permission_classes = [permissions.AllowAny]  # match SalesOrderListView pattern; tighten later

    def get_queryset(self):
        return (
            ProductReview.objects
            .filter(status=ProductReview.Status.PENDING)
            .select_related('customer', 'product')
            .order_by('-created_at')
        )


class AllReviewsListView(generics.ListAPIView):
    """GET /api/manager/reviews/?status=pending|accepted|rejected — Product Manager: list all reviews"""
    serializer_class   = ProductReviewSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        qs = ProductReview.objects.select_related('customer', 'product').order_by('-created_at')
        status_filter = self.request.query_params.get('status')
        valid = {choice[0] for choice in ProductReview.Status.choices}
        if status_filter in valid:
            qs = qs.filter(status=status_filter)
        return qs


class ReviewModerationView(APIView):
    """POST /api/manager/reviews/<pk>/moderate/  — Product Manager approves or rejects a review
    Body: {"decision": "approve"} or {"decision": "reject"}
    """
    permission_classes = [permissions.AllowAny]

    def post(self, request, pk):
        try:
            review = ProductReview.objects.get(pk=pk)
        except ProductReview.DoesNotExist:
            return Response({'error': 'Review not found'}, status=status.HTTP_404_NOT_FOUND)

        decision = request.data.get('decision')
        if decision == 'approve':
            review.status = ProductReview.Status.ACCEPTED
        elif decision == 'reject':
            review.status = ProductReview.Status.REJECTED
        else:
            return Response(
                {'error': 'Invalid decision. Use "approve" or "reject".'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        review.save(update_fields=['status', 'updated_at'])
        return Response(ProductReviewSerializer(review).data)