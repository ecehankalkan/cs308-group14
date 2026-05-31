from django.test import TestCase
from rest_framework.test import APIClient
from django.core import mail

from store.models import Customer, Product, Category, Wishlist


class ProductTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.category = Category.objects.create(name='Books')
        self.product = Product.objects.create(
            name='Django Unleashed',
            price=45.00,
            stock_quantity=20,
            serial_number='SN-100',
            category=self.category,
        )
        self.customer = Customer.objects.create_user(
            email='customer@test.com', password='pass1234!', name='Customer',
            role=Customer.Role.CUSTOMER,
        )
        self.product_manager = Customer.objects.create_user(
            email='pm@test.com', password='pass1234!', name='PM',
            role=Customer.Role.PRODUCT_MANAGER,
        )
        self.sales_manager = Customer.objects.create_user(
            email='sm@test.com', password='pass1234!', name='SM',
            role=Customer.Role.SALES_MANAGER,
        )

    def test_product_list_is_publicly_accessible(self):
        r = self.client.get('/api/products/')
        self.assertEqual(r.status_code, 200)
        self.assertEqual(len(r.data), 1)

    def test_product_search_filters_by_name(self):
        Product.objects.create(
            name='Flask Guide', price=30.00, stock_quantity=5, serial_number='SN-101'
        )
        r = self.client.get('/api/products/?search=Django')
        self.assertEqual(r.status_code, 200)
        self.assertEqual(len(r.data), 1)
        self.assertEqual(r.data[0]['name'], 'Django Unleashed')

    def test_product_detail_returns_correct_product(self):
        r = self.client.get(f'/api/products/{self.product.pk}/')
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.data['id'], self.product.pk)
        self.assertEqual(r.data['name'], self.product.name)

    def test_product_detail_not_found_returns_404(self):
        r = self.client.get('/api/products/99999/')
        self.assertEqual(r.status_code, 404)

    def test_stock_update_by_product_manager_succeeds(self):
        self.client.force_authenticate(user=self.product_manager)
        r = self.client.patch(
            f'/api/products/{self.product.pk}/stock/', {'stock_quantity': 50},
            format='json'
        )
        self.assertEqual(r.status_code, 200)
        self.product.refresh_from_db()
        self.assertEqual(self.product.stock_quantity, 50)

    def test_stock_increase_by_product_manager_succeeds(self):
        self.client.force_authenticate(user=self.product_manager)
        r = self.client.patch(
            f'/api/products/{self.product.pk}/stock/', {'stock_delta': 5},
            format='json'
        )
        self.assertEqual(r.status_code, 200)
        self.product.refresh_from_db()
        self.assertEqual(self.product.stock_quantity, 25)

    def test_stock_decrease_by_product_manager_succeeds(self):
        self.client.force_authenticate(user=self.product_manager)
        r = self.client.patch(
            f'/api/products/{self.product.pk}/stock/', {'stock_delta': -5},
            format='json'
        )
        self.assertEqual(r.status_code, 200)
        self.product.refresh_from_db()
        self.assertEqual(self.product.stock_quantity, 15)

    def test_stock_decrease_below_zero_fails(self):
        self.client.force_authenticate(user=self.product_manager)
        r = self.client.patch(
            f'/api/products/{self.product.pk}/stock/', {'stock_delta': -25},
            format='json'
        )
        self.assertEqual(r.status_code, 400)
        self.product.refresh_from_db()
        self.assertEqual(self.product.stock_quantity, 20)

    def test_stock_update_by_regular_customer_fails(self):
        self.client.force_authenticate(user=self.customer)
        r = self.client.patch(
            f'/api/products/{self.product.pk}/stock/', {'stock_quantity': 50}
        )
        self.assertEqual(r.status_code, 403)

    def test_discount_by_sales_manager_succeeds(self):
        self.client.force_authenticate(user=self.sales_manager)
        r = self.client.post(
            f'/api/products/{self.product.pk}/discount/', {'discounted_price': 35.00}
        )
        self.assertEqual(r.status_code, 200)
        self.product.refresh_from_db()
        self.assertEqual(float(self.product.discounted_price), 35.00)

    def test_discount_by_regular_customer_fails(self):
        self.client.force_authenticate(user=self.customer)
        r = self.client.post(
            f'/api/products/{self.product.pk}/discount/', {'discounted_price': 35.00}
        )
        self.assertEqual(r.status_code, 403)

    def test_price_update_with_discount_percentage_sets_discounted_price(self):
        self.client.force_authenticate(user=self.sales_manager)
        r = self.client.patch(
            f'/api/products/{self.product.pk}/price/',
            {'price': 40.00, 'discount_percentage': 25},
        )
        self.assertEqual(r.status_code, 200)
        self.product.refresh_from_db()
        self.assertEqual(float(self.product.price), 40.00)
        self.assertAlmostEqual(float(self.product.discounted_price), 30.00, places=2)

    def test_wishlist_discount_notification_email(self):
        # Create a wishlist entry for the customer
        Wishlist.objects.create(customer=self.customer, product=self.product)

        # Now update the discount as sales manager
        self.client.force_authenticate(user=self.sales_manager)
        r = self.client.post(
            f'/api/products/{self.product.pk}/discount/',
            {'discounted_price': 30.00}
        )
        self.assertEqual(r.status_code, 200)

        # Verify an email was sent
        self.assertEqual(len(mail.outbox), 1)
        self.assertIn("Price drop on Django Unleashed", mail.outbox[0].subject)
        self.assertEqual(mail.outbox[0].to, [self.customer.email])

    def test_price_update_by_regular_customer_fails(self):
        self.client.force_authenticate(user=self.customer)
        r = self.client.patch(
            f'/api/products/{self.product.pk}/price/', {'price': 10.00}, format='json'
        )
        self.assertEqual(r.status_code, 403)

    def test_price_update_to_zero_on_active_product_fails(self):
        self.client.force_authenticate(user=self.sales_manager)
        r = self.client.patch(
            f'/api/products/{self.product.pk}/price/', {'price': 0}, format='json'
        )
        self.assertEqual(r.status_code, 400)

    def test_my_review_returns_204_when_no_review_exists(self):
        self.client.force_authenticate(user=self.customer)
        r = self.client.get(f'/api/products/{self.product.pk}/my-review/')
        self.assertEqual(r.status_code, 204)

    def test_my_review_returns_own_review(self):
        from store.models import ProductReview
        review = ProductReview.objects.create(
            product=self.product,
            customer=self.customer,
            rating=4,
            comment='Great book',
            status=ProductReview.Status.PENDING,
        )
        self.client.force_authenticate(user=self.customer)
        r = self.client.get(f'/api/products/{self.product.pk}/my-review/')
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.data['id'], review.pk)

