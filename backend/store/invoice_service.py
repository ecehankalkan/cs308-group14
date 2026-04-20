import io
from django.core.mail import EmailMessage
from django.utils import timezone
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import letter
from reportlab.lib import colors
from store.models import Product

def generate_invoice_pdf(order_data):
    """
    Generates a PDF invoice fully in-memory using ReportLab.
    """
    buffer = io.BytesIO()
    # Create the PDF object, using the buffer as its "file."
    p = canvas.Canvas(buffer, pagesize=letter)
    width, height = letter

    # Header
    p.setFont("Helvetica-Bold", 24)
    p.drawString(50, height - 80, "INVOICE")

    # Order Info
    p.setFont("Helvetica", 12)
    p.drawString(50, height - 120, f"Order ID: {order_data['id']}")
    p.drawString(50, height - 140, f"Date: {order_data['date']}")
    
    # Address
    p.drawString(50, height - 170, "Shipping Address:")
    p.setFont("Helvetica-Oblique", 12)
    p.drawString(50, height - 190, order_data['address'])

    # Table Header
    p.setFont("Helvetica-Bold", 12)
    y = height - 240
    p.drawString(50, y, "Product")
    p.drawString(350, y, "Qty")
    p.drawString(450, y, "Price")
    
    # Line separator
    p.setStrokeColor(colors.black)
    p.line(50, y-10, 500, y-10)

    # Products List
    p.setFont("Helvetica", 12)
    y -= 30
    for item in order_data['items']:
        p.drawString(50, y, item['product_name'])
        p.drawString(350, y, str(item['quantity']))
        p.drawString(450, y, f"${item['price']:.2f}")
        y -= 25

    # Total Price line
    p.line(50, y, 500, y)
    y -= 25
    p.setFont("Helvetica-Bold", 14)
    p.drawString(350, y, "Total:")
    p.drawString(450, y, f"${order_data['total_price']:.2f}")

    # Footer message
    p.setFont("Helvetica-Oblique", 10)
    p.drawString(50, 50, "Thank you for your business!")

    # Close and save the PDF object cleanly
    p.showPage()
    p.save()

    # Get the value of the BytesIO buffer and return it
    buffer.seek(0)
    return buffer.getvalue()

def process_mock_order_and_invoice(customer_email="test@example.com"):
    """
    Simulates completing checkout: Creates PDF, updates stock, sends email.
    """
    # 1. Create a dummy fake order dictionary to simulate checkout
    order_data = {
        "id": "INV-MOCK-999",
        "date": timezone.now().strftime("%B %d, %Y %I:%M %p"),
        "total_price": 50.00,
        "address": "123 University Campus, Collegeville, USA",
        "items": [
            {"product_name": "Physics Textbook", "price": 35.00, "quantity": 1},
            {"product_name": "Graphing Calculator", "price": 15.00, "quantity": 1}
        ]
    }
    
    # 2. Reduce Stock in real Database (SCRUM-56)
    products_reduced = []
    for item in order_data["items"]:
        # Let's see if this exact product exists in our DB, if not we skip
        # so this script doesn't crash before you guys seed your DB products.
        try:
            prod = Product.objects.filter(name__icontains=item["product_name"]).first()
            if prod and prod.stock_quantity >= item["quantity"]:
                prod.stock_quantity -= item["quantity"]
                prod.save()
                products_reduced.append(prod.name)
        except Exception:
            continue
            
    # 3. Generate the actual PDF Document (SCRUM-54 & 55)
    pdf_bytes = generate_invoice_pdf(order_data)
    
    # 4. Dispatch Email with PDF attachment (SCRUM-55 & 56)
    # This will print to terminal locally because of EMAIL_BACKEND setting
    email = EmailMessage(
        subject=f"Your Invoice for Order #{order_data['id']}",
        body="Hello! Thank you for your purchase. Please find your detailed invoice attached to this email.",
        from_email="billing@ourbookstore.com",
        to=[customer_email],
    )
    email.attach(f"invoice_{order_data['id']}.pdf", pdf_bytes, "application/pdf")
    email.send(fail_silently=False)
    
    return {
        "status": "success",
        "email_sent_to": customer_email,
        "products_stock_reduced": products_reduced
    }
