from django.conf import settings

class SessionHeaderMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        custom_session_id = request.META.get('HTTP_X_SESSION_ID')
        if custom_session_id:
            request.COOKIES[settings.SESSION_COOKIE_NAME] = custom_session_id

        response = self.get_response(request)
        if hasattr(request, 'session') and request.session.session_key:
            response['X-Session-Id'] = request.session.session_key
        return response
