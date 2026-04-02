from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from .models import Product, Cart, Wishlist, Order, Review, Refund, Delivery
from .serializers import (
    RegisterSerializer, CustomerSerializer, ProductSerializer,
    CartSerializer, WishlistSerializer, OrderSerializer,
    ReviewSerializer, RefundSerializer, DeliverySerializer,
)


class RegisterView(generics.CreateAPIView):
    """POST /api/register/"""
    serializer_class   = RegisterSerializer
    permission_classes = [permissions.AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        customer = serializer.save()
        refresh  = RefreshToken.for_user(customer)
        return Response({
            'user':    CustomerSerializer(customer).data,
            'access':  str(refresh.access_token),
            'refresh': str(refresh),
        }, status=status.HTTP_201_CREATED)


class MeView(APIView):
    """GET /api/me/"""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        return Response(CustomerSerializer(request.user).data)


class ProductListView(generics.ListAPIView):
    """GET /api/products/"""
    queryset           = Product.objects.all()
    serializer_class   = ProductSerializer
    permission_classes = [permissions.AllowAny]


class ProductDetailView(generics.RetrieveAPIView):
    """GET /api/products/<id>/"""
    queryset           = Product.objects.all()
    serializer_class   = ProductSerializer
    permission_classes = [permissions.AllowAny]


class CartView(generics.ListCreateAPIView):
    """GET / POST /api/cart/"""
    serializer_class   = CartSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Cart.objects.filter(customer=self.request.user)

    def perform_create(self, serializer):
        serializer.save(customer=self.request.user)


class CartItemView(generics.RetrieveUpdateDestroyAPIView):
    """GET / PATCH / DELETE /api/cart/<id>/"""
    serializer_class   = CartSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Cart.objects.filter(customer=self.request.user)


class WishlistView(generics.ListCreateAPIView):
    """GET / POST /api/wishlist/"""
    serializer_class   = WishlistSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Wishlist.objects.filter(customer=self.request.user)

    def perform_create(self, serializer):
        serializer.save(customer=self.request.user)


class WishlistItemView(generics.DestroyAPIView):
    """DELETE /api/wishlist/<id>/"""
    serializer_class   = WishlistSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Wishlist.objects.filter(customer=self.request.user)


class OrderListView(generics.ListCreateAPIView):
    """GET / POST /api/orders/"""
    serializer_class   = OrderSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Order.objects.filter(customer=self.request.user)

    def perform_create(self, serializer):
        serializer.save(customer=self.request.user)


class OrderDetailView(generics.RetrieveAPIView):
    """GET /api/orders/<id>/"""
    serializer_class   = OrderSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Order.objects.filter(customer=self.request.user)


class ReviewListView(generics.ListCreateAPIView):
    """GET / POST /api/reviews/"""
    serializer_class   = ReviewSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]

    def get_queryset(self):
        return Review.objects.filter(approved=True)

    def perform_create(self, serializer):
        serializer.save(customer=self.request.user)


class RefundView(generics.ListCreateAPIView):
    """GET / POST /api/refunds/"""
    serializer_class   = RefundSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Refund.objects.filter(customer=self.request.user)

    def perform_create(self, serializer):
        serializer.save(customer=self.request.user)


class DeliveryView(generics.ListAPIView):
    """GET /api/deliveries/"""
    serializer_class   = DeliverySerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Delivery.objects.filter(customer=self.request.user)
