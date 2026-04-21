from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.permissions import AllowAny
from store.services.invoice_service import process_mock_order_and_invoice

@api_view(['GET', 'POST'])
@permission_classes([AllowAny])
def test_invoice_email(request):
    """GET / POST /api/test-invoice/ — Triggers the SCRUM-54/55/56 mock logic"""
    email = request.GET.get('email', 'student@university.edu')
    if request.method == 'POST':
        email = request.data.get('email', email)
    result = process_mock_order_and_invoice(customer_email=email)
    return Response(result)
