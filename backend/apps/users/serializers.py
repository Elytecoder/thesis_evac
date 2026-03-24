"""
User serializers for authentication and profile management.
"""
from rest_framework import serializers
from django.contrib.auth import get_user_model
import re

User = get_user_model()


class UserSerializer(serializers.ModelSerializer):
    """Basic user serializer for profile display."""
    
    class Meta:
        model = User
        fields = [
            'id', 'username', 'email', 'full_name', 'phone_number',
            'province', 'municipality', 'barangay', 'street',
            'role', 'is_active', 'is_suspended', 'profile_picture',
            'email_verified', 'date_joined'
        ]
        read_only_fields = ['id', 'username', 'date_joined', 'role', 'email_verified']


class MdrrmoUserListSerializer(serializers.ModelSerializer):
    """
    MDRRMO user management list/detail shape.
    `user_id` = public_display_id (6-digit reference); `id` = DB pk for suspend/delete URLs.
    """

    user_id = serializers.IntegerField(source='public_display_id', read_only=True)

    class Meta:
        model = User
        fields = [
            'id',
            'user_id',
            'username',
            'email',
            'full_name',
            'phone_number',
            'province',
            'municipality',
            'barangay',
            'street',
            'role',
            'is_active',
            'is_suspended',
            'profile_picture',
            'email_verified',
            'date_joined',
        ]
        read_only_fields = [
            'id',
            'user_id',
            'username',
            'email',
            'full_name',
            'phone_number',
            'province',
            'municipality',
            'barangay',
            'street',
            'role',
            'is_active',
            'is_suspended',
            'profile_picture',
            'email_verified',
            'date_joined',
        ]


class UserRegistrationSerializer(serializers.ModelSerializer):
    """Serializer for user registration with email verification."""
    password = serializers.CharField(write_only=True, min_length=8)
    password_confirm = serializers.CharField(write_only=True, min_length=8)
    verification_code = serializers.CharField(write_only=True, max_length=6, min_length=6)
    
    class Meta:
        model = User
        fields = [
            'email', 'password', 'password_confirm', 'verification_code',
            'full_name', 'phone_number',
            'province', 'municipality', 'barangay', 'street'
        ]
    
    def validate_email(self, value):
        """Validate email format and uniqueness."""
        value = value.lower().strip()
        
        # Check if email already exists
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError("Email is already registered")
        
        # Basic email format validation
        email_regex = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        if not re.match(email_regex, value):
            raise serializers.ValidationError("Enter a valid email address")
        
        return value
    
    def validate_full_name(self, value):
        """Validate full name: letters, spaces, hyphens only."""
        value = value.strip()
        
        if len(value) < 2:
            raise serializers.ValidationError("Name must be at least 2 characters")
        
        if len(value) > 60:
            raise serializers.ValidationError("Name must not exceed 60 characters")
        
        # Allow letters, spaces, hyphens, and common Filipino characters
        name_regex = r'^[a-zA-ZñÑáéíóúÁÉÍÓÚ\s\-]+$'
        if not re.match(name_regex, value):
            raise serializers.ValidationError("Please enter a valid name using letters only")
        
        return value
    
    def validate_phone_number(self, value):
        """Validate Philippine mobile number format."""
        value = value.strip()
        
        # Must be exactly 11 digits
        if not value.isdigit():
            raise serializers.ValidationError("Phone number must contain only digits")
        
        if len(value) != 11:
            raise serializers.ValidationError("Enter a valid 11-digit Philippine mobile number")
        
        if not value.startswith('09'):
            raise serializers.ValidationError("Phone number must start with 09")
        
        return value
    
    def validate_password(self, value):
        """Validate password strength."""
        if len(value) < 8:
            raise serializers.ValidationError("Password must be at least 8 characters")
        
        # Check for uppercase
        if not re.search(r'[A-Z]', value):
            raise serializers.ValidationError(
                "Password must contain at least one uppercase letter"
            )
        
        # Check for lowercase
        if not re.search(r'[a-z]', value):
            raise serializers.ValidationError(
                "Password must contain at least one lowercase letter"
            )
        
        # Check for digit
        if not re.search(r'\d', value):
            raise serializers.ValidationError(
                "Password must contain at least one number"
            )
        
        return value
    
    def validate_province(self, value):
        """Validate province is not empty."""
        if not value or not value.strip():
            raise serializers.ValidationError("Province is required")
        return value.strip()
    
    def validate_municipality(self, value):
        """Validate municipality is not empty."""
        if not value or not value.strip():
            raise serializers.ValidationError("Municipality is required")
        return value.strip()
    
    def validate_barangay(self, value):
        """Validate barangay is not empty."""
        if not value or not value.strip():
            raise serializers.ValidationError("Barangay is required")
        from apps.users.barangay_utils import normalize_barangay_label

        return normalize_barangay_label(value.strip())
    
    def validate(self, data):
        """Cross-field validation."""
        # Check passwords match
        if data['password'] != data['password_confirm']:
            raise serializers.ValidationError({"password_confirm": "Passwords do not match"})
        
        # Verify email verification code
        from apps.users.models import EmailVerificationCode
        email = data.get('email')
        code = data.get('verification_code')
        
        if not EmailVerificationCode.verify_code(email, code):
            raise serializers.ValidationError({
                "verification_code": "Invalid or expired verification code"
            })
        
        return data
    
    def create(self, validated_data):
        """Create user with verified email."""
        from django.utils import timezone
        
        validated_data.pop('password_confirm')
        validated_data.pop('verification_code')
        password = validated_data.pop('password')
        
        # Generate username from email
        email = validated_data['email']
        base_username = email.split('@')[0]
        username = base_username
        counter = 1
        while User.objects.filter(username=username).exists():
            username = f"{base_username}{counter}"
            counter += 1
        
        validated_data['username'] = username
        validated_data['email_verified'] = True
        validated_data['email_verified_at'] = timezone.now()
        validated_data['is_active'] = True  # Activate after email verification
        
        user = User.objects.create_user(**validated_data)
        user.set_password(password)
        user.save()
        return user


class UserLoginSerializer(serializers.Serializer):
    """Serializer for user login (email + password)."""
    email = serializers.EmailField(write_only=True)
    password = serializers.CharField(write_only=True)


class UserProfileUpdateSerializer(serializers.ModelSerializer):
    """Serializer for updating user profile. Only phone_number and street are editable (email requires re-verification)."""
    
    class Meta:
        model = User
        fields = ['phone_number', 'street']


class PasswordChangeSerializer(serializers.Serializer):
    """Serializer for password change."""
    old_password = serializers.CharField(write_only=True)
    new_password = serializers.CharField(write_only=True, min_length=6)
    new_password_confirm = serializers.CharField(write_only=True, min_length=6)
    
    def validate(self, data):
        if data['new_password'] != data['new_password_confirm']:
            raise serializers.ValidationError("New passwords do not match")
        return data


class DeleteAccountSerializer(serializers.Serializer):
    """Resident self-delete: confirm with current password."""
    password = serializers.CharField(write_only=True)
