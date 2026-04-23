from rest_framework import generics, permissions, status
from rest_framework.response import Response

from ..models import Cart
from ..serializers import CartSerializer
from ..services.cart_service import CartBeforeLoginService

class GuestCartView(generics.ListCreateAPIView):
    """GET / POST /api/guest/cart/"""
    serializer_class   = CartSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        # Ensure session exists but don't force recreation
        if not self.request.session.session_key:
            self.request.session.create()
        return Cart.objects.filter(session_key=self.request.session.session_key)

    def create(self, request, *args, **kwargs):
        # Ensure session exists
        if not request.session.session_key:
            request.session.create()
        
        session_key = request.session.session_key
        product_id = request.data.get('product_id')
        quantity = int(request.data.get('quantity', 1))

        existing_item = CartBeforeLoginService.add_product_to_cart(
            customer=None, session_key=session_key, product_id=product_id, quantity=quantity
        )
        if existing_item:
            # Mark session as modified so it's saved
            request.session.modified = True
            serializer = self.get_serializer(existing_item)
            return Response(serializer.data, status=status.HTTP_200_OK)
        
        # Mark session as modified before creating new item
        request.session.modified = True
        return super().create(request, *args, **kwargs)

    def perform_create(self, serializer):
        if not self.request.session.session_key:
            self.request.session.create()
        serializer.save(customer=None, session_key=self.request.session.session_key)


class GuestCartItemView(generics.RetrieveUpdateDestroyAPIView):
    """GET / PATCH / DELETE /api/guest/cart/<id>/"""
    serializer_class   = CartSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        # Ensure session exists but don't force recreation
        if not self.request.session.session_key:
            self.request.session.create()
        return Cart.objects.filter(session_key=self.request.session.session_key)
