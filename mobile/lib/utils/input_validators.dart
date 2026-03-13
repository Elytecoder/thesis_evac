/// Input Validation Utilities
/// Provides reusable validation functions for forms across the app

class InputValidators {
  // ============================================================================
  // PHONE NUMBER VALIDATION
  // ============================================================================
  
  /// Validates Philippine mobile numbers
  /// Format: 09XXXXXXXXX (11 digits starting with 09)
  static String? validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }

    // Remove any whitespace
    final cleanValue = value.replaceAll(RegExp(r'\s+'), '');

    // Check if it contains only digits
    if (!RegExp(r'^[0-9]+$').hasMatch(cleanValue)) {
      return 'Phone number must contain only digits';
    }

    // Check length
    if (cleanValue.length != 11) {
      return 'Phone number must be exactly 11 digits';
    }

    // Check if starts with 09
    if (!cleanValue.startsWith('09')) {
      return 'Please enter a valid Philippine mobile number (11 digits starting with 09)';
    }

    return null; // Valid
  }

  /// Formats phone number input (for TextInputFormatter)
  static String formatPhoneNumber(String value) {
    // Remove non-digits
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Limit to 11 digits
    if (digits.length > 11) {
      return digits.substring(0, 11);
    }
    
    return digits;
  }

  // ============================================================================
  // NAME VALIDATION
  // ============================================================================
  
  /// Validates names (letters, spaces, hyphens only)
  static String? validateName(String? value, {String fieldName = 'Name'}) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }

    // Check for valid characters (letters, spaces, hyphens)
    if (!RegExp(r'^[a-zA-Z\s\-]+$').hasMatch(value)) {
      return '$fieldName can only contain letters, spaces, and hyphens';
    }

    // Check minimum length
    if (value.trim().length < 2) {
      return '$fieldName must be at least 2 characters';
    }

    // Check maximum length
    if (value.length > 50) {
      return '$fieldName must not exceed 50 characters';
    }

    return null; // Valid
  }

  /// Formats name input (for TextInputFormatter)
  static String formatName(String value) {
    // Remove invalid characters (keep only letters, spaces, hyphens)
    return value.replaceAll(RegExp(r'[^a-zA-Z\s\-]'), '');
  }

  // ============================================================================
  // ADDRESS VALIDATION
  // ============================================================================
  
  /// Validates street address
  static String? validateStreetAddress(String? value) {
    if (value == null || value.isEmpty) {
      return 'Street address is required';
    }

    // Allow letters, numbers, spaces, hyphens, commas, periods
    if (!RegExp(r'^[a-zA-Z0-9\s\-,\.]+$').hasMatch(value)) {
      return 'Address contains invalid characters';
    }

    // Check minimum length
    if (value.trim().length < 5) {
      return 'Address must be at least 5 characters';
    }

    // Check maximum length
    if (value.length > 100) {
      return 'Address must not exceed 100 characters';
    }

    return null; // Valid
  }

  /// Formats street address input
  static String formatStreetAddress(String value) {
    // Remove invalid characters
    final formatted = value.replaceAll(RegExp(r'[^a-zA-Z0-9\s\-,\.]'), '');
    
    // Limit to 100 characters
    if (formatted.length > 100) {
      return formatted.substring(0, 100);
    }
    
    return formatted;
  }

  // ============================================================================
  // DESCRIPTION VALIDATION
  // ============================================================================
  
  /// Validates report descriptions
  static String? validateDescription(String? value, {
    int minLength = 10,
    int maxLength = 500,
  }) {
    if (value == null || value.isEmpty) {
      return 'Description is required';
    }

    final trimmedValue = value.trim();

    // Check minimum length
    if (trimmedValue.length < minLength) {
      return 'Description must contain at least $minLength characters';
    }

    // Check maximum length
    if (trimmedValue.length > maxLength) {
      return 'Description must not exceed $maxLength characters';
    }

    return null; // Valid
  }

  /// Returns character count message for description fields
  static String getCharacterCountMessage(String value, {int maxLength = 500}) {
    final length = value.length;
    final remaining = maxLength - length;
    
    if (remaining < 0) {
      return 'Exceeded by ${-remaining} characters';
    } else if (remaining < 50) {
      return '$remaining characters remaining';
    }
    
    return '$length / $maxLength characters';
  }

  // ============================================================================
  // NUMERIC VALIDATION
  // ============================================================================
  
  /// Validates positive integers (for capacity, count fields)
  static String? validatePositiveInteger(String? value, {
    String fieldName = 'Value',
    int? maxValue,
    bool required = true,
  }) {
    if (value == null || value.isEmpty) {
      if (required) {
        return '$fieldName is required';
      }
      return null;
    }

    // Check if it's a valid integer
    final intValue = int.tryParse(value);
    if (intValue == null) {
      return '$fieldName must be a valid number';
    }

    // Check if positive
    if (intValue < 0) {
      return '$fieldName cannot be negative';
    }

    // Check if zero
    if (intValue == 0) {
      return '$fieldName must be greater than zero';
    }

    // Check maximum value
    if (maxValue != null && intValue > maxValue) {
      return '$fieldName cannot exceed $maxValue';
    }

    return null; // Valid
  }

  /// Formats numeric input
  static String formatPositiveInteger(String value, {int? maxValue}) {
    // Remove non-digits
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (digits.isEmpty) return '';
    
    final intValue = int.tryParse(digits);
    if (intValue == null) return '';
    
    // Apply max value constraint
    if (maxValue != null && intValue > maxValue) {
      return maxValue.toString();
    }
    
    return digits;
  }

  // ============================================================================
  // EMAIL VALIDATION
  // ============================================================================
  
  /// Validates email addresses
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }

    // Basic email regex
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }

    return null; // Valid
  }

  // ============================================================================
  // COORDINATE VALIDATION
  // ============================================================================
  
  /// Validates latitude values
  static String? validateLatitude(String? value) {
    if (value == null || value.isEmpty) {
      return 'Latitude is required';
    }

    final doubleValue = double.tryParse(value);
    if (doubleValue == null) {
      return 'Invalid latitude format';
    }

    // Philippines latitude range: approximately 4°N to 21°N
    if (doubleValue < 4.0 || doubleValue > 21.0) {
      return 'Latitude must be within Philippines (4° to 21°)';
    }

    return null; // Valid
  }

  /// Validates longitude values
  static String? validateLongitude(String? value) {
    if (value == null || value.isEmpty) {
      return 'Longitude is required';
    }

    final doubleValue = double.tryParse(value);
    if (doubleValue == null) {
      return 'Invalid longitude format';
    }

    // Philippines longitude range: approximately 116°E to 127°E
    if (doubleValue < 116.0 || doubleValue > 127.0) {
      return 'Longitude must be within Philippines (116° to 127°)';
    }

    return null; // Valid
  }

  // ============================================================================
  // DROPDOWN VALIDATION
  // ============================================================================
  
  /// Validates dropdown selections
  static String? validateDropdown(String? value, {String fieldName = 'Field'}) {
    if (value == null || value.isEmpty || value == 'Select') {
      return 'Please select a $fieldName';
    }
    return null; // Valid
  }
}
