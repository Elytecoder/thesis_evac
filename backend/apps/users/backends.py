"""
Custom authentication backend: authenticate by email + password.
Django still requires a username on the User model; we look up by email and use the stored username for authentication.
"""
from django.contrib.auth import get_user_model
from django.contrib.auth.backends import ModelBackend

User = get_user_model()


class EmailBackend(ModelBackend):
    """
    Authenticate using email and password.
    """
    def authenticate(self, request, username=None, password=None, **kwargs):
        # Support both username (for backward compat) and email from kwargs
        email = kwargs.get('email') or username
        if email is None or password is None:
            return None
        email = email.lower().strip()
        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            return None
        if user.check_password(password):
            return user
        return None
