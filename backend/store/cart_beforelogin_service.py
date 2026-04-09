from .models import Cart

class CartBeforeLoginService:
    """Service class specifically for handling cart actions before and during login."""

    @staticmethod
    def merge_guest_cart(session_key, user):
        """
        Merge the anonymous session cart into the user's cart after login/register.
        """
        if not session_key:
            return
            
        guest_items = Cart.objects.filter(session_key=session_key)
        for guest_item in guest_items:
            user_item, created = Cart.objects.get_or_create(
                customer=user,
                product=guest_item.product,
                defaults={'quantity': guest_item.quantity}
            )
            if not created:
                user_item.quantity += guest_item.quantity
                user_item.save(update_fields=['quantity'])
                
            guest_item.delete()

    @staticmethod
    def add_product_to_cart(customer, session_key, product_id, quantity=1):
        """
        Adds a product to the cart or increments the quantity if it already exists.
        Returns the existing item if aggregated, or None if a new item needs to be created.
        """
        if not product_id:
            return None
            
        existing_item = Cart.objects.filter(
            customer=customer, 
            session_key=session_key, 
            product_id=product_id
        ).first()

        if existing_item:
            existing_item.quantity += quantity
            existing_item.save(update_fields=['quantity'])
            return existing_item

        return None
