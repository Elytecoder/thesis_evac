"""
User model for residents and MDRRMO personnel.
"""
from django.contrib.auth.models import AbstractUser
from django.db import models


class User(AbstractUser):
    """
    Custom user with role: resident or mdrrmo.
    Used for authentication and report ownership.
    """
    class Role(models.TextChoices):
        RESIDENT = 'resident', 'Resident'
        MDRRMO = 'mdrrmo', 'MDRRMO'

    role = models.CharField(
        max_length=20,
        choices=Role.choices,
        default=Role.RESIDENT,
    )
    is_active = models.BooleanField(default=True)

    class Meta:
        db_table = 'users_user'

    def __str__(self):
        return f"{self.username} ({self.role})"
