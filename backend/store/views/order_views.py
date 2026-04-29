from rest_framework import generics, permissions

from ..models import Order
from ..serializers import OrderSerializer, SalesOrderSerializer


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


class SalesOrderListView(generics.ListAPIView):
    """GET /api/sales/orders/ — all orders for the sales manager dashboard"""
    serializer_class   = SalesOrderSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        return (
            Order.objects
            .select_related('customer')
            .prefetch_related('items__product')
            .order_by('-created_at')
        )
