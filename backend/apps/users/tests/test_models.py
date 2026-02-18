"""
Tests for user models.
"""
from django.test import TestCase
from apps.users.models import User


class UserModelTests(TestCase):
    """Test cases for User model."""

    def test_create_resident_user(self):
        """Test creating a resident user."""
        user = User.objects.create_user(
            username='resident1',
            password='testpass123',
            role=User.Role.RESIDENT,
        )
        self.assertEqual(user.username, 'resident1')
        self.assertEqual(user.role, User.Role.RESIDENT)
        self.assertTrue(user.is_active)
        self.assertTrue(user.check_password('testpass123'))

    def test_create_mdrrmo_user(self):
        """Test creating an MDRRMO user."""
        user = User.objects.create_user(
            username='mdrrmo1',
            password='testpass123',
            role=User.Role.MDRRMO,
        )
        self.assertEqual(user.username, 'mdrrmo1')
        self.assertEqual(user.role, User.Role.MDRRMO)

    def test_user_default_role(self):
        """Test that default role is RESIDENT."""
        user = User.objects.create_user(
            username='defaultuser',
            password='testpass123',
        )
        self.assertEqual(user.role, User.Role.RESIDENT)

    def test_user_default_is_active(self):
        """Test that users are active by default."""
        user = User.objects.create_user(
            username='activeuser',
            password='testpass123',
        )
        self.assertTrue(user.is_active)

    def test_user_str_representation(self):
        """Test string representation includes username and role."""
        user = User.objects.create_user(
            username='testuser',
            password='testpass123',
            role=User.Role.MDRRMO,
        )
        str_repr = str(user)
        self.assertIn('testuser', str_repr)
        self.assertIn('mdrrmo', str_repr.lower())

    def test_user_role_choices(self):
        """Test that both role choices work."""
        resident = User.objects.create_user(
            username='resident',
            password='pass123',
            role=User.Role.RESIDENT,
        )
        mdrrmo = User.objects.create_user(
            username='mdrrmo',
            password='pass123',
            role=User.Role.MDRRMO,
        )
        self.assertEqual(resident.role, 'resident')
        self.assertEqual(mdrrmo.role, 'mdrrmo')
