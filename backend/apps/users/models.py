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


class PasswordResetCode(models.Model):
    """
    One-time OTP for password reset.
    Codes expire after 10 minutes. Max 3 requests per 15 minutes (rate-limited).
    """
    EXPIRY_MINUTES = 10
    RATE_LIMIT_MAX = 3
    RATE_LIMIT_WINDOW_MINUTES = 15
    MAX_VERIFY_ATTEMPTS = 5

    email = models.EmailField()
    code = models.CharField(max_length=6)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    is_used = models.BooleanField(default=False)
    attempts_count = models.PositiveSmallIntegerField(default=0)

    class Meta:
        db_table = 'users_password_reset'
        ordering = ['-created_at']

    def __str__(self):
        return f"PasswordReset({self.email})"

    def is_expired(self):
        return timezone.now() > self.expires_at

    def is_attempts_exceeded(self):
        return self.attempts_count >= self.MAX_VERIFY_ATTEMPTS

    @classmethod
    def generate_code(cls):
        return ''.join(random.choices(string.digits, k=6))

    @classmethod
    def is_rate_limited(cls, email):
        """Return True if too many reset codes were created recently."""
        window_start = timezone.now() - timezone.timedelta(minutes=cls.RATE_LIMIT_WINDOW_MINUTES)
        recent_count = cls.objects.filter(email=email, created_at__gte=window_start).count()
        return recent_count >= cls.RATE_LIMIT_MAX

    @classmethod
    def create_reset(cls, email):
        """Create a fresh reset code; raises ValueError('rate_limited') when throttled.

        Uses UPDATE (mark used) instead of DELETE when invalidating the previous code
        so that the row is preserved for rate-limit counting within the 15-minute window.
        """
        if cls.is_rate_limited(email):
            raise ValueError('rate_limited')
        # Mark any live codes for this email as used (invalidates them without losing history)
        cls.objects.filter(email=email, is_used=False).update(is_used=True)
        code = cls.generate_code()
        expires_at = timezone.now() + timezone.timedelta(minutes=cls.EXPIRY_MINUTES)
        return cls.objects.create(email=email, code=code, expires_at=expires_at)

    @classmethod
    def check_code(cls, email, code):
        """
        Check a reset code WITHOUT consuming it (used by verify-reset-code step).
        Returns: 'valid' | 'expired' | 'invalid' | 'attempts_exceeded'
        Increments attempts_count on every call; invalidates after MAX_VERIFY_ATTEMPTS.
        """
        try:
            reset = cls.objects.filter(
                email=email, is_used=False,
            ).latest('created_at')
        except cls.DoesNotExist:
            return 'invalid'

        if reset.is_attempts_exceeded():
            return 'attempts_exceeded'
        if reset.is_expired():
            return 'expired'

        reset.attempts_count += 1
        reset.save(update_fields=['attempts_count'])

        if reset.code != code:
            return 'invalid'
        return 'valid'

    @classmethod
    def consume_code(cls, email, code):
        """
        Verify AND consume a reset code (used by reset-password step).
        Returns: ('valid', reset_obj) | ('expired', None) | ('invalid', None)
        """
        try:
            reset = cls.objects.filter(
                email=email, code=code, is_used=False,
            ).latest('created_at')
        except cls.DoesNotExist:
            return 'invalid', None

        if reset.is_expired():
            return 'expired', None

        reset.is_used = True
        reset.save(update_fields=['is_used'])
        return 'valid', reset


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
