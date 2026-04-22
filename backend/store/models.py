from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
from django.core.validators import MinValueValidator, MaxValueValidator
from django.db import models


# ---------------------------------------------------------------------------
# Custom User / Customer
# ---------------------------------------------------------------------------

class CustomerManager(BaseUserManager):
    def create_user(self, email, password=None, **extra_fields):
        if not email:
            raise ValueError('Email is required')
        email = self.normalize_email(email)
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('role', Customer.Role.CUSTOMER)
        return self.create_user(email, password, **extra_fields)


class Customer(AbstractBaseUser, PermissionsMixin):
    class Role(models.TextChoices):
        CUSTOMER        = 'customer',        'Customer'
        SALES_MANAGER   = 'sales_manager',   'Sales Manager'
        PRODUCT_MANAGER = 'product_manager', 'Product Manager'

    name         = models.CharField(max_length=255)
    email        = models.EmailField(unique=True, db_index=True)
    tax_id       = models.CharField(max_length=50, blank=True)
    home_address = models.TextField(blank=True)
    role         = models.CharField(max_length=20, choices=Role.choices, default=Role.CUSTOMER)
    firebase_uid = models.CharField(max_length=128, blank=True, db_index=True)
    is_active    = models.BooleanField(default=True)
    is_staff     = models.BooleanField(default=False)
    created_at   = models.DateTimeField(auto_now_add=True)

    USERNAME_FIELD  = 'email'
    REQUIRED_FIELDS = ['name']

    objects = CustomerManager()

    class Meta:
        indexes = [models.Index(fields=['role'])]

    def __str__(self):
        return f'{self.name} <{self.email}>'


# ---------------------------------------------------------------------------
# Category
# ---------------------------------------------------------------------------

class Category(models.Model):
    name        = models.CharField(max_length=100, unique=True)
    description = models.TextField(blank=True)

    class Meta:
        verbose_name_plural = 'categories'

    def __str__(self):
        return self.name


# ---------------------------------------------------------------------------
# Product
# ---------------------------------------------------------------------------

class Product(models.Model):
    name              = models.CharField(max_length=255, db_index=True)
    model             = models.CharField(max_length=255, blank=True)
    serial_number     = models.CharField(max_length=100, unique=True, blank=True)
    description       = models.TextField(blank=True)
    stock_quantity    = models.PositiveIntegerField(default=0)
    price             = models.DecimalField(max_digits=10, decimal_places=2, validators=[MinValueValidator(0)])
    discounted_price  = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True, validators=[MinValueValidator(0)])
    warranty_status   = models.BooleanField(default=False)
    distributor_info  = models.CharField(max_length=255, blank=True)
    category          = models.ForeignKey(Category, on_delete=models.SET_NULL, null=True, blank=True, related_name='products')
    popularity_score  = models.FloatField(default=0.0, db_index=True)

    class Meta:
        indexes = [
            models.Index(fields=['category']),
            models.Index(fields=['price']),
        ]

    def effective_price(self):
        return self.discounted_price if self.discounted_price is not None else self.price

    def __str__(self):
        return self.name


# ---------------------------------------------------------------------------
# Order
# ---------------------------------------------------------------------------

class Order(models.Model):
    class Status(models.TextChoices):
        PROCESSING = 'processing', 'Processing'
        IN_TRANSIT = 'in-transit', 'In Transit'
        DELIVERED  = 'delivered',  'Delivered'

    customer         = models.ForeignKey(Customer, on_delete=models.PROTECT, related_name='orders')
    total_price      = models.DecimalField(max_digits=12, decimal_places=2, validators=[MinValueValidator(0)])
    status           = models.CharField(max_length=20, choices=Status.choices, default=Status.PROCESSING, db_index=True)
    delivery_address = models.TextField()
    created_at       = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        indexes = [models.Index(fields=['customer', 'status'])]

    def __str__(self):
        return f'Order #{self.pk} — {self.customer.email}'


class OrderItem(models.Model):
    order             = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='items')
    product           = models.ForeignKey(Product, on_delete=models.PROTECT, related_name='order_items')
    quantity          = models.PositiveIntegerField(default=1)
    price_at_purchase = models.DecimalField(max_digits=10, decimal_places=2, validators=[MinValueValidator(0)])

    class Meta:
        indexes = [models.Index(fields=['order', 'product'])]

    def __str__(self):
        return f'{self.product.name} x{self.quantity} (Order #{self.order_id})'


# ---------------------------------------------------------------------------
# Cart
# ---------------------------------------------------------------------------

class Cart(models.Model):
    customer = models.ForeignKey(Customer, on_delete=models.CASCADE, related_name='cart_items', null=True, blank=True)
    session_key = models.CharField(max_length=40, null=True, blank=True, db_index=True)
    product  = models.ForeignKey(Product, on_delete=models.CASCADE, related_name='cart_entries')
    quantity = models.PositiveIntegerField(default=1)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=['customer', 'product'],
                condition=models.Q(customer__isnull=False),
                name='unique_customer_product'
            ),
            models.UniqueConstraint(
                fields=['session_key', 'product'],
                condition=models.Q(session_key__isnull=False),
                name='unique_session_product'
            ),
        ]
        indexes = [
            models.Index(fields=['customer']),
            models.Index(fields=['session_key']),
        ]

    def __str__(self):
        owner = self.customer.name if self.customer else f"Guest ({self.session_key})"
        return f'{owner} — {self.product.name} x{self.quantity}'


# ---------------------------------------------------------------------------
# Delivery Address
# ---------------------------------------------------------------------------

class DeliveryAddress(models.Model):
    customer       = models.ForeignKey(Customer, on_delete=models.CASCADE, related_name='delivery_addresses')
    label          = models.CharField(max_length=50, blank=True, default='')  # e.g., "Home", "Work", "School"
    recipient_name = models.CharField(max_length=255)
    street         = models.CharField(max_length=255)
    city           = models.CharField(max_length=100)
    zip_code       = models.CharField(max_length=20)
    country        = models.CharField(max_length=100)
    is_default     = models.BooleanField(default=False)
    created_at     = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [models.Index(fields=['customer'])]

    def __str__(self):
        label_prefix = f"[{self.label}] " if self.label else ""
        return f'{label_prefix}{self.recipient_name} — {self.street}, {self.city}'


# ---------------------------------------------------------------------------
# Payment Card (MOCK DATA FOR TESTING ONLY - NEVER USE IN PRODUCTION)
# ---------------------------------------------------------------------------

class PaymentCard(models.Model):
    """
    WARNING: This stores fake/test credit card data for demo purposes only.
    NEVER store real credit card numbers in production.
    Use payment processors like Stripe/PayPal instead.
    """
    customer      = models.ForeignKey(Customer, on_delete=models.CASCADE, related_name='payment_cards')
    label         = models.CharField(max_length=50, blank=True, default='')  # e.g., "Personal", "Business"
    card_number   = models.CharField(max_length=19)  # MOCK DATA ONLY
    holder_name   = models.CharField(max_length=255)
    expiry_date   = models.CharField(max_length=7)  # Format: MM/YYYY
    is_default    = models.BooleanField(default=False)
    created_at    = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [models.Index(fields=['customer'])]

    def __str__(self):
        label_prefix = f"[{self.label}] " if self.label else ""
        return f'{label_prefix}{self.holder_name} — **** **** **** {self.card_number[-4:]}'
