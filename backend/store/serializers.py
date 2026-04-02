from rest_framework import serializers
from .models import Customer, Product, Cart, Wishlist, Order, OrderItem, Review, Refund, Delivery


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)

    class Meta:
        model  = Customer
        fields = ['id', 'email', 'name', 'tax_id', 'home_address', 'password']

    def create(self, validated_data):
        return Customer.objects.create_user(**validated_data)


class CustomerSerializer(serializers.ModelSerializer):
    class Meta:
        model  = Customer
        fields = ['id', 'email', 'name', 'tax_id', 'home_address', 'role', 'created_at']


class ProductSerializer(serializers.ModelSerializer):
    class Meta:
        model  = Product
        fields = ['id', 'name', 'model', 'serial_number', 'description',
                  'stock_quantity', 'price', 'discounted_price',
                  'warranty_status', 'distributor_info', 'category', 'popularity_score']


class CartSerializer(serializers.ModelSerializer):
    product    = ProductSerializer(read_only=True)
    product_id = serializers.PrimaryKeyRelatedField(
        queryset=Product.objects.all(), source='product', write_only=True
    )

    class Meta:
        model  = Cart
        fields = ['id', 'product', 'product_id', 'quantity']


class WishlistSerializer(serializers.ModelSerializer):
    product = ProductSerializer(read_only=True)
    product_id = serializers.PrimaryKeyRelatedField(
        queryset=Product.objects.all(), source='product', write_only=True
    )

    class Meta:
        model  = Wishlist
        fields = ['id', 'product', 'product_id']


class OrderItemSerializer(serializers.ModelSerializer):
    product = ProductSerializer(read_only=True)

    class Meta:
        model  = OrderItem
        fields = ['id', 'product', 'quantity', 'price_at_purchase']


class OrderSerializer(serializers.ModelSerializer):
    items = OrderItemSerializer(many=True, read_only=True)

    class Meta:
        model  = Order
        fields = ['id', 'total_price', 'status', 'delivery_address', 'created_at', 'items']


class ReviewSerializer(serializers.ModelSerializer):
    class Meta:
        model  = Review
        fields = ['id', 'product', 'rating', 'comment', 'approved', 'created_at']
        read_only_fields = ['approved']


class RefundSerializer(serializers.ModelSerializer):
    class Meta:
        model  = Refund
        fields = ['id', 'order_item', 'status', 'refund_amount', 'created_at']
        read_only_fields = ['status']


class DeliverySerializer(serializers.ModelSerializer):
    class Meta:
        model  = Delivery
        fields = ['id', 'order', 'product', 'quantity', 'total_price',
                  'delivery_address', 'is_completed']
