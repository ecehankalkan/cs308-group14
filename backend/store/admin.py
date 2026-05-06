from django.contrib import admin
from .models import (
    Customer, Category, Product, Order, OrderItem,
    Cart, DeliveryAddress, PaymentCard, ProductReview, Wishlist
)


@admin.register(Customer)
class CustomerAdmin(admin.ModelAdmin):
    list_display = ['id', 'email', 'name', 'role', 'is_active', 'created_at']
    list_filter = ['role', 'is_active']
    search_fields = ['email', 'name']
    readonly_fields = ['created_at']


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ['id', 'name', 'description']
    search_fields = ['name']


@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    list_display = ['id', 'name', 'category', 'price', 'discounted_price', 'stock_quantity']
    list_filter = ['category']
    search_fields = ['name', 'serial_number']


@admin.register(Order)
class OrderAdmin(admin.ModelAdmin):
    list_display = ['id', 'customer', 'status', 'total_price', 'created_at']
    list_filter = ['status']
    search_fields = ['customer__email']
    readonly_fields = ['created_at']


@admin.register(OrderItem)
class OrderItemAdmin(admin.ModelAdmin):
    list_display = ['id', 'order', 'product', 'quantity', 'price_at_purchase']


@admin.register(Cart)
class CartAdmin(admin.ModelAdmin):
    list_display = ['id', 'customer', 'product', 'quantity']
    search_fields = ['customer__email']


@admin.register(DeliveryAddress)
class DeliveryAddressAdmin(admin.ModelAdmin):
    list_display = ['id', 'customer', 'label', 'city', 'country', 'is_default']
    search_fields = ['customer__email', 'city']


@admin.register(PaymentCard)
class PaymentCardAdmin(admin.ModelAdmin):
    list_display = ['id', 'customer', 'label', 'holder_name', 'is_default']
    search_fields = ['customer__email', 'holder_name']


@admin.register(ProductReview)
class ProductReviewAdmin(admin.ModelAdmin):
    list_display = ['id', 'product', 'customer', 'rating', 'status', 'created_at']
    list_filter = ['status']
    list_editable = ['status']
    search_fields = ['product__name', 'customer__email', 'comment']
    readonly_fields = ['product', 'customer', 'order_item', 'rating', 'comment', 'created_at', 'updated_at']


@admin.register(Wishlist)
class WishlistAdmin(admin.ModelAdmin):
    list_display = ['id', 'customer', 'product']
    search_fields = ['customer__email', 'product__name']
