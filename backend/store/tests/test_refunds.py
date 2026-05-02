from django.test import TestCase
from rest_framework.test import APIClient

from store.models import Customer, Product, Order, OrderItem


class RefundDecisionTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.customer = Customer.objects.create_user(
            email='customer@test.com', password='pass1234!', name='Customer'
        )
        self.product = Product.objects.create(
            name='Refund Book', price=30.00, stock_quantity=5, serial_number='SN-002'
        )

    def _order(self, status=Order.Status.REFUND_REQUESTED, qty=2):
        order = Order.objects.create(
            customer=self.customer,
            total_price=self.product.price * qty,
            status=status,
            delivery_address='456 Refund Ave',
        )
        OrderItem.objects.create(
            order=order,
            product=self.product,
            quantity=qty,
            price_at_purchase=self.product.price,
        )
        return order

    def test_accept_refund_changes_status_to_refunded(self):
        order = self._order()
        r = self.client.post(
            f'/api/sales/orders/{order.pk}/refund-decision/', {'decision': 'accept'}
        )
        self.assertEqual(r.status_code, 200)
        order.refresh_from_db()
        self.assertEqual(order.status, Order.Status.REFUNDED)

    def test_accept_refund_restocks_product(self):
        initial_stock = self.product.stock_quantity
        order = self._order(qty=2)
        self.client.post(
            f'/api/sales/orders/{order.pk}/refund-decision/', {'decision': 'accept'}
        )
        self.product.refresh_from_db()
        self.assertEqual(self.product.stock_quantity, initial_stock + 2)

    def test_reject_refund_changes_status_to_refund_rejected(self):
        order = self._order()
        r = self.client.post(
            f'/api/sales/orders/{order.pk}/refund-decision/', {'decision': 'reject'}
        )
        self.assertEqual(r.status_code, 200)
        order.refresh_from_db()
        self.assertEqual(order.status, Order.Status.REFUND_REJECTED)

    def test_refund_decision_on_non_pending_order_fails(self):
        order = self._order(status=Order.Status.DELIVERED)
        r = self.client.post(
            f'/api/sales/orders/{order.pk}/refund-decision/', {'decision': 'accept'}
        )
        self.assertEqual(r.status_code, 400)

    def test_invalid_refund_decision_returns_400(self):
        order = self._order()
        r = self.client.post(
            f'/api/sales/orders/{order.pk}/refund-decision/', {'decision': 'maybe'}
        )
        self.assertEqual(r.status_code, 400)

    def test_invalid_order_action_returns_400(self):
        order = Order.objects.create(
            customer=self.customer,
            total_price=50.00,
            status=Order.Status.PROCESSING,
            delivery_address='789 Action Blvd',
        )
        self.client.force_authenticate(user=self.customer)
        r = self.client.post(f'/api/orders/{order.pk}/action/', {'action': 'fly'})
        self.assertEqual(r.status_code, 400)
