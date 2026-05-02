from django.test import TestCase
from rest_framework.test import APIClient

from store.models import Customer, Product, Cart


class CartTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.customer = Customer.objects.create_user(
            email='cart@test.com', password='pass1234!', name='Cart User'
        )
        self.product = Product.objects.create(
            name='Cart Book', price=20.00, stock_quantity=15, serial_number='SN-200'
        )

    def test_get_cart_requires_authentication(self):
        r = self.client.get('/api/cart/')
        self.assertEqual(r.status_code, 401)

    def test_add_item_to_cart(self):
        self.client.force_authenticate(user=self.customer)
        r = self.client.post('/api/cart/', {'product_id': self.product.pk, 'quantity': 1})
        self.assertIn(r.status_code, [200, 201])
        self.assertEqual(Cart.objects.filter(customer=self.customer).count(), 1)

    def test_adding_same_item_twice_increases_quantity(self):
        self.client.force_authenticate(user=self.customer)
        self.client.post('/api/cart/', {'product_id': self.product.pk, 'quantity': 1})
        r = self.client.post('/api/cart/', {'product_id': self.product.pk, 'quantity': 2})
        self.assertEqual(r.status_code, 200)
        item = Cart.objects.get(customer=self.customer, product=self.product)
        self.assertEqual(item.quantity, 3)

    def test_remove_item_from_cart(self):
        self.client.force_authenticate(user=self.customer)
        self.client.post('/api/cart/', {'product_id': self.product.pk, 'quantity': 1})
        item = Cart.objects.get(customer=self.customer, product=self.product)
        r = self.client.delete(f'/api/cart/{item.pk}/')
        self.assertEqual(r.status_code, 204)
        self.assertFalse(Cart.objects.filter(customer=self.customer).exists())

    def test_update_cart_item_quantity(self):
        self.client.force_authenticate(user=self.customer)
        self.client.post('/api/cart/', {'product_id': self.product.pk, 'quantity': 1})
        item = Cart.objects.get(customer=self.customer, product=self.product)
        r = self.client.patch(f'/api/cart/{item.pk}/', {'quantity': 5})
        self.assertEqual(r.status_code, 200)
        item.refresh_from_db()
        self.assertEqual(item.quantity, 5)

    def test_guest_cart_add_item(self):
        r = self.client.post('/api/guest/cart/', {'product_id': self.product.pk, 'quantity': 1})
        self.assertIn(r.status_code, [200, 201])

    def test_guest_cart_get_returns_session_items(self):
        self.client.post('/api/guest/cart/', {'product_id': self.product.pk, 'quantity': 1})
        r = self.client.get('/api/guest/cart/')
        self.assertEqual(r.status_code, 200)
        self.assertEqual(len(r.data), 1)
