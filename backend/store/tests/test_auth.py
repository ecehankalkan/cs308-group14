from django.test import TestCase
from rest_framework.test import APIClient
from store.models import Customer


class AuthTests(TestCase):
    def setUp(self):
        self.client = APIClient()

    def _customer(self, email='user@test.com', password='pass1234!', name='Test User'):
        return Customer.objects.create_user(email=email, password=password, name=name)

    def test_register_success(self):
        r = self.client.post('/api/register/', {
            'email': 'new@test.com', 'name': 'New User', 'password': 'pass1234!'
        })
        self.assertEqual(r.status_code, 201)
        self.assertIn('access', r.data)
        self.assertIn('refresh', r.data)

    def test_register_duplicate_email_returns_400(self):
        self._customer(email='dup@test.com')
        r = self.client.post('/api/register/', {
            'email': 'dup@test.com', 'name': 'Dup', 'password': 'pass1234!'
        })
        self.assertEqual(r.status_code, 400)

    def test_register_password_too_short_returns_400(self):
        r = self.client.post('/api/register/', {
            'email': 'short@test.com', 'name': 'Short', 'password': 'abc'
        })
        self.assertEqual(r.status_code, 400)

    def test_login_success(self):
        self._customer(email='login@test.com', password='pass1234!')
        r = self.client.post('/api/login/', {
            'email': 'login@test.com', 'password': 'pass1234!'
        })
        self.assertEqual(r.status_code, 200)
        self.assertIn('access', r.data)

    def test_login_wrong_password_returns_401(self):
        self._customer(email='wrong@test.com', password='pass1234!')
        r = self.client.post('/api/login/', {
            'email': 'wrong@test.com', 'password': 'badpass!!'
        })
        self.assertEqual(r.status_code, 401)

    def test_me_returns_user_data_when_authenticated(self):
        user = self._customer()
        self.client.force_authenticate(user=user)
        r = self.client.get('/api/me/')
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.data['email'], user.email)
        self.assertEqual(r.data['name'], user.name)

    def test_me_requires_authentication(self):
        r = self.client.get('/api/me/')
        self.assertEqual(r.status_code, 401)
