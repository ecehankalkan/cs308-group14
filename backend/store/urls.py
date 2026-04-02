from django.urls import path
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from . import views

urlpatterns = [
    # Auth
    path('register/',      views.RegisterView.as_view(),     name='register'),
    path('login/',         TokenObtainPairView.as_view(),    name='login'),
    path('token/refresh/', TokenRefreshView.as_view(),       name='token_refresh'),
    path('me/',            views.MeView.as_view(),           name='me'),

    # Products (public list/detail + manager write operations)
    path('products/',                        views.ProductListView.as_view(),     name='product_list'),
    path('products/<int:pk>/',               views.ProductDetailView.as_view(),   name='product_detail'),
    path('products/<int:pk>/stock/',         views.ProductStockView.as_view(),    name='product_stock'),
    path('products/<int:pk>/discount/',      views.ProductDiscountView.as_view(), name='product_discount'),

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
    path('reviews/',                        views.ReviewListView.as_view(),       name='review_list'),
    path('reviews/<int:pk>/approve/',       views.ReviewApproveView.as_view(),    name='review_approve'),
    path('reviews/<int:pk>/disapprove/',    views.ReviewDisapproveView.as_view(), name='review_disapprove'),

    # Refunds
    path('refunds/', views.RefundView.as_view(), name='refund_list'),

    # Deliveries
    path('deliveries/',              views.DeliveryView.as_view(),         name='delivery_list'),
    path('deliveries/<int:pk>/complete/', views.DeliveryCompleteView.as_view(), name='delivery_complete'),

    # Sales Manager
    path('invoices/', views.InvoiceView.as_view(),  name='invoice_list'),
    path('revenue/',  views.RevenueView.as_view(),  name='revenue'),
]