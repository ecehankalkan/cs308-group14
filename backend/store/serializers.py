from rest_framework import serializers
from .models import Customer, Product, Cart


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
    in_stock = serializers.SerializerMethodField()

    class Meta:
        model  = Product
        fields = ['id', 'name', 'model', 'serial_number', 'description',
                  'stock_quantity', 'price', 'discounted_price', 'in_stock',
                  'warranty_status', 'distributor_info', 'category', 'popularity_score']

    def get_in_stock(self, obj):
        return obj.stock_quantity > 0


class CartSerializer(serializers.ModelSerializer):
    product    = ProductSerializer(read_only=True)
    product_id = serializers.PrimaryKeyRelatedField(
        queryset=Product.objects.all(), source='product', write_only=True
    )

    class Meta:
        model  = Cart
        fields = ['id', 'product', 'product_id', 'quantity']