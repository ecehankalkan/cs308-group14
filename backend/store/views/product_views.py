from django.db.models import Q
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from ..models import Customer, Product
from ..serializers import ProductSerializer


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

        return Response(ProductSerializer(product).data)
