import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../features/authentication/auth_service.dart';
import 'reset_password_screen.dart';

/// Step 2 of the password reset flow.
/// User enters the 6-digit OTP sent to their email.
class VerifyResetCodeScreen extends StatefulWidget {
  final String email;

  const VerifyResetCodeScreen({super.key, required this.email});

  @override
  State<VerifyResetCodeScreen> createState() => _VerifyResetCodeScreenState();
}

class _VerifyResetCodeScreenState extends State<VerifyResetCodeScreen> {
  final _authService = AuthService();
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final List<FocusNode> _keyListenerNodes = List.generate(6, (_) => FocusNode());

  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;

  // ── OTP expiry countdown (10 min) ────────────────────────────────────────
  int _expirySecondsLeft = 10 * 60;
  Timer? _expiryTimer;

  // ── Resend cooldown (60 s) ────────────────────────────────────────────────
  int _resendCooldownLeft = 0;
  Timer? _resendCooldownTimer;

  @override
  void initState() {
    super.initState();
    _startExpiryTimer();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    for (final f in _keyListenerNodes) {
      f.dispose();
    }
    _expiryTimer?.cancel();
    _resendCooldownTimer?.cancel();
    super.dispose();
  }

  // ── Timer helpers ──────────────────────────────────────────────────────────

  void _startExpiryTimer() {
    _expiryTimer?.cancel();
    setState(() => _expirySecondsLeft = 10 * 60);
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

  bool get _codeExpired => _expirySecondsLeft == 0;
  bool get _canResend => _resendCooldownLeft == 0;

  String get _expiryLabel {
    if (_codeExpired) return 'Code expired — request a new one';
    final m = _expirySecondsLeft ~/ 60;
    final s = _expirySecondsLeft % 60;
    return 'Code expires in ${m}m ${s.toString().padLeft(2, '0')}s';
  }

  // ──────────────────────────────────────────────────────────────────────────

  String get _enteredCode => _controllers.map((c) => c.text).join();

  bool get _isCodeComplete => _enteredCode.length == 6;

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    setState(() => _errorMessage = null);
    if (_isCodeComplete && !_codeExpired) {
      _handleVerify();
    }
  }

  void _onKeyDown(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _handleVerify() async {
    if (!_isCodeComplete || _isVerifying) return;
    if (_codeExpired) {
      setState(() => _errorMessage = 'The code has expired. Please request a new one.');
      return;
    }
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      await _authService.verifyResetCode(widget.email, _enteredCode);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(
            email: widget.email,
            code: _enteredCode,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        for (final c in _controllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
      });
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _handleResend() async {
    if (!_canResend || _isResending || _isVerifying) return;
    setState(() => _isResending = true);
    try {
      await _authService.forgotPassword(widget.email);
      if (!mounted) return;
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
      setState(() => _errorMessage = null);
      _startExpiryTimer();
      _startResendCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A new reset code has been sent to your email.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Widget _buildDigitField(int index) {
    return SizedBox(
      width: 44,
      child: KeyboardListener(
        focusNode: _keyListenerNodes[index],
        onKeyEvent: (e) => _onKeyDown(index, e),
        child: TextFormField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.blue[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            filled: true,
            fillColor: _controllers[index].text.isNotEmpty
                ? Colors.blue[50]
                : Colors.grey[50],
          ),
          onChanged: (v) => _onDigitChanged(index, v),
          enabled: !_isVerifying && !_codeExpired,
        ),
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
            colors: [Colors.blue[700]!, Colors.blue[900]!],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
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
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.mark_email_read_outlined,
                            size: 40,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Enter Reset Code',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'A 6-digit code was sent to\n${widget.email}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 36),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Expiry countdown banner
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.only(bottom: 16),
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

                              // OTP digit row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: List.generate(
                                  6,
                                  (i) => _buildDigitField(i),
                                ),
                              ),
                              if (_errorMessage != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.red[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.red[200]!),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.error_outline,
                                          color: Colors.red[700], size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: TextStyle(
                                            color: Colors.red[800],
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: (_isCodeComplete &&
                                        !_isVerifying &&
                                        !_codeExpired)
                                    ? _handleVerify
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[700],
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isVerifying
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Verify Code',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Didn't receive the code? ",
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: (_canResend &&
                                            !_isResending &&
                                            !_isVerifying)
                                        ? _handleResend
                                        : null,
                                    child: _isResending
                                        ? const SizedBox(
                                            height: 14,
                                            width: 14,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          )
                                        : Text(
                                            _resendCooldownLeft > 0
                                                ? 'Resend in ${_resendCooldownLeft}s'
                                                : 'Resend',
                                            style: TextStyle(
                                              color: _canResend
                                                  ? Colors.blue[700]
                                                  : Colors.grey,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            ],
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
