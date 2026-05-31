from django.test import TestCase
from rest_framework.test import APIClient

from store.models import Customer, Product, Wishlist


class WishlistTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.customer = Customer.objects.create_user(
            email='wish@test.com', password='pass1234!', name='Wish User'
        )
        self.product = Product.objects.create(
            name='Wishlist Book', price=30.00, stock_quantity=10
        )

    def test_get_wishlist_requires_authentication(self):
        r = self.client.get('/api/wishlist/')
        self.assertEqual(r.status_code, 401)

    def test_get_empty_wishlist(self):
        self.client.force_authenticate(user=self.customer)
        r = self.client.get('/api/wishlist/')
        self.assertEqual(r.status_code, 200)
        self.assertEqual(len(r.data), 0)

    def test_add_product_to_wishlist(self):
        self.client.force_authenticate(user=self.customer)
        r = self.client.post('/api/wishlist/', {'product_id': self.product.pk}, format='json')
        self.assertEqual(r.status_code, 201)
        self.assertTrue(Wishlist.objects.filter(customer=self.customer, product=self.product).exists())

    def test_add_same_product_twice_is_idempotent(self):
        self.client.force_authenticate(user=self.customer)
        self.client.post('/api/wishlist/', {'product_id': self.product.pk}, format='json')
        r = self.client.post('/api/wishlist/', {'product_id': self.product.pk}, format='json')
        self.assertEqual(r.status_code, 200)
        self.assertEqual(Wishlist.objects.filter(customer=self.customer).count(), 1)

    def test_add_nonexistent_product_returns_404(self):
        self.client.force_authenticate(user=self.customer)
        r = self.client.post('/api/wishlist/', {'product_id': 99999}, format='json')
        self.assertEqual(r.status_code, 404)

    def test_remove_product_from_wishlist(self):
        Wishlist.objects.create(customer=self.customer, product=self.product)
        self.client.force_authenticate(user=self.customer)
        r = self.client.delete(f'/api/wishlist/{self.product.pk}/')
        self.assertEqual(r.status_code, 204)
        self.assertFalse(Wishlist.objects.filter(customer=self.customer, product=self.product).exists())

    def test_remove_nonexistent_wishlist_item_returns_404(self):
        self.client.force_authenticate(user=self.customer)
        r = self.client.delete(f'/api/wishlist/{self.product.pk}/')
        self.assertEqual(r.status_code, 404)
