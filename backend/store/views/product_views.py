from django.db.models import Q
from rest_framework import generics, permissions, status, serializers
from rest_framework.response import Response
from rest_framework.views import APIView

from ..models import Customer, Product, ProductReview, OrderItem, Order, Category
from ..serializers import ProductSerializer, ProductReviewSerializer, CategorySerializer

class CategoryListCreateView(generics.ListCreateAPIView):
    serializer_class = CategorySerializer

    def get_permissions(self):
        if self.request.method == 'POST':
            return [IsProductManager()]
        return [permissions.AllowAny()]

    def get_queryset(self):
        if not (self.request.user.is_authenticated and self.request.user.role == Customer.Role.PRODUCT_MANAGER):
            return Category.objects.filter(is_active=True)
        return Category.objects.all()

class CategoryDetailView(generics.RetrieveUpdateAPIView):
    queryset = Category.objects.all()
    serializer_class = CategorySerializer
    
    def get_permissions(self):
        if self.request.method in ['PUT', 'PATCH']:
            return [IsProductManager()]
        return [permissions.AllowAny()]


class IsSalesManager(permissions.BasePermission):
    def has_permission(self, request, view):
        return (request.user.is_authenticated and
                request.user.role == Customer.Role.SALES_MANAGER)


class IsProductManager(permissions.BasePermission):
    def has_permission(self, request, view):
        return (request.user.is_authenticated and
                request.user.role == Customer.Role.PRODUCT_MANAGER)


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
        qs       = Product.objects.prefetch_related('reviews').all()
        search   = self.request.query_params.get('search')
        category = self.request.query_params.get('category')
        sort     = self.request.query_params.get('sort')

        manager_roles = {Customer.Role.PRODUCT_MANAGER, Customer.Role.SALES_MANAGER}
        if not (self.request.user.is_authenticated and self.request.user.role in manager_roles):
            qs = qs.filter(is_active=True)

        if search:
            qs = qs.filter(Q(name__icontains=search) | Q(description__icontains=search))
        if category:
            qs = qs.filter(category__name__icontains=category)
        if sort == 'price':
            qs = qs.order_by('price')
        elif sort == 'popularity':
            qs = qs.order_by('-popularity_score')

        return qs


class ProductDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    GET          /api/products/<id>/ — public
    PUT/PATCH    /api/products/<id>/ — PRODUCT_MANAGER only
    DELETE       /api/products/<id>/ — PRODUCT_MANAGER only
    """
    queryset         = Product.objects.all()
    serializer_class = ProductSerializer

    def get_permissions(self):
        if self.request.method in ['PUT', 'PATCH', 'DELETE']:
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
        delta = request.data.get('stock_delta')

        if quantity is not None and delta is not None:
            return Response({'error': 'Provide either stock_quantity or stock_delta'}, status=status.HTTP_400_BAD_REQUEST)
        if quantity is None and delta is None:
            return Response({'error': 'stock_quantity or stock_delta required'}, status=status.HTTP_400_BAD_REQUEST)

        if quantity is not None:
            try:
                quantity = int(quantity)
            except (TypeError, ValueError):
                return Response({'error': 'Invalid stock_quantity'}, status=status.HTTP_400_BAD_REQUEST)
            if quantity < 0:
                return Response({'error': 'stock_quantity must be >= 0'}, status=status.HTTP_400_BAD_REQUEST)
            product.stock_quantity = quantity
        else:
            try:
                delta = int(delta)
            except (TypeError, ValueError):
                return Response({'error': 'Invalid stock_delta'}, status=status.HTTP_400_BAD_REQUEST)
            new_quantity = product.stock_quantity + delta
            if new_quantity < 0:
                return Response({'error': 'stock_quantity cannot be negative'}, status=status.HTTP_400_BAD_REQUEST)
            product.stock_quantity = new_quantity

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

        from decimal import Decimal, InvalidOperation
        try:
            discounted_price = Decimal(str(discounted_price))
        except (TypeError, ValueError, InvalidOperation):
            return Response({'error': 'Invalid discounted_price'}, status=status.HTTP_400_BAD_REQUEST)

        product.discounted_price = discounted_price
        product.save(update_fields=['discounted_price'])

        if product.discounted_price is not None and product.discounted_price < product.price:
            from store.views.wishlist_view import notify_wishlist_users
            notify_wishlist_users(product)

        return Response(ProductSerializer(product).data)


class ProductPriceView(APIView):
    """PATCH /api/products/<id>/price/ — sales manager dashboard"""
    permission_classes = [IsSalesManager]

    def patch(self, request, pk):
        try:
            product = Product.objects.get(pk=pk)
        except Product.DoesNotExist:
            return Response({'error': 'Product not found'}, status=status.HTTP_404_NOT_FOUND)

        new_price = request.data.get('price')
        discount_pct = request.data.get('discount_percentage')

        if new_price is not None:
            from decimal import Decimal, InvalidOperation
            try:
                product.price = Decimal(str(new_price))
            except (TypeError, ValueError, InvalidOperation):
                return Response({'error': 'Invalid price'}, status=status.HTTP_400_BAD_REQUEST)

        if discount_pct is not None:
            try:
                pct = float(discount_pct)
                if not (0 <= pct <= 100):
                    return Response({'error': 'discount_percentage must be 0–100'}, status=status.HTTP_400_BAD_REQUEST)
                if pct > 0:
                    from decimal import Decimal
                    product.discounted_price = Decimal(str(round(float(product.price) * (1 - pct / 100), 2)))
                else:
                    product.discounted_price = None
            except (TypeError, ValueError):
                return Response({'error': 'Invalid discount_percentage'}, status=status.HTTP_400_BAD_REQUEST)

        from decimal import Decimal
        if product.is_active and product.price <= Decimal('0'):
            return Response(
                {'error': 'Cannot set price to 0 while product is active. Deactivate the product first.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        product.save()

        if product.discounted_price is not None and product.discounted_price < product.price:
            from store.views.wishlist_view import notify_wishlist_users
            notify_wishlist_users(product)

        return Response(ProductSerializer(product).data)


class ProductReviewListCreateView(generics.ListCreateAPIView):
    """
    GET  /api/products/<product_id>/reviews/ — public (only ACCEPTED reviews)
    POST /api/products/<product_id>/reviews/ — authenticated users (must have purchased + delivered)
    """
    serializer_class = ProductReviewSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        product_id = self.kwargs.get('product_id')
        # Only show accepted reviews to public
        return ProductReview.objects.filter(
            product_id=product_id, 
            status=ProductReview.Status.ACCEPTED
        ).order_by('-created_at')

    def perform_create(self, serializer):
        product_id = self.kwargs.get('product_id')
        product = Product.objects.get(pk=product_id)

        order_item = OrderItem.objects.filter(
            order__customer=self.request.user,
            order__status=Order.Status.DELIVERED,
            product_id=product_id
        ).first()

        if not order_item:
            raise serializers.ValidationError(
                "You can only review products you have purchased and received."
            )

        existing = ProductReview.objects.filter(
            product=product,
            customer=self.request.user,
        ).first()

        if existing:
            if existing.status != ProductReview.Status.REJECTED:
                raise serializers.ValidationError(
                    "You have already submitted a review for this product."
                )
            # Reopen the rejected review as a fresh pending submission
            existing.rating = serializer.validated_data.get('rating')
            existing.comment = serializer.validated_data.get('comment', '')
            existing.order_item = order_item
            existing.status = ProductReview.Status.PENDING
            existing.save()
            serializer.instance = existing
        else:
            serializer.save(
                product=product,
                customer=self.request.user,
                order_item=order_item
            )

    def get_permissions(self):
        if self.request.method == 'POST':
            return [permissions.IsAuthenticated()]
        return [permissions.AllowAny()]


class MyProductReviewView(APIView):
    """GET /api/products/<product_id>/my-review/ — returns the logged-in user's own review (any status)"""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, product_id):
        try:
            review = ProductReview.objects.get(product_id=product_id, customer=request.user)
            return Response(ProductReviewSerializer(review).data)
        except ProductReview.DoesNotExist:
            return Response(None, status=status.HTTP_204_NO_CONTENT)


class ProductReviewDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    GET    /api/reviews/<id>/ — public
    PUT    /api/reviews/<id>/ — review owner only
    DELETE /api/reviews/<id>/ — review owner only
    """
    queryset = ProductReview.objects.all()
    serializer_class = ProductReviewSerializer

    def get_permissions(self):
        if self.request.method == 'GET':
            return [permissions.AllowAny()]
        return [permissions.IsAuthenticated()]

    def perform_update(self, serializer):
        if self.get_object().customer != self.request.user:
            raise permissions.PermissionDenied("You can only edit your own reviews.")
        serializer.save()

    def perform_destroy(self, instance):
        if instance.customer != self.request.user:
            raise permissions.PermissionDenied("You can only delete your own reviews.")
        instance.delete()
