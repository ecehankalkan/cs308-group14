from django.db import transaction
from django.db.models import Q, Sum
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenObtainPairView

from .models import Customer, Product, Cart, Wishlist, Order, OrderItem, Review, Refund, Delivery
from .serializers import (
    RegisterSerializer, CustomerSerializer, ProductSerializer,
    CartSerializer, WishlistSerializer, OrderSerializer, OrderCreateSerializer,
    ReviewSerializer, RefundSerializer, DeliverySerializer,
)
from .cart_beforelogin_service import CartBeforeLoginService


# ---------------------------------------------------------------------------
# Custom permissions
# ---------------------------------------------------------------------------

class IsSalesManager(permissions.BasePermission):
    def has_permission(self, request, view):
        return (request.user.is_authenticated and
                request.user.role == Customer.Role.SALES_MANAGER)


class IsProductManager(permissions.BasePermission):
    def has_permission(self, request, view):
        return (request.user.is_authenticated and
                request.user.role == Customer.Role.PRODUCT_MANAGER)


# ---------------------------------------------------------------------------
# Auth
# ---------------------------------------------------------------------------

class RegisterView(generics.CreateAPIView):
    """POST /api/register/"""
    serializer_class   = RegisterSerializer
    permission_classes = [permissions.AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        customer = serializer.save()

        session_key = request.session.session_key
        CartBeforeLoginService.merge_guest_cart(session_key, customer)

        refresh  = RefreshToken.for_user(customer)
        return Response({
            'user':    CustomerSerializer(customer).data,
            'access':  str(refresh.access_token),
            'refresh': str(refresh),
        }, status=status.HTTP_201_CREATED)


class CustomTokenObtainPairView(TokenObtainPairView):
    """Custom login view to merge the cart after obtaining tokens."""
    def post(self, request, *args, **kwargs):
        response = super().post(request, *args, **kwargs)
        if response.status_code == status.HTTP_200_OK:
            serializer = self.get_serializer(data=request.data)
            if serializer.is_valid():
                session_key = request.session.session_key
                CartBeforeLoginService.merge_guest_cart(session_key, serializer.user)
        return response


class MeView(APIView):
    """GET /api/me/"""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        return Response(CustomerSerializer(request.user).data)


# ---------------------------------------------------------------------------
# Products
# ---------------------------------------------------------------------------

class ProductListView(generics.ListCreateAPIView):
    """
    GET  /api/products/ — public, supports ?search= ?category= ?sort=price|popularity
    POST /api/products/ — PRODUCT_MANAGER only
    """
    serializer_class = ProductSerializer

    def get_permissions(self):
        if self.request.method == 'POST':
            return [IsProductManager()]
        return [permissions.AllowAny()]

    def get_queryset(self):
        qs       = Product.objects.all()
        search   = self.request.query_params.get('search')
        category = self.request.query_params.get('category')
        sort     = self.request.query_params.get('sort')

        if search:
            qs = qs.filter(Q(name__icontains=search) | Q(description__icontains=search))
        if category:
            qs = qs.filter(category__name__icontains=category)
        if sort == 'price':
            qs = qs.order_by('price')
        elif sort == 'popularity':
            qs = qs.order_by('-popularity_score')

        return qs


class ProductDetailView(generics.RetrieveDestroyAPIView):
    """
    GET    /api/products/<id>/ — public
    DELETE /api/products/<id>/ — PRODUCT_MANAGER only
    """
    queryset         = Product.objects.all()
    serializer_class = ProductSerializer

    def get_permissions(self):
        if self.request.method == 'DELETE':
            return [IsProductManager()]
        return [permissions.AllowAny()]


class ProductStockView(APIView):
    """PATCH /api/products/<id>/stock/ — PRODUCT_MANAGER only"""
    permission_classes = [IsProductManager]

    def patch(self, request, pk):
        try:
            product = Product.objects.get(pk=pk)
        except Product.DoesNotExist:
            return Response({'error': 'Product not found'}, status=status.HTTP_404_NOT_FOUND)

        quantity = request.data.get('stock_quantity')
        if quantity is None:
            return Response({'error': 'stock_quantity required'}, status=status.HTTP_400_BAD_REQUEST)

        product.stock_quantity = quantity
        product.save(update_fields=['stock_quantity'])
        return Response(ProductSerializer(product).data)


class ProductDiscountView(APIView):
    """POST /api/products/<id>/discount/ — SALES_MANAGER only"""
    permission_classes = [IsSalesManager]

    def post(self, request, pk):
        try:
            product = Product.objects.get(pk=pk)
        except Product.DoesNotExist:
            return Response({'error': 'Product not found'}, status=status.HTTP_404_NOT_FOUND)

        discounted_price = request.data.get('discounted_price')
        if discounted_price is None:
            return Response({'error': 'discounted_price required'}, status=status.HTTP_400_BAD_REQUEST)

        product.discounted_price = discounted_price
        product.save(update_fields=['discounted_price'])

        notified_count = Wishlist.objects.filter(product=product).count()

        return Response({
            **ProductSerializer(product).data,
            'notified_customers': notified_count,
        })


# ---------------------------------------------------------------------------
# Cart
# ---------------------------------------------------------------------------

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


# ---------------------------------------------------------------------------
# Wishlist
# ---------------------------------------------------------------------------

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


# ---------------------------------------------------------------------------
# Orders
# ---------------------------------------------------------------------------

class OrderListView(generics.ListAPIView):
    """
    GET  /api/orders/ — customer's own orders
    POST /api/orders/ — create order with items, auto-calculates total, reduces stock
    """
    serializer_class   = OrderSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Order.objects.filter(customer=self.request.user)

    def post(self, request, *args, **kwargs):
        create_serializer = OrderCreateSerializer(data=request.data)
        create_serializer.is_valid(raise_exception=True)

        data       = create_serializer.validated_data
        items_data = data['items']

        # Validate products and stock before touching the DB
        resolved = []
        for item in items_data:
            try:
                product = Product.objects.get(pk=item['product_id'])
            except Product.DoesNotExist:
                return Response(
                    {'error': f"Product {item['product_id']} not found"},
                    status=status.HTTP_404_NOT_FOUND,
                )
            if product.stock_quantity < item['quantity']:
                return Response(
                    {'error': f"Insufficient stock for '{product.name}'"},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            resolved.append((product, item['quantity']))

        total_price = sum(p.effective_price() * qty for p, qty in resolved)

        with transaction.atomic():
            order = Order.objects.create(
                customer=request.user,
                delivery_address=data['delivery_address'],
                total_price=total_price,
            )
            for product, quantity in resolved:
                OrderItem.objects.create(
                    order=order,
                    product=product,
                    quantity=quantity,
                    price_at_purchase=product.effective_price(),
                )
                Product.objects.filter(pk=product.pk).update(
                    stock_quantity=product.stock_quantity - quantity
                )

        return Response(OrderSerializer(order).data, status=status.HTTP_201_CREATED)


class OrderDetailView(generics.RetrieveAPIView):
    """GET /api/orders/<id>/"""
    serializer_class   = OrderSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Order.objects.filter(customer=self.request.user)


# ---------------------------------------------------------------------------
# Reviews
# ---------------------------------------------------------------------------

class ReviewListView(generics.ListCreateAPIView):
    """GET / POST /api/reviews/"""
    serializer_class   = ReviewSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]

    def get_queryset(self):
        return Review.objects.filter(approved=True)

    def perform_create(self, serializer):
        serializer.save(customer=self.request.user)


class ReviewApproveView(APIView):
    """PATCH /api/reviews/<id>/approve/ — PRODUCT_MANAGER only"""
    permission_classes = [IsProductManager]

    def patch(self, request, pk):
        try:
            review = Review.objects.get(pk=pk)
        except Review.DoesNotExist:
            return Response({'error': 'Review not found'}, status=status.HTTP_404_NOT_FOUND)
        review.approved = True
        review.save(update_fields=['approved'])
        return Response(ReviewSerializer(review).data)


class ReviewDisapproveView(APIView):
    """PATCH /api/reviews/<id>/disapprove/ — PRODUCT_MANAGER only"""
    permission_classes = [IsProductManager]

    def patch(self, request, pk):
        try:
            review = Review.objects.get(pk=pk)
        except Review.DoesNotExist:
            return Response({'error': 'Review not found'}, status=status.HTTP_404_NOT_FOUND)
        review.approved = False
        review.save(update_fields=['approved'])
        return Response(ReviewSerializer(review).data)


# ---------------------------------------------------------------------------
# Refunds
# ---------------------------------------------------------------------------

class RefundView(generics.ListCreateAPIView):
    """GET / POST /api/refunds/"""
    serializer_class   = RefundSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Refund.objects.filter(customer=self.request.user)

    def perform_create(self, serializer):
        serializer.save(customer=self.request.user)


# ---------------------------------------------------------------------------
# Deliveries
# ---------------------------------------------------------------------------

class DeliveryView(generics.ListAPIView):
    """
    GET /api/deliveries/
    PRODUCT_MANAGER sees all deliveries; customers see only their own.
    """
    serializer_class   = DeliverySerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        if self.request.user.role == Customer.Role.PRODUCT_MANAGER:
            return Delivery.objects.all()
        return Delivery.objects.filter(customer=self.request.user)


class DeliveryCompleteView(APIView):
    """PATCH /api/deliveries/<id>/complete/ — PRODUCT_MANAGER only"""
    permission_classes = [IsProductManager]

    def patch(self, request, pk):
        try:
            delivery = Delivery.objects.get(pk=pk)
        except Delivery.DoesNotExist:
            return Response({'error': 'Delivery not found'}, status=status.HTTP_404_NOT_FOUND)
        delivery.is_completed = True
        delivery.save(update_fields=['is_completed'])
        return Response(DeliverySerializer(delivery).data)


# ---------------------------------------------------------------------------
# Sales Manager — Invoices & Revenue
# ---------------------------------------------------------------------------

class InvoiceView(generics.ListAPIView):
    """GET /api/invoices/?from=YYYY-MM-DD&to=YYYY-MM-DD — SALES_MANAGER only"""
    serializer_class   = OrderSerializer
    permission_classes = [IsSalesManager]

    def get_queryset(self):
        qs        = Order.objects.all()
        from_date = self.request.query_params.get('from')
        to_date   = self.request.query_params.get('to')
        if from_date:
            qs = qs.filter(created_at__date__gte=from_date)
        if to_date:
            qs = qs.filter(created_at__date__lte=to_date)
        return qs


class RevenueView(APIView):
    """GET /api/revenue/?from=YYYY-MM-DD&to=YYYY-MM-DD — SALES_MANAGER only"""
    permission_classes = [IsSalesManager]

    def get(self, request):
        qs        = Order.objects.all()
        from_date = request.query_params.get('from')
        to_date   = request.query_params.get('to')
        if from_date:
            qs = qs.filter(created_at__date__gte=from_date)
        if to_date:
            qs = qs.filter(created_at__date__lte=to_date)

        revenue = qs.aggregate(total=Sum('total_price'))['total'] or 0
        return Response({
            'revenue':     revenue,
            'order_count': qs.count(),
            'from':        from_date,
            'to':          to_date,
        })

# ---------------------------------------------------------------------------
# Mock PDF Invoice Endpoint (SCRUM 54-56)
# ---------------------------------------------------------------------------

from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from .invoice_service import process_mock_order_and_invoice

@api_view(['GET', 'POST'])
@permission_classes([AllowAny])
def test_invoice_email(request):
    """GET / POST /api/test-invoice/ — Triggers the SCRUM-54/55/56 mock logic"""
    email = request.GET.get('email', 'student@university.edu')
    if request.method == 'POST':
        email = request.data.get('email', email)
    result = process_mock_order_and_invoice(customer_email=email)
    return Response(result)