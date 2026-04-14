"""
User model for residents and MDRRMO personnel.
"""
from django.contrib.auth.models import AbstractUser
from django.db import models
from django.utils import timezone
import random
import string


class User(AbstractUser):
    """
    Custom user with role: resident or mdrrmo.
    Authentication uses email; username is auto-generated from email for Django internals.
    """
    class Role(models.TextChoices):
        RESIDENT = 'resident', 'Resident'
        MDRRMO = 'mdrrmo', 'MDRRMO'

    # Email is the login identifier (uniqueness enforced in registration API)
    role = models.CharField(
        max_length=20,
        choices=Role.choices,
        default=Role.RESIDENT,
    )
    
    # Profile information
    full_name = models.CharField(max_length=255, blank=True)
    phone_number = models.CharField(max_length=15, blank=True)
    
    # Address fields (structured)
    province = models.CharField(max_length=100, blank=True)
    municipality = models.CharField(max_length=100, blank=True)
    barangay = models.CharField(max_length=100, blank=True)
    street = models.CharField(max_length=255, blank=True)  # Optional
    
    profile_picture = models.URLField(blank=True)
    
    # Account status
    is_active = models.BooleanField(default=False)  # Inactive until email verified
    is_suspended = models.BooleanField(default=False)
    suspended_at = models.DateTimeField(null=True, blank=True)
    
    # Email verification
    email_verified = models.BooleanField(default=False)
    email_verified_at = models.DateTimeField(null=True, blank=True)

    # Non-sequential public ID for MDRRMO display (6 digits, unique). DB pk unchanged.
    public_display_id = models.PositiveIntegerField(unique=True)

    class Meta:
        db_table = 'users_user'
        indexes = [
            models.Index(fields=['email'], name='users_user_email_idx'),
        ]

    def __str__(self):
        return f"{self.username} ({self.role})"

    def save(self, *args, **kwargs):
        if self.barangay:
            from apps.users.barangay_utils import normalize_barangay_label

            self.barangay = normalize_barangay_label(self.barangay)
        if self.public_display_id is None:
            from apps.users.utils_codes import allocate_unique_six_digit

            self.public_display_id = allocate_unique_six_digit(
                self.__class__,
                'public_display_id',
            )
        super().save(*args, **kwargs)
    
    def suspend(self):
        """Suspend user account."""
        from django.utils import timezone
        self.is_suspended = True
        self.suspended_at = timezone.now()
        self.save()
    
    def activate(self):
        """Activate suspended user account."""
        self.is_suspended = False
        self.suspended_at = None
        self.save()


class EmailVerificationCode(models.Model):
    """
    Email verification codes for user registration.
    Codes expire after 5 minutes.
    """
    email = models.EmailField()
    code = models.CharField(max_length=6)
    created_at = models.DateTimeField(auto_now_add=True)
    is_used = models.BooleanField(default=False)
    
    class Meta:
        db_table = 'users_email_verification'
        ordering = ['-created_at']
    
    def __str__(self):
        return f"{self.email} - {self.code}"
    
    def is_expired(self):
        """Check if code is expired (5 minutes)."""
        expiry_time = self.created_at + timezone.timedelta(minutes=5)
        return timezone.now() > expiry_time
    
    @classmethod
    def generate_code(cls):
        """Generate a random 6-digit verification code."""
        return ''.join(random.choices(string.digits, k=6))
    
    @classmethod
    def create_verification(cls, email):
        """Create a new verification code for an email."""
        # Delete any existing unused codes for this email
        cls.objects.filter(email=email, is_used=False).delete()
        
        code = cls.generate_code()
        return cls.objects.create(email=email, code=code)
    
    @classmethod
    def verify_code(cls, email, code):
        """
        Verify a code for an email.

        Returns one of:
          'valid'   – code is correct and has been marked used
          'expired' – code exists but is past the 5-minute window
          'invalid' – no matching unused code found (wrong code or already used)
        """
        try:
            verification = cls.objects.filter(
                email=email,
                code=code,
                is_used=False
            ).latest('created_at')

            if verification.is_expired():
                return 'expired'

            verification.is_used = True
            verification.save()
            return 'valid'
        except cls.DoesNotExist:
            return 'invalid'
