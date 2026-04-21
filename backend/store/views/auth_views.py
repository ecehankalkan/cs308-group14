from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenObtainPairView

from ..models import Customer
from ..serializers import RegisterSerializer, CustomerSerializer
from ..services.cart_service import CartBeforeLoginService


class RegisterView(generics.CreateAPIView):
    """POST /api/register/"""
    serializer_class   = RegisterSerializer
    permission_classes = [permissions.AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        customer = serializer.save()

        session_key = request.session.session_key
        CartBeforeLoginService.merge_guest_cart(session_key, customer)

        refresh  = RefreshToken.for_user(customer)
        return Response({
            'user':    CustomerSerializer(customer).data,
            'access':  str(refresh.access_token),
            'refresh': str(refresh),
        }, status=status.HTTP_201_CREATED)


class CustomTokenObtainPairView(TokenObtainPairView):
    """Custom login view to merge the cart after obtaining tokens."""
    def post(self, request, *args, **kwargs):
        response = super().post(request, *args, **kwargs)
        if response.status_code == status.HTTP_200_OK:
            serializer = self.get_serializer(data=request.data)
            if serializer.is_valid():
                session_key = request.session.session_key
                CartBeforeLoginService.merge_guest_cart(session_key, serializer.user)
        return response


class MeView(APIView):
    """GET /api/me/"""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        return Response(CustomerSerializer(request.user).data)
