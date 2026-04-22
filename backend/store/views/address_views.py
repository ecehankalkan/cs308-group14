from rest_framework import generics, permissions, status
from rest_framework.response import Response

from ..models import DeliveryAddress, PaymentCard
from ..serializers import DeliveryAddressSerializer, PaymentCardSerializer


class DeliveryAddressListView(generics.ListCreateAPIView):
    """GET / POST /api/addresses/"""
    serializer_class = DeliveryAddressSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return DeliveryAddress.objects.filter(customer=self.request.user)

    def perform_create(self, serializer):
        address = serializer.save(customer=self.request.user)
        
        if address.is_default or not DeliveryAddress.objects.filter(customer=self.request.user).exclude(id=address.id).exists():
            DeliveryAddress.objects.filter(customer=self.request.user).exclude(id=address.id).update(is_default=False)
            address.is_default = True
            address.save()


class DeliveryAddressDetailView(generics.RetrieveUpdateDestroyAPIView):
    """GET / PATCH / DELETE /api/addresses/<id>/"""
    serializer_class = DeliveryAddressSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return DeliveryAddress.objects.filter(customer=self.request.user)

    def perform_update(self, serializer):
        address = serializer.save()
        if address.is_default:
            DeliveryAddress.objects.filter(customer=self.request.user).exclude(id=address.id).update(is_default=False)


class PaymentCardListView(generics.ListCreateAPIView):
    """
    GET / POST /api/payment-cards/
    
    WARNING: Stores FAKE card data for testing only.
    NEVER use in production with real cards.
    """
    serializer_class = PaymentCardSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return PaymentCard.objects.filter(customer=self.request.user)

    def perform_create(self, serializer):
        card = serializer.save(customer=self.request.user)
        
        if card.is_default or not PaymentCard.objects.filter(customer=self.request.user).exclude(id=card.id).exists():
            PaymentCard.objects.filter(customer=self.request.user).exclude(id=card.id).update(is_default=False)
            card.is_default = True
            card.save()


class PaymentCardDetailView(generics.RetrieveUpdateDestroyAPIView):
    """GET / PATCH / DELETE /api/payment-cards/<id>/"""
    serializer_class = PaymentCardSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return PaymentCard.objects.filter(customer=self.request.user)

    def perform_update(self, serializer):
        card = serializer.save()
        if card.is_default:
            PaymentCard.objects.filter(customer=self.request.user).exclude(id=card.id).update(is_default=False)
