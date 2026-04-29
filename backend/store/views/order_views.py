from django.http import HttpResponse
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
