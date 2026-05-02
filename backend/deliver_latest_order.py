import os
import django

# Setup Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from store.models import Order

def deliver_latest():
    latest_order = Order.objects.last()
    if not latest_order:
        print("❌ No orders found in the database.")
        return
        
    latest_order.status = Order.Status.DELIVERED
    latest_order.save(update_fields=['status'])
    print(f"✅ Success! Order #{latest_order.id} has been marked as DELIVERED.")

if __name__ == '__main__':
    deliver_latest()
