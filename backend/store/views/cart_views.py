from rest_framework import generics, permissions, status
from rest_framework.response import Response

from ..models import Cart
from ..serializers import CartSerializer
from ..services.cart_service import CartBeforeLoginService


class CartView(generics.ListCreateAPIView):
    """GET / POST /api/cart/"""
    serializer_class   = CartSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Cart.objects.filter(customer=self.request.user)

    def create(self, request, *args, **kwargs):
        product_id = request.data.get('product_id')
        quantity = int(request.data.get('quantity', 1))
        existing_item = CartBeforeLoginService.add_product_to_cart(
            customer=request.user, session_key=None, product_id=product_id, quantity=quantity
        )
        if existing_item:
            serializer = self.get_serializer(existing_item)
            return Response(serializer.data, status=status.HTTP_200_OK)
        return super().create(request, *args, **kwargs)

    def perform_create(self, serializer):
        serializer.save(customer=self.request.user)


class CartItemView(generics.RetrieveUpdateDestroyAPIView):
    """GET / PATCH / DELETE /api/cart/<id>/"""
    serializer_class   = CartSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Cart.objects.filter(customer=self.request.user)
