from django.test import TestCase
from rest_framework.test import APIClient

from store.models import Customer, Category


class CategoryTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.customer = Customer.objects.create_user(
            email='customer@test.com', password='pass1234!', name='Customer',
            role=Customer.Role.CUSTOMER,
        )
        self.product_manager = Customer.objects.create_user(
            email='pm@test.com', password='pass1234!', name='PM',
            role=Customer.Role.PRODUCT_MANAGER,
        )
        self.active_category = Category.objects.create(name='Fiction', is_active=True)
        self.inactive_category = Category.objects.create(name='Hidden', is_active=False)

    def test_category_list_is_publicly_accessible(self):
        r = self.client.get('/api/categories/')
        self.assertEqual(r.status_code, 200)

    def test_inactive_categories_hidden_from_public(self):
        r = self.client.get('/api/categories/')
        self.assertEqual(r.status_code, 200)
        names = [c['name'] for c in r.data]
        self.assertIn('Fiction', names)
        self.assertNotIn('Hidden', names)

    def test_product_manager_sees_all_categories_including_inactive(self):
        self.client.force_authenticate(user=self.product_manager)
        r = self.client.get('/api/categories/')
        self.assertEqual(r.status_code, 200)
        names = [c['name'] for c in r.data]
        self.assertIn('Fiction', names)
        self.assertIn('Hidden', names)

    def test_create_category_by_product_manager(self):
        self.client.force_authenticate(user=self.product_manager)
        r = self.client.post('/api/categories/', {'name': 'Science', 'description': 'Science books'})
        self.assertEqual(r.status_code, 201)
        self.assertTrue(Category.objects.filter(name='Science').exists())

    def test_create_category_by_regular_customer_fails(self):
        self.client.force_authenticate(user=self.customer)
        r = self.client.post('/api/categories/', {'name': 'Hacked'})
        self.assertEqual(r.status_code, 403)

    def test_update_category_by_product_manager(self):
        self.client.force_authenticate(user=self.product_manager)
        r = self.client.patch(
            f'/api/categories/{self.active_category.pk}/',
            {'name': 'Updated Fiction'}, format='json'
        )
        self.assertEqual(r.status_code, 200)
        self.active_category.refresh_from_db()
        self.assertEqual(self.active_category.name, 'Updated Fiction')
