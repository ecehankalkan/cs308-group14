from rest_framework import serializers
from .models import Customer, Product, Cart, Order, OrderItem, DeliveryAddress, PaymentCard, ProductReview, Wishlist, Category

class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = ['id', 'name', 'description', 'is_active']
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
    in_stock      = serializers.SerializerMethodField()
    average_rating = serializers.SerializerMethodField()
    rating_count   = serializers.SerializerMethodField()
    serial_number  = serializers.CharField(read_only=True)
    price          = serializers.DecimalField(max_digits=10, decimal_places=2, required=False)
    discounted_price = serializers.DecimalField(max_digits=10, decimal_places=2, required=False, allow_null=True)

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        request = self.context.get('request')
        if request and request.user and request.user.is_authenticated:
            if getattr(request.user, 'role', None) == 'product_manager':
                self.fields.pop('price', None)
                self.fields.pop('discounted_price', None)

    class Meta:
        model  = Product
        fields = ['id', 'name', 'model', 'serial_number', 'description',
                  'stock_quantity', 'price', 'discounted_price', 'in_stock',
                  'warranty_status', 'distributor_info', 'category', 'popularity_score',
                  'average_rating', 'rating_count', 'is_active', 'image_url']

    def validate(self, attrs):
        request = self.context.get('request')
        is_pm = request and request.user.is_authenticated and request.user.role == Customer.Role.PRODUCT_MANAGER
        
        if is_pm:
            # Prevent Product Manager from modifying price
            attrs.pop('price', None)
            attrs.pop('discounted_price', None)
            
            # If creating a new product, we must provide a default price since the DB requires it
            if not self.instance:
                attrs['price'] = 0.0
                attrs['is_active'] = False # Default to inactive when price is 0.0

        # Determine the effective price to enforce visibility rules
        current_price = attrs.get('price')
        if current_price is None and self.instance:
            current_price = self.instance.price
        
        # If price is 0, product cannot be active
        is_active = attrs.get('is_active')
        if is_active and current_price is not None and float(current_price) <= 0.0:
            raise serializers.ValidationError("Cannot enable product visibility until a price has been set by the Sales team.")

        return attrs

    def get_in_stock(self, obj):
        return obj.stock_quantity > 0

    def get_average_rating(self, obj):
        # Use prefetched reviews if available (O(1) memory check instead of DB query)
        if hasattr(obj, '_prefetched_objects_cache') and 'reviews' in obj._prefetched_objects_cache:
            valid_reviews = [r for r in obj.reviews.all() if r.rating is not None and r.status != 'rejected']
            if valid_reviews:
                return round(sum(r.rating for r in valid_reviews) / len(valid_reviews), 1)
            return None

        # Fallback to DB query if not prefetched
        from django.db.models import Avg
        result = obj.reviews.filter(rating__isnull=False).exclude(status='rejected').aggregate(avg=Avg('rating'))
        avg = result['avg']
        return round(avg, 1) if avg is not None else None

    def get_rating_count(self, obj):
        # Use prefetched reviews if available
        if hasattr(obj, '_prefetched_objects_cache') and 'reviews' in obj._prefetched_objects_cache:
            valid_reviews = [r for r in obj.reviews.all() if r.rating is not None and r.status != 'rejected']
            return len(valid_reviews)

        # Fallback to DB query
        return obj.reviews.filter(rating__isnull=False).exclude(status='rejected').count()


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


class SalesOrderSerializer(serializers.ModelSerializer):
    items          = OrderItemSerializer(many=True, read_only=True)
    total_amount   = serializers.DecimalField(source='total_price', max_digits=12, decimal_places=2, read_only=True)
    customer_name  = serializers.CharField(source='customer.name', read_only=True)
    customer_email = serializers.CharField(source='customer.email', read_only=True)

    class Meta:
        model  = Order
        fields = ['id', 'created_at', 'total_amount', 'delivery_address', 'status',
                  'customer_name', 'customer_email', 'items']


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
        fields = ['id', 'label', 'recipient_name', 'street', 'city', 'zip_code', 'country', 'is_default', 'created_at']
        read_only_fields = ['id', 'created_at']


class PaymentCardSerializer(serializers.ModelSerializer):
    class Meta:
        model = PaymentCard
        fields = ['id', 'label', 'card_number', 'holder_name', 'expiry_date', 'is_default', 'created_at']
        read_only_fields = ['id', 'created_at']


class ProductReviewSerializer(serializers.ModelSerializer):
    customer_name  = serializers.CharField(source='customer.name', read_only=True)
    customer_email = serializers.CharField(source='customer.email', read_only=True)

    class Meta:
        model = ProductReview
        fields = ['id', 'product', 'customer', 'customer_name', 'customer_email', 'rating', 'comment', 'status', 'created_at', 'updated_at']
        read_only_fields = ['id', 'customer', 'status', 'created_at', 'updated_at']

class WishlistSerializer(serializers.ModelSerializer):
    product = ProductSerializer(read_only=True)

    class Meta:
        model  = Wishlist
        fields = ['id', 'product']