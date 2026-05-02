from datetime import timedelta

from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient

from store.models import Customer, Product, Order, OrderItem


class OrderTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.customer = Customer.objects.create_user(
            email='customer@test.com', password='pass1234!', name='Customer'
        )
        self.product = Product.objects.create(
            name='Test Book', price=25.00, stock_quantity=10, serial_number='SN-001'
        )

    def _order(self, customer=None, status=Order.Status.PROCESSING, qty=2, days_ago=0):
        customer = customer or self.customer
        order = Order.objects.create(
            customer=customer,
            total_price=self.product.price * qty,
            status=status,
            delivery_address='123 Test St, Test City',
        )
        OrderItem.objects.create(
            order=order,
            product=self.product,
            quantity=qty,
            price_at_purchase=self.product.price,
        )
        if days_ago:
            Order.objects.filter(pk=order.pk).update(
                created_at=timezone.now() - timedelta(days=days_ago)
            )
            order.refresh_from_db()
        return order

    def test_order_list_requires_authentication(self):
        r = self.client.get('/api/orders/')
        self.assertEqual(r.status_code, 401)

    def test_order_list_returns_only_own_orders(self):
        other = Customer.objects.create_user(
            email='other@test.com', password='pass1234!', name='Other'
        )
        self._order()
        self._order(customer=other)
        self.client.force_authenticate(user=self.customer)
        r = self.client.get('/api/orders/')
        self.assertEqual(r.status_code, 200)
        self.assertEqual(len(r.data), 1)

    def test_cancel_processing_order_succeeds(self):
        order = self._order()
        self.client.force_authenticate(user=self.customer)
        r = self.client.post(f'/api/orders/{order.pk}/action/', {'action': 'cancel'})
        self.assertEqual(r.status_code, 200)
        order.refresh_from_db()
        self.assertEqual(order.status, Order.Status.CANCELLED)

    def test_cancel_order_restocks_product(self):
        initial_stock = self.product.stock_quantity
        order = self._order(qty=3)
        self.client.force_authenticate(user=self.customer)
        self.client.post(f'/api/orders/{order.pk}/action/', {'action': 'cancel'})
        self.product.refresh_from_db()
        self.assertEqual(self.product.stock_quantity, initial_stock + 3)

    def test_cancel_in_transit_order_fails(self):
        order = self._order(status=Order.Status.IN_TRANSIT)
        self.client.force_authenticate(user=self.customer)
        r = self.client.post(f'/api/orders/{order.pk}/action/', {'action': 'cancel'})
        self.assertEqual(r.status_code, 400)

    def test_refund_request_on_delivered_order_succeeds(self):
        order = self._order(status=Order.Status.DELIVERED)
        self.client.force_authenticate(user=self.customer)
        r = self.client.post(f'/api/orders/{order.pk}/action/', {'action': 'refund'})
        self.assertEqual(r.status_code, 200)
        order.refresh_from_db()
        self.assertEqual(order.status, Order.Status.REFUND_REQUESTED)

    def test_refund_request_on_processing_order_fails(self):
        order = self._order(status=Order.Status.PROCESSING)
        self.client.force_authenticate(user=self.customer)
        r = self.client.post(f'/api/orders/{order.pk}/action/', {'action': 'refund'})
        self.assertEqual(r.status_code, 400)

    def test_refund_request_after_30_days_fails(self):
        order = self._order(status=Order.Status.DELIVERED, days_ago=31)
        self.client.force_authenticate(user=self.customer)
        r = self.client.post(f'/api/orders/{order.pk}/action/', {'action': 'refund'})
        self.assertEqual(r.status_code, 400)

    def test_invoice_endpoint_returns_pdf(self):
        order = self._order()
        r = self.client.get(f'/api/sales/orders/{order.pk}/invoice/')
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r['Content-Type'], 'application/pdf')

    def test_sales_order_list_shows_all_orders(self):
        other = Customer.objects.create_user(
            email='other2@test.com', password='pass1234!', name='Other2'
        )
        self._order()
        self._order(customer=other)
        r = self.client.get('/api/sales/orders/')
        self.assertEqual(r.status_code, 200)
        self.assertGreaterEqual(len(r.data), 2)
