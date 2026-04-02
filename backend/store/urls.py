from django.urls import path
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from . import views

urlpatterns = [
    # Auth
    path('register/',      views.RegisterView.as_view(),     name='register'),
    path('login/',         TokenObtainPairView.as_view(),    name='login'),
    path('token/refresh/', TokenRefreshView.as_view(),       name='token_refresh'),
    path('me/',            views.MeView.as_view(),           name='me'),

    # Products
    path('products/',            views.ProductListView.as_view(),   name='product_list'),
    path('products/<int:pk>/',   views.ProductDetailView.as_view(), name='product_detail'),

    # Cart
    path('cart/',          views.CartView.as_view(),         name='cart'),
    path('cart/<int:pk>/', views.CartItemView.as_view(),     name='cart_item'),

    # Wishlist
    path('wishlist/',          views.WishlistView.as_view(),     name='wishlist'),
    path('wishlist/<int:pk>/', views.WishlistItemView.as_view(), name='wishlist_item'),

    # Orders
    path('orders/',          views.OrderListView.as_view(),   name='order_list'),
    path('orders/<int:pk>/', views.OrderDetailView.as_view(), name='order_detail'),

    # Reviews
    path('reviews/', views.ReviewListView.as_view(), name='review_list'),

    # Refunds
    path('refunds/', views.RefundView.as_view(), name='refund_list'),

    # Deliveries
    path('deliveries/', views.DeliveryView.as_view(), name='delivery_list'),
]
