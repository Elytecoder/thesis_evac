"""MDRRMO-only permission for admin endpoints."""
from rest_framework import permissions


class IsMDRRMO(permissions.BasePermission):
    """Allow only users with role MDRRMO."""
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        role = getattr(request.user, 'role', None)
        return str(role).lower() == 'mdrrmo'
