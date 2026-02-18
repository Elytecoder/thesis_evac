"""MDRRMO-only permission for admin endpoints."""
from rest_framework import permissions


class IsMDRRMO(permissions.BasePermission):
    """Allow only users with role MDRRMO."""
    def has_permission(self, request, view):
        return request.user and request.user.is_authenticated and request.user.role == 'mdrrmo'
