from .auth_views import RegisterView, CustomTokenObtainPairView, MeView
from .product_views import ProductListView, ProductDetailView, ProductStockView, ProductDiscountView, IsSalesManager, IsProductManager
from .cart_views import CartView, CartItemView
from .guest_cart_views import GuestCartView, GuestCartItemView
from .test_views import test_invoice_email

__all__ = [
    'RegisterView',
    'CustomTokenObtainPairView',
    'MeView',
    'ProductListView',
    'ProductDetailView',
    'ProductStockView',
    'ProductDiscountView',
    'IsSalesManager',
    'IsProductManager',
    'CartView',
    'CartItemView',
    'GuestCartView',
    'GuestCartItemView',
    'test_invoice_email',
]
