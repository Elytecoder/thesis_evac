import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../features/authentication/auth_service.dart';
import '../../models/user.dart';
import '../../data/philippine_address_data.dart';
import 'map_screen.dart';

/// Registration screen with real Gmail SMTP email verification.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  // Form controllers
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _streetController = TextEditingController();
  final _verificationCodeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Address dropdowns
  String? _selectedProvince;
  String? _selectedMunicipality;
  String? _selectedBarangay;

  List<String> _municipalities = [];
  List<String> _barangays = [];

  // State management
  bool _isLoading = false;
  bool _isSendingCode = false;
  bool _codeSent = false;
  bool _isVerified = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Password strength
  String _passwordStrength = '';
  Color _passwordStrengthColor = Colors.grey;

  // ── Email verification timers ──────────────────────────────────────────────
  /// Counts DOWN from 300 s (5 min) while the code is still valid.
  int _expirySecondsLeft = 0;
  Timer? _expiryTimer;

  /// Resend cooldown: user must wait 60 s before requesting a new code.
  int _resendCooldownLeft = 0;
  Timer? _resendCooldownTimer;
  // ──────────────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _verificationCodeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _expiryTimer?.cancel();
    _resendCooldownTimer?.cancel();
    super.dispose();
  }

  // ── Timer helpers ──────────────────────────────────────────────────────────

  void _startExpiryTimer() {
    _expiryTimer?.cancel();
    setState(() => _expirySecondsLeft = 5 * 60); // 5 minutes
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_expirySecondsLeft > 0) {
          _expirySecondsLeft--;
        } else {
          _expiryTimer?.cancel();
        }
      });
    });
  }

  void _startResendCooldown() {
    _resendCooldownTimer?.cancel();
    setState(() => _resendCooldownLeft = 60);
    _resendCooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_resendCooldownLeft > 0) {
          _resendCooldownLeft--;
        } else {
          _resendCooldownTimer?.cancel();
        }
      });
    });
  }

  String get _expiryLabel {
    if (_expirySecondsLeft <= 0) return 'Code expired — request a new one';
    final m = _expirySecondsLeft ~/ 60;
    final s = _expirySecondsLeft % 60;
    return 'Code expires in ${m}m ${s.toString().padLeft(2, '0')}s';
  }

  bool get _codeExpired => _codeSent && _expirySecondsLeft == 0;
  bool get _canResend => _codeSent && _resendCooldownLeft == 0;
  // ──────────────────────────────────────────────────────────────────────────

  void _checkPasswordStrength(String password) {
    if (password.isEmpty) {
      setState(() {
        _passwordStrength = '';
        _passwordStrengthColor = Colors.grey;
      });
      return;
    }

    int strength = 0;
    if (password.length >= 8) strength++;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength++;
    if (RegExp(r'[a-z]').hasMatch(password)) strength++;
    if (RegExp(r'[0-9]').hasMatch(password)) strength++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength++;

    setState(() {
      if (strength <= 2) {
        _passwordStrength = 'Weak';
        _passwordStrengthColor = Colors.red;
      } else if (strength == 3) {
        _passwordStrength = 'Fair';
        _passwordStrengthColor = Colors.orange;
      } else if (strength == 4) {
        _passwordStrength = 'Good';
        _passwordStrengthColor = Colors.blue;
      } else {
        _passwordStrength = 'Strong';
        _passwordStrengthColor = Colors.green;
      }
    });
  }

  Future<void> _sendVerificationCode() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showError('Please enter your email address');
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email)) {
      _showError('Please enter a valid email address');
      return;
    }

    setState(() => _isSendingCode = true);

    try {
      final message = await _authService.sendVerificationCode(email);

      if (mounted) {
        setState(() {
          _codeSent = true;
          _isSendingCode = false;
          // Clear any previously entered code when a fresh one is sent.
          _verificationCodeController.clear();
        });
        _startExpiryTimer();
        _startResendCooldown();
        _showSuccess(message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSendingCode = false);
        _showError(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_codeSent || _verificationCodeController.text.trim().isEmpty) {
      _showError('Please verify your email first');
      return;
    }

    if (_selectedProvince == null || _selectedMunicipality == null || _selectedBarangay == null) {
      _showError('Please select your complete address');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final User user = await _authService.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        passwordConfirm: _confirmPasswordController.text,
        fullName: _fullNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        province: _selectedProvince!,
        municipality: _selectedMunicipality!,
        barangay: _selectedBarangay!,
        street: _streetController.text.trim(),
        verificationCode: _verificationCodeController.text.trim(),
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const MapScreen(),
          ),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome, ${user.fullName}! Account created successfully.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue[700]!,
              Colors.blue[900]!,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Back button
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.person_add,
                            size: 40,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Title
                        const Text(
                          'Create Account',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        Text(
                          'Register as a resident',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Registration form
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Form(
                            key: _formKey,
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Full name
                                TextFormField(
                                  controller: _fullNameController,
                                  decoration: InputDecoration(
                                    labelText: 'Full Name *',
                                    prefixIcon: const Icon(Icons.person),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[a-zA-ZñÑáéíóúÁÉÍÓÚ\s\-]'),
                                    ),
                                  ],
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your full name';
                                    }
                                    if (value.length < 2) {
                                      return 'Name must be at least 2 characters';
                                    }
                                    if (value.length > 60) {
                                      return 'Name must not exceed 60 characters';
                                    }
                                    return null;
                                  },
                                  enabled: !_isLoading,
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Email with verification
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    labelText: 'Email Address *',
                                    prefixIcon: const Icon(Icons.email),
                                    suffixIcon: _codeSent
                                        ? const Icon(Icons.check_circle, color: Colors.green)
                                        : null,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your email';
                                    }
                                    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(value)) {
                                      return 'Please enter a valid email';
                                    }
                                    return null;
                                  },
                                  enabled: !_isLoading && !_codeSent,
                                ),
                                
                                const SizedBox(height: 12),
                                
                                // Send verification code button
                                if (!_codeSent)
                                  ElevatedButton.icon(
                                    onPressed: _isSendingCode ? null : _sendVerificationCode,
                                    icon: _isSendingCode
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.send),
                                    label: Text(_isSendingCode ? 'Sending...' : 'Send Verification Code'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue[600],
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                
                                const SizedBox(height: 16),
                                
                                // Verification code input (appears after code is sent)
                                if (_codeSent) ...[
                                  // Expiry countdown banner
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _codeExpired
                                          ? Colors.red[50]
                                          : (_expirySecondsLeft < 60
                                              ? Colors.orange[50]
                                              : Colors.blue[50]),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _codeExpired
                                            ? Colors.red[300]!
                                            : (_expirySecondsLeft < 60
                                                ? Colors.orange[300]!
                                                : Colors.blue[200]!),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _codeExpired
                                              ? Icons.timer_off
                                              : Icons.timer,
                                          size: 16,
                                          color: _codeExpired
                                              ? Colors.red[700]
                                              : (_expirySecondsLeft < 60
                                                  ? Colors.orange[700]
                                                  : Colors.blue[700]),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _expiryLabel,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: _codeExpired
                                                ? Colors.red[700]
                                                : (_expirySecondsLeft < 60
                                                    ? Colors.orange[700]
                                                    : Colors.blue[700]),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  TextFormField(
                                    controller: _verificationCodeController,
                                    keyboardType: TextInputType.number,
                                    maxLength: 6,
                                    decoration: InputDecoration(
                                      labelText: 'Enter 6-Digit Verification Code *',
                                      prefixIcon: const Icon(Icons.verified_user),
                                      helperText: 'Check your email inbox (and spam folder)',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(6),
                                    ],
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter verification code';
                                      }
                                      if (value.length != 6) {
                                        return 'Code must be 6 digits';
                                      }
                                      return null;
                                    },
                                    enabled: !_isLoading,
                                  ),

                                  // Resend button with cooldown
                                  Row(
                                    children: [
                                      _isSendingCode
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2),
                                            )
                                          : Icon(Icons.refresh,
                                              size: 16,
                                              color: _canResend
                                                  ? Colors.blue[700]
                                                  : Colors.grey),
                                      TextButton(
                                        onPressed: (_canResend && !_isSendingCode)
                                            ? _sendVerificationCode
                                            : null,
                                        child: Text(
                                          _resendCooldownLeft > 0
                                              ? 'Resend in ${_resendCooldownLeft}s'
                                              : 'Resend Code',
                                          style: TextStyle(
                                            color: _canResend
                                                ? Colors.blue[700]
                                                : Colors.grey,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 16),
                                ],
                                
                                // Phone number
                                TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  maxLength: 11,
                                  decoration: InputDecoration(
                                    labelText: 'Phone Number *',
                                    hintText: '09XXXXXXXXX',
                                    prefixIcon: const Icon(Icons.phone),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(11),
                                  ],
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your phone number';
                                    }
                                    if (value.length != 11) {
                                      return 'Enter a valid 11-digit phone number';
                                    }
                                    if (!value.startsWith('09')) {
                                      return 'Phone number must start with 09';
                                    }
                                    return null;
                                  },
                                  enabled: !_isLoading,
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Province dropdown
                                DropdownButtonFormField<String>(
                                  value: _selectedProvince,
                                  decoration: InputDecoration(
                                    labelText: 'Province *',
                                    prefixIcon: const Icon(Icons.location_city),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  items: PhilippineAddressData.getProvinces()
                                      .map((province) => DropdownMenuItem(
                                            value: province,
                                            child: Text(province),
                                          ))
                                      .toList(),
                                  onChanged: _isLoading ? null : (value) {
                                    setState(() {
                                      _selectedProvince = value;
                                      _selectedMunicipality = null;
                                      _selectedBarangay = null;
                                      _municipalities = PhilippineAddressData.getMunicipalities(value ?? '');
                                      _barangays = [];
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select your province';
                                    }
                                    return null;
                                  },
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Municipality dropdown
                                DropdownButtonFormField<String>(
                                  value: _selectedMunicipality,
                                  decoration: InputDecoration(
                                    labelText: 'Municipality/City *',
                                    prefixIcon: const Icon(Icons.location_on),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  items: _municipalities
                                      .map((municipality) => DropdownMenuItem(
                                            value: municipality,
                                            child: Text(municipality),
                                          ))
                                      .toList(),
                                  onChanged: _isLoading || _selectedProvince == null ? null : (value) {
                                    setState(() {
                                      _selectedMunicipality = value;
                                      _selectedBarangay = null;
                                      _barangays = PhilippineAddressData.getBarangays(value ?? '');
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select your municipality/city';
                                    }
                                    return null;
                                  },
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Barangay dropdown
                                DropdownButtonFormField<String>(
                                  value: _selectedBarangay,
                                  decoration: InputDecoration(
                                    labelText: 'Barangay *',
                                    prefixIcon: const Icon(Icons.location_on_outlined),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  items: _barangays
                                      .map((barangay) => DropdownMenuItem(
                                            value: barangay,
                                            child: Text(barangay),
                                          ))
                                      .toList(),
                                  onChanged: _isLoading || _selectedMunicipality == null ? null : (value) {
                                    setState(() {
                                      _selectedBarangay = value;
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select your barangay';
                                    }
                                    return null;
                                  },
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Street (optional)
                                TextFormField(
                                  controller: _streetController,
                                  decoration: InputDecoration(
                                    labelText: 'Street Address (Optional)',
                                    prefixIcon: const Icon(Icons.home),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  maxLength: 100,
                                  enabled: !_isLoading,
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Password
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    labelText: 'Password *',
                                    prefixIcon: const Icon(Icons.lock),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    helperText: _passwordStrength.isNotEmpty
                                        ? 'Strength: $_passwordStrength'
                                        : null,
                                    helperStyle: TextStyle(
                                      color: _passwordStrengthColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onChanged: _checkPasswordStrength,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a password';
                                    }
                                    if (value.length < 8) {
                                      return 'Password must be at least 8 characters';
                                    }
                                    if (!RegExp(r'[A-Z]').hasMatch(value)) {
                                      return 'Must contain at least one uppercase letter';
                                    }
                                    if (!RegExp(r'[a-z]').hasMatch(value)) {
                                      return 'Must contain at least one lowercase letter';
                                    }
                                    if (!RegExp(r'[0-9]').hasMatch(value)) {
                                      return 'Must contain at least one number';
                                    }
                                    return null;
                                  },
                                  enabled: !_isLoading,
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Confirm password
                                TextFormField(
                                  controller: _confirmPasswordController,
                                  obscureText: _obscureConfirmPassword,
                                  decoration: InputDecoration(
                                    labelText: 'Confirm Password *',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureConfirmPassword
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscureConfirmPassword = !_obscureConfirmPassword;
                                        });
                                      },
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value != _passwordController.text) {
                                      return 'Passwords do not match';
                                    }
                                    return null;
                                  },
                                  enabled: !_isLoading,
                                ),
                                
                                const SizedBox(height: 24),
                                
                                // Register button
                                ElevatedButton(
                                  onPressed: _isLoading || !_codeSent ? null : _handleRegister,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue[700],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 2,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          'Register',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Login link
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Already have an account? ',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _isLoading
                                          ? null
                                          : () => Navigator.pop(context),
                                      child: const Text(
                                        'Login',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
