from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from django.core.mail import send_mail
from django.conf import settings

from ..models import Product, Wishlist
from ..serializers import WishlistSerializer


class WishlistView(APIView):
    """
    GET  /api/wishlist/        — returns all wishlist items for the logged-in user
    POST /api/wishlist/        — adds a product to the wishlist
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        items = Wishlist.objects.filter(customer=request.user).select_related('product').prefetch_related('product__reviews')
        serializer = WishlistSerializer(items, many=True)
        return Response(serializer.data)

    def post(self, request):
        product_id = request.data.get('product_id')
        if not product_id:
            return Response(
                {'error': 'product_id is required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        try:
            product = Product.objects.get(pk=product_id)
        except Product.DoesNotExist:
            return Response(
                {'error': 'Product not found'},
                status=status.HTTP_404_NOT_FOUND
            )

        # If already in wishlist, return it without duplicating
        item, created = Wishlist.objects.get_or_create(
            customer=request.user,
            product=product,
        )
        serializer = WishlistSerializer(item)
        return Response(
            serializer.data,
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK
        )


class WishlistItemView(APIView):
    """
    DELETE /api/wishlist/<product_id>/ — removes a product from the wishlist
    """
    permission_classes = [IsAuthenticated]

    def delete(self, request, product_id):
        try:
            item = Wishlist.objects.get(customer=request.user, product_id=product_id)
            item.delete()
            return Response(status=status.HTTP_204_NO_CONTENT)
        except Wishlist.DoesNotExist:
            return Response(
                {'error': 'Item not in wishlist'},
                status=status.HTTP_404_NOT_FOUND
            )


def notify_wishlist_users(product: Product):
    """
    Called when a discount is applied to a product.
    Sends an email to every customer who has this product in their wishlist.
    """
    wishlist_entries = Wishlist.objects.filter(product=product).select_related('customer')
    emails = [entry.customer.email for entry in wishlist_entries if entry.customer.email]

    if not emails:
        return

    effective_price = product.discounted_price if product.discounted_price else product.price
    discount_amount = product.price - effective_price

    subject = f"Price drop on {product.name} in your wishlist!"
    message = (
        f"Hi,\n\n"
        f"Great news! A product in your inkcloud wishlist just got a discount.\n\n"
        f"Product: {product.name}\n"
        f"Original price: ${product.price:.2f}\n"
        f"New price: ${effective_price:.2f}\n"
        f"You save: ${discount_amount:.2f}\n\n"
        f"Visit inkcloud to grab it before it sells out!\n\n"
        f"— The inkcloud team"
    )

    send_mail(
        subject=subject,
        message=message,
        from_email=settings.DEFAULT_FROM_EMAIL,
        recipient_list=emails,
        fail_silently=True,  # don't crash if email fails
    )