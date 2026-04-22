from rest_framework import serializers
from .models import Customer, Product, Cart, Order, OrderItem, DeliveryAddress, PaymentCard


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


class ProfileUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model  = Customer
        fields = ['home_address']


class ProductSerializer(serializers.ModelSerializer):
    in_stock = serializers.SerializerMethodField()

    class Meta:
        model  = Product
        fields = ['id', 'name', 'model', 'serial_number', 'description',
                  'stock_quantity', 'price', 'discounted_price', 'in_stock',
                  'warranty_status', 'distributor_info', 'category', 'popularity_score']

    def get_in_stock(self, obj):
        return obj.stock_quantity > 0


class OrderItemSerializer(serializers.ModelSerializer):
    product_id   = serializers.IntegerField(source='product.id', read_only=True)
    product_name = serializers.CharField(source='product.name', read_only=True)
    unit_price   = serializers.DecimalField(source='price_at_purchase', max_digits=10, decimal_places=2, read_only=True)

    class Meta:
        model  = OrderItem
        fields = ['product_id', 'product_name', 'quantity', 'unit_price']


class OrderSerializer(serializers.ModelSerializer):
    items        = OrderItemSerializer(many=True, read_only=True)
    total_amount = serializers.DecimalField(source='total_price', max_digits=12, decimal_places=2, read_only=True)

    class Meta:
        model  = Order
        fields = ['id', 'created_at', 'total_amount', 'delivery_address', 'status', 'items']


class CartSerializer(serializers.ModelSerializer):
    product    = ProductSerializer(read_only=True)
    product_id = serializers.PrimaryKeyRelatedField(
        queryset=Product.objects.all(), source='product', write_only=True
    )

    class Meta:
        model  = Cart
        fields = ['id', 'product', 'product_id', 'quantity']


class DeliveryAddressSerializer(serializers.ModelSerializer):
    class Meta:
        model = DeliveryAddress
        fields = ['id', 'recipient_name', 'street', 'city', 'zip_code', 'country', 'is_default', 'created_at']
        read_only_fields = ['id', 'created_at']


class PaymentCardSerializer(serializers.ModelSerializer):
    class Meta:
        model = PaymentCard
        fields = ['id', 'card_number', 'holder_name', 'expiry_date', 'is_default', 'created_at']
        read_only_fields = ['id', 'created_at']