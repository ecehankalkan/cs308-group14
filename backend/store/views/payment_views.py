from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from django.db import transaction
from django.utils import timezone
from decimal import Decimal

from ..models import Cart, Order, OrderItem, Product, DeliveryAddress, PaymentCard
from ..services.invoice_service import generate_invoice_pdf
from django.core.mail import EmailMessage


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def checkout_view(request):
    """
    Process checkout: create order, reduce stock, generate invoice, send email
    
    Expected data:
    {
        "shipping_address": "123 Main St, City, ZIP, Country",
        "card_last_four": "1234",
        "address_id": 1,  // optional: ID of saved address used
        "card_id": 1      // optional: ID of saved card used
    }
    """
    customer = request.user
    shipping_address = request.data.get('shipping_address', '').strip()
    card_last_four = request.data.get('card_last_four', '****')
    address_id = request.data.get('address_id')
    card_id = request.data.get('card_id')
    
    # Validation
    if not shipping_address:
        return Response(
            {'error': 'Shipping address is required'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    # Get user's cart items
    cart_items = Cart.objects.filter(customer=customer).select_related('product')
    
    if not cart_items.exists():
        return Response(
            {'error': 'Cart is empty'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    # Validate stock and calculate total
    order_items_data = []
    total_price = Decimal('0.00')
    
    for cart_item in cart_items:
        product = cart_item.product
        quantity = cart_item.quantity
        
        # Check stock availability
        if product.stock_quantity < quantity:
            return Response(
                {
                    'error': f'Insufficient stock for {product.name}. Available: {product.stock_quantity}, Requested: {quantity}'
                },
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Calculate price
        price = product.effective_price()
        item_total = price * quantity
        total_price += item_total
        
        order_items_data.append({
            'product': product,
            'quantity': quantity,
            'price': price,
            'item_total': item_total
        })
    
    # Create order and update stock in a transaction
    try:
        with transaction.atomic():
            # Create order
            order = Order.objects.create(
                customer=customer,
                total_price=total_price,
                delivery_address=shipping_address,
                status=Order.Status.PROCESSING
            )
            
            # Create order items and reduce stock
            for item_data in order_items_data:
                product = item_data['product']
                
                OrderItem.objects.create(
                    order=order,
                    product=product,
                    quantity=item_data['quantity'],
                    price_at_purchase=item_data['price']
                )
                
                # Reduce stock
                product.stock_quantity -= item_data['quantity']
                product.save()
            
            # Clear cart
            cart_items.delete()
            
            # Generate invoice
            invoice_data = {
                "id": f"ORD-{order.id}",
                "date": order.created_at.strftime("%B %d, %Y %I:%M %p"),
                "total_price": float(total_price),
                "address": shipping_address,
                "items": [
                    {
                        "product_name": item['product'].name,
                        "price": float(item['price']),
                        "quantity": item['quantity']
                    }
                    for item in order_items_data
                ]
            }
            
            pdf_bytes = generate_invoice_pdf(invoice_data)
            
            # Send email with invoice
            email = EmailMessage(
                subject=f"Your Order Confirmation - Order #{order.id}",
                body=f"Dear {customer.name},\n\nThank you for your purchase! Your order has been confirmed.\n\nOrder ID: ORD-{order.id}\nTotal Amount: ${total_price}\n\nYour invoice is attached. We'll notify you when your order ships!\n\nBest regards,\ninkcloud Team",
                from_email="orders@inkcloud.com",
                to=[customer.email],
            )
            email.attach(f"invoice_ORD-{order.id}.pdf", pdf_bytes, "application/pdf")
            email.send(fail_silently=False)
            
            return Response({
                'success': True,
                'order_id': order.id,
                'order_number': f'ORD-{order.id}',
                'total_amount': float(total_price),
                'items_count': len(order_items_data),
                'delivery_address': shipping_address,
                'message': 'Payment successful! Invoice sent to your email.',
                'created_at': order.created_at.isoformat()
            }, status=status.HTTP_201_CREATED)
            
    except Exception as e:
        return Response(
            {'error': f'Checkout failed: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
