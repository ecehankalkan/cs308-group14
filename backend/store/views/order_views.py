from rest_framework import generics, permissions

from ..models import Order
from ..serializers import OrderSerializer


class OrderListView(generics.ListAPIView):
    """GET /api/orders/"""
    serializer_class   = OrderSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return (
            Order.objects
            .filter(customer=self.request.user)
            .prefetch_related('items__product')
            .order_by('-created_at')
        )
