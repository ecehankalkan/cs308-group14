from django.urls import path
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from . import views

urlpatterns = [
    # Auth
    path('register/',      views.RegisterView.as_view(),     name='register'),
    path('login/',         views.CustomTokenObtainPairView.as_view(), name='login'),
    path('token/refresh/', TokenRefreshView.as_view(),       name='token_refresh'),
    path('me/',            views.MeView.as_view(),           name='me'),
    path('profile/',       views.ProfileView.as_view(),      name='profile'),
    path('orders/',        views.OrderListView.as_view(),    name='orders'),
    path('orders/<int:pk>/action/', views.OrderActionView.as_view(), name='order_action'),
    path('sales/orders/', views.SalesOrderListView.as_view(), name='sales_orders'),
    path('sales/orders/<int:pk>/invoice/', views.SalesOrderInvoiceView.as_view(), name='sales_order_invoice'),
    path('sales/orders/<int:pk>/refund-decision/', views.SalesRefundDecisionView.as_view(), name='sales_refund_decision'),

    # Products (public list/detail + manager write operations)
    path('products/',                        views.ProductListView.as_view(),     name='product_list'),
    path('products/<int:pk>/',               views.ProductDetailView.as_view(),   name='product_detail'),
    path('products/<int:pk>/stock/',         views.ProductStockView.as_view(),    name='product_stock'),
    path('products/<int:pk>/discount/',      views.ProductDiscountView.as_view(), name='product_discount'),
    path('products/<int:pk>/price/',         views.ProductPriceView.as_view(),    name='product_price'),
    path('products/<int:product_id>/reviews/', views.ProductReviewListCreateView.as_view(), name='product_reviews'),
    path('products/<int:product_id>/my-review/', views.MyProductReviewView.as_view(), name='my_review'),
    path('reviews/<int:pk>/',                views.ProductReviewDetailView.as_view(),     name='review_detail'),

    # Cart (Authenticated Only)
    path('cart/',          views.CartView.as_view(),         name='cart'),
    path('cart/<int:pk>/', views.CartItemView.as_view(),     name='cart_item'),

    # Guest Cart (Before Login)
    path('guest/cart/',          views.GuestCartView.as_view(),         name='guest_cart'),
    path('guest/cart/<int:pk>/', views.GuestCartItemView.as_view(),     name='guest_cart_item'),

    # Checkout & Payment
    path('checkout/', views.checkout_view, name='checkout'),

    # Delivery Addresses
    path('addresses/', views.DeliveryAddressListView.as_view(), name='address_list'),
    path('addresses/<int:pk>/', views.DeliveryAddressDetailView.as_view(), name='address_detail'),

    # Payment Cards (MOCK DATA ONLY - for testing)
    path('payment-cards/', views.PaymentCardListView.as_view(), name='payment_card_list'),
    path('payment-cards/<int:pk>/', views.PaymentCardDetailView.as_view(), name='payment_card_detail'),

    # Wishlist (Authenticated Only)
    path('wishlist/',                  views.WishlistView.as_view(),     name='wishlist'),
    path('wishlist/<int:product_id>/', views.WishlistItemView.as_view(), name='wishlist_item'),

    # Testing Endpoint for Invoices & Emails (SCRUM 54-56)
    path('test-invoice/', views.test_invoice_email, name='test_invoice'),
]