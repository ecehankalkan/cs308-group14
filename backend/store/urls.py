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

    # Products (public list/detail + manager write operations)
    path('products/',                        views.ProductListView.as_view(),     name='product_list'),
    path('products/<int:pk>/',               views.ProductDetailView.as_view(),   name='product_detail'),
    path('products/<int:pk>/stock/',         views.ProductStockView.as_view(),    name='product_stock'),
    path('products/<int:pk>/discount/',      views.ProductDiscountView.as_view(), name='product_discount'),

    # Cart (Authenticated Only)
    path('cart/',          views.CartView.as_view(),         name='cart'),
    path('cart/<int:pk>/', views.CartItemView.as_view(),     name='cart_item'),

    # Guest Cart (Before Login)
    path('guest/cart/',          views.GuestCartView.as_view(),         name='guest_cart'),
    path('guest/cart/<int:pk>/', views.GuestCartItemView.as_view(),     name='guest_cart_item'),

    # Checkout & Payment
    path('checkout/', views.checkout_view, name='checkout'),

    # Testing Endpoint for Invoices & Emails (SCRUM 54-56)
    path('test-invoice/', views.test_invoice_email, name='test_invoice'),
]