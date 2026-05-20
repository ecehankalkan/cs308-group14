from datetime import timedelta

from django.core.mail import send_mail
from django.http import HttpResponse
from django.utils import timezone
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from ..models import Order
from ..serializers import OrderSerializer, SalesOrderSerializer
from ..services.invoice_service import generate_invoice_pdf


class OrderListView(generics.ListAPIView):
    """GET /api/orders/"""
    serializer_class   = OrderSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return (
            Order.objects
            .filter(customer=self.request.user)
            .prefetch_related('items__product')
            .order_by('-created_at')
        )


class SalesOrderListView(generics.ListAPIView):
    """GET /api/sales/orders/ — all orders for the sales manager dashboard"""
    serializer_class   = SalesOrderSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        return (
            Order.objects
            .select_related('customer')
            .prefetch_related('items__product')
            .order_by('-created_at')
        )


class SalesOrderInvoiceView(APIView):
    """GET /api/sales/orders/<pk>/invoice/ — stream invoice PDF for a given order.
    Add ?download=1 to get Content-Disposition: attachment (triggers browser download).
    Without it the PDF opens inline (browser preview).
    """
    permission_classes = [permissions.AllowAny]

    def get(self, request, pk):
        try:
            order = (
                Order.objects
                .prefetch_related('items__product')
                .get(pk=pk)
            )
        except Order.DoesNotExist:
            return Response({'error': 'Order not found'}, status=status.HTTP_404_NOT_FOUND)

        invoice_data = {
            'id': f'ORD-{order.id}',
            'date': order.created_at.strftime('%B %d, %Y %I:%M %p'),
            'total_price': float(order.total_price),
            'address': order.delivery_address,
            'items': [
                {
                    'product_name': item.product.name,
                    'price': float(item.price_at_purchase),
                    'quantity': item.quantity,
                }
                for item in order.items.all()
            ],
        }

        pdf_bytes = generate_invoice_pdf(invoice_data)
        download = request.query_params.get('download', '0') == '1'
        disposition = 'attachment' if download else 'inline'

        http_response = HttpResponse(pdf_bytes, content_type='application/pdf')
        http_response['Content-Disposition'] = f'{disposition}; filename="invoice_ORD-{order.id}.pdf"'
        return http_response


class OrderActionView(APIView):
    """POST /api/orders/<pk>/action/  — user cancels or requests a refund"""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        try:
            order = (
                Order.objects
                .prefetch_related('items__product')
                .get(pk=pk, customer=request.user)
            )
        except Order.DoesNotExist:
            return Response({'error': 'Order not found'}, status=status.HTTP_404_NOT_FOUND)

        action = request.data.get('action')

        if action == 'cancel':
            if order.status != Order.Status.PROCESSING:
                return Response(
                    {'error': 'Only processing orders can be cancelled.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            # Restock items
            for item in order.items.all():
                product = item.product
                product.stock_quantity += item.quantity
                product.save(update_fields=['stock_quantity'])
            order.status = Order.Status.CANCELLED
            order.save(update_fields=['status'])
            return Response({'message': 'Order cancelled successfully.', 'status': order.status})

        if action == 'refund':
            if order.status != Order.Status.DELIVERED:
                return Response(
                    {'error': 'Only delivered orders are eligible for a refund.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            if timezone.now() - order.created_at > timedelta(days=30):
                return Response(
                    {'error': 'Refund window has expired (30 days).'},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            order.status = Order.Status.REFUND_REQUESTED
            order.save(update_fields=['status'])
            return Response({'message': 'Refund requested successfully.', 'status': order.status})

        return Response({'error': 'Invalid action. Use "cancel" or "refund".'}, status=status.HTTP_400_BAD_REQUEST)


class SalesRefundDecisionView(APIView):
    """POST /api/sales/orders/<pk>/refund-decision/ — manager accepts or rejects a refund"""
    permission_classes = [permissions.AllowAny]

    def post(self, request, pk):
        try:
            order = (
                Order.objects
                .prefetch_related('items__product')
                .get(pk=pk)
            )
        except Order.DoesNotExist:
            return Response({'error': 'Order not found'}, status=status.HTTP_404_NOT_FOUND)

        if order.status != Order.Status.REFUND_REQUESTED:
            return Response(
                {'error': 'Order is not pending a refund request.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        decision = request.data.get('decision')
        customer_email = order.customer.email
        order_ref = f'ORD-{order.id}'

        # Build itemized refund breakdown using the price PAID at purchase time.
        # We deliberately read item.price_at_purchase (NOT product.price or
        # product.discounted_price) so later price changes never affect the email.
        item_lines = []
        items_total = 0.0
        for item in order.items.all():
            unit_price = float(item.price_at_purchase)
            line_total = unit_price * item.quantity
            items_total += line_total
            item_lines.append(
                f'  - {item.product.name} x{item.quantity} '
                f'@ ${unit_price:.2f} = ${line_total:.2f}'
            )
        items_breakdown = '\n'.join(item_lines) if item_lines else '  (no items)'
        amount = items_total  # equals order.total_price, but computed from purchase-time prices

        if decision == 'accept':
            # Restock items
            for item in order.items.all():
                product = item.product
                product.stock_quantity += item.quantity
                product.save(update_fields=['stock_quantity'])
            order.status = Order.Status.REFUNDED
            order.save(update_fields=['status'])
            send_mail(
                subject=f'Refund Accepted for Order {order_ref}',
                message=(
                    f'Hello,\n\n'
                    f'Your refund request for order {order_ref} has been ACCEPTED.\n\n'
                    f'Refund breakdown (prices as paid at time of purchase):\n'
                    f'{items_breakdown}\n\n'
                    f'Total refund: ${amount:.2f}\n\n'
                    f'This amount will be credited back to your original payment method.\n\n'
                    f'Thank you,\nInkCloud Team'
                ),
                from_email=None,  # uses DEFAULT_FROM_EMAIL from settings
                recipient_list=[customer_email],
                fail_silently=True,
            )
            return Response({'message': 'Refund accepted.', 'status': order.status})

        if decision == 'reject':
            order.status = Order.Status.REFUND_REJECTED
            order.save(update_fields=['status'])
            send_mail(
                subject=f'Refund Rejected for Order {order_ref}',
                message=(
                    f'Hello,\n\n'
                    f'Unfortunately, your refund request for order {order_ref} has been REJECTED.\n\n'
                    f'For reference, your original order (prices as paid at purchase):\n'
                    f'{items_breakdown}\n\n'
                    f'Order total: ${amount:.2f}\n\n'
                    f'If you have questions, please contact our support team.\n\n'
                    f'Thank you,\nInkCloud Team'
                ),
                from_email=None,
                recipient_list=[customer_email],
                fail_silently=True,
            )
            return Response({'message': 'Refund rejected.', 'status': order.status})

        return Response({'error': 'Invalid decision. Use "accept" or "reject".'}, status=status.HTTP_400_BAD_REQUEST)
