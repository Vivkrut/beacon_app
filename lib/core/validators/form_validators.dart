/// Form validation utilities for Beacon SOS
class FormValidators {
  /// Validate contact name
  /// Rules: 2-50 characters, no numeric digits allowed
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name is required';
    }
    if (value.length < 2 || value.length > 50) {
      return 'Name must be 2-50 characters';
    }
    if (value.contains(RegExp(r'\d'))) {
      return 'Name must not contain numbers';
    }
    return null;
  }

  /// Validate phone number
  /// Supports:
  /// - Indian: +91XXXXXXXXXX (10 digits)
  /// - International: +[1-999] with 7-15 digits
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }

    // Indian format: +91XXXXXXXXXX
    if (RegExp(r'^\+91\d{10}$').hasMatch(value)) {
      return null;
    }

    // International format: +[1-3 digits][7-15 digits]
    if (RegExp(r'^\+\d{1,3}\d{7,15}$').hasMatch(value)) {
      return null;
    }

    return 'Invalid phone format. Use +91XXXXXXXXXX (India) or +[code][number]';
  }

  /// Validate email address
  /// Rules: Optional field, validates if provided
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Email is optional
    }

    // Simple RFC 5322 pattern
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value)) {
      return 'Invalid email address';
    }

    return null;
  }
}
