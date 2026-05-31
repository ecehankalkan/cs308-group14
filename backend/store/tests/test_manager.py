from django.test import TestCase
from rest_framework.test import APIClient

from store.models import Customer, Product, Order, OrderItem, ProductReview


class ReviewModerationTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.customer = Customer.objects.create_user(
            email='reviewer@test.com', password='pass1234!', name='Reviewer'
        )
        self.product = Product.objects.create(
            name='Review Book', price=20.00, stock_quantity=5
        )

    def _review(self, status=ProductReview.Status.PENDING):
        return ProductReview.objects.create(
            product=self.product,
            customer=self.customer,
            rating=4,
            comment='Good book',
            status=status,
        )

    def test_pending_reviews_list_returns_only_pending(self):
        self._review(status=ProductReview.Status.PENDING)
        self._review.__func__  # suppress lint
        accepted_customer = Customer.objects.create_user(
            email='accepted@test.com', password='pass1234!', name='Accepted'
        )
        ProductReview.objects.create(
            product=self.product, customer=accepted_customer,
            rating=3, status=ProductReview.Status.ACCEPTED
        )
        r = self.client.get('/api/manager/reviews/pending/')
        self.assertEqual(r.status_code, 200)
        self.assertEqual(len(r.data), 1)
        self.assertEqual(r.data[0]['status'], 'pending')

    def test_all_reviews_list_returns_all_statuses(self):
        self._review(status=ProductReview.Status.PENDING)
        other = Customer.objects.create_user(
            email='other@test.com', password='pass1234!', name='Other'
        )
        ProductReview.objects.create(
            product=self.product, customer=other,
            rating=5, status=ProductReview.Status.ACCEPTED
        )
        r = self.client.get('/api/manager/reviews/')
        self.assertEqual(r.status_code, 200)
        self.assertGreaterEqual(len(r.data), 2)

    def test_all_reviews_filter_by_accepted_status(self):
        self._review(status=ProductReview.Status.PENDING)
        other = Customer.objects.create_user(
            email='other2@test.com', password='pass1234!', name='Other2'
        )
        ProductReview.objects.create(
            product=self.product, customer=other,
            rating=5, status=ProductReview.Status.ACCEPTED
        )
        r = self.client.get('/api/manager/reviews/?status=accepted')
        self.assertEqual(r.status_code, 200)
        self.assertEqual(len(r.data), 1)
        self.assertEqual(r.data[0]['status'], 'accepted')

    def test_approve_review_changes_status_to_accepted(self):
        review = self._review()
        r = self.client.post(
            f'/api/manager/reviews/{review.pk}/moderate/', {'decision': 'approve'}, format='json'
        )
        self.assertEqual(r.status_code, 200)
        review.refresh_from_db()
        self.assertEqual(review.status, ProductReview.Status.ACCEPTED)

    def test_reject_review_changes_status_to_rejected(self):
        review = self._review()
        r = self.client.post(
            f'/api/manager/reviews/{review.pk}/moderate/', {'decision': 'reject'}, format='json'
        )
        self.assertEqual(r.status_code, 200)
        review.refresh_from_db()
        self.assertEqual(review.status, ProductReview.Status.REJECTED)

    def test_invalid_moderation_decision_returns_400(self):
        review = self._review()
        r = self.client.post(
            f'/api/manager/reviews/{review.pk}/moderate/', {'decision': 'maybe'}, format='json'
        )
        self.assertEqual(r.status_code, 400)

    def test_moderate_nonexistent_review_returns_404(self):
        r = self.client.post(
            '/api/manager/reviews/99999/moderate/', {'decision': 'approve'}, format='json'
        )
        self.assertEqual(r.status_code, 404)


class ProductManagerOrderTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.customer = Customer.objects.create_user(
            email='order@test.com', password='pass1234!', name='Order User'
        )
        self.product = Product.objects.create(
            name='Order Book', price=25.00, stock_quantity=10
        )

    def _order(self, status=Order.Status.PROCESSING):
        order = Order.objects.create(
            customer=self.customer,
            total_price=25.00,
            status=status,
            delivery_address='123 Delivery St',
        )
        OrderItem.objects.create(
            order=order, product=self.product,
            quantity=1, price_at_purchase=25.00
        )
        return order

    def test_manager_order_list_returns_all_orders(self):
        self._order()
        other = Customer.objects.create_user(
            email='other@test.com', password='pass1234!', name='Other'
        )
        Order.objects.create(
            customer=other, total_price=50.00,
            status=Order.Status.DELIVERED, delivery_address='456 Other St'
        )
        r = self.client.get('/api/manager/orders/')
        self.assertEqual(r.status_code, 200)
        self.assertGreaterEqual(len(r.data), 2)

    def test_delivery_update_to_in_transit(self):
        order = self._order(status=Order.Status.PROCESSING)
        r = self.client.patch(
            f'/api/manager/orders/{order.pk}/delivery/',
            {'status': 'in-transit'}, format='json'
        )
        self.assertEqual(r.status_code, 200)
        order.refresh_from_db()
        self.assertEqual(order.status, Order.Status.IN_TRANSIT)

    def test_delivery_update_to_delivered(self):
        order = self._order(status=Order.Status.IN_TRANSIT)
        r = self.client.patch(
            f'/api/manager/orders/{order.pk}/delivery/',
            {'status': 'delivered'}, format='json'
        )
        self.assertEqual(r.status_code, 200)
        order.refresh_from_db()
        self.assertEqual(order.status, Order.Status.DELIVERED)

    def test_delivery_update_invalid_status_returns_400(self):
        order = self._order()
        r = self.client.patch(
            f'/api/manager/orders/{order.pk}/delivery/',
            {'status': 'teleported'}, format='json'
        )
        self.assertEqual(r.status_code, 400)

    def test_delivery_update_on_refunded_order_fails(self):
        order = self._order(status=Order.Status.REFUNDED)
        r = self.client.patch(
            f'/api/manager/orders/{order.pk}/delivery/',
            {'status': 'delivered'}, format='json'
        )
        self.assertEqual(r.status_code, 400)
