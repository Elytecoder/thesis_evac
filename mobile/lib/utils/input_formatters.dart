import 'package:flutter/services.dart';

/// Custom TextInputFormatters for various input types

/// Phone number input formatter
/// - Only allows digits
/// - Limits to 11 digits
class PhoneNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove all non-digit characters
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Limit to 11 digits
    final limitedDigits = digitsOnly.length > 11 
        ? digitsOnly.substring(0, 11) 
        : digitsOnly;

    return TextEditingValue(
      text: limitedDigits,
      selection: TextSelection.collapsed(offset: limitedDigits.length),
    );
  }
}

/// Name input formatter
/// - Only allows letters, spaces, and hyphens
class NameInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove invalid characters
    final validText = newValue.text.replaceAll(RegExp(r'[^a-zA-Z\s\-]'), '');
    
    // Limit to 50 characters
    final limitedText = validText.length > 50 
        ? validText.substring(0, 50) 
        : validText;

    return TextEditingValue(
      text: limitedText,
      selection: TextSelection.collapsed(offset: limitedText.length),
    );
  }
}

/// Street address input formatter
/// - Allows letters, numbers, spaces, hyphens, commas, periods
/// - Limits to 100 characters
class StreetAddressInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove invalid characters
    final validText = newValue.text.replaceAll(
      RegExp(r'[^a-zA-Z0-9\s\-,\.]'),
      '',
    );
    
    // Limit to 100 characters
    final limitedText = validText.length > 100 
        ? validText.substring(0, 100) 
        : validText;

    return TextEditingValue(
      text: limitedText,
      selection: TextSelection.collapsed(offset: limitedText.length),
    );
  }
}

/// Description input formatter
/// - Limits to specified maximum length (default 500)
class DescriptionInputFormatter extends TextInputFormatter {
  final int maxLength;

  DescriptionInputFormatter({this.maxLength = 500});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length > maxLength) {
      return oldValue;
    }
    return newValue;
  }
}

/// Positive integer input formatter
/// - Only allows digits
/// - No leading zeros (except for zero itself)
/// - Optional maximum value
class PositiveIntegerInputFormatter extends TextInputFormatter {
  final int? maxValue;

  PositiveIntegerInputFormatter({this.maxValue});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove all non-digit characters
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Parse value
    final intValue = int.tryParse(digitsOnly);
    if (intValue == null) {
      return oldValue;
    }

    // Check max value constraint
    if (maxValue != null && intValue > maxValue!) {
      return oldValue;
    }

    // Remove leading zeros (except for "0")
    final formattedText = intValue.toString();

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}

/// Decimal number input formatter (for coordinates)
/// - Allows digits, decimal point, and negative sign
class DecimalInputFormatter extends TextInputFormatter {
  final int decimalPlaces;

  DecimalInputFormatter({this.decimalPlaces = 6});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Allow digits, decimal point, and negative sign
    final validText = newValue.text.replaceAll(
      RegExp(r'[^0-9\.\-]'),
      '',
    );

    // Ensure only one decimal point
    final parts = validText.split('.');
    if (parts.length > 2) {
      return oldValue;
    }

    // Ensure negative sign is only at the start
    if (validText.contains('-') && !validText.startsWith('-')) {
      return oldValue;
    }

    // Limit decimal places
    if (parts.length == 2 && parts[1].length > decimalPlaces) {
      return oldValue;
    }

    return TextEditingValue(
      text: validText,
      selection: TextSelection.collapsed(offset: validText.length),
    );
  }
}
