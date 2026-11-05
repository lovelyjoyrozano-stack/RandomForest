import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../models/models.dart';
import 'dashboard_screen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  final bool sessionExpired;

  const LoginScreen({
    super.key,
    this.sessionExpired = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();

  bool _hide = true;
  bool _loading = false;
  bool _rememberMe = true;

  String? _error;

  static const Color _darkGreen = Color(0xFF124B30);
  static const Color _textColor = Color(0xFF203328);
  static const Color _fieldBorder = Color(0xFFD5E5D9);
  static const Color _mutedText = Color(0xFF64756A);

  @override
  void initState() {
    super.initState();

    if (widget.sessionExpired) {
      _error = 'Your session expired. Please log in again.';
    }
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  // EXISTING LOGIN API CONNECTION
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await ApiClient.instance.post(
        '/login',
        auth: false,
        body: {
          'username': _username.text.trim(),
          'password': _password.text,
        },
      );

      final map = Map<String, dynamic>.from(data as Map);

      final user = User.fromJson(
        Map<String, dynamic>.from(map['user'] as Map),
      );

      if (user.role.toLowerCase() != 'farmer') {
        throw const ApiException(
          'Only Farmer accounts can log in here.',
        );
      }

      await Session.instance.signIn(
        map['access_token'] as String,
        user,
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const DashboardScreen(),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Unexpected response from the server.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _openRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RegisterScreen(),
      ),
    );
  }

  void _openForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ForgotPasswordScreen(),
      ),
    );
  }


@override
Widget build(BuildContext context) {
  return Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        // FULLSCREEN BACKGROUND IMAGE
        Positioned.fill(
          child: Image.asset(
            'assets/images/dashboard_field.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const ColoredBox(
                color: Color(0xFFE5F3E8),
              );
            },
          ),
        ),

        // LIGHT OVERLAY
        const Positioned.fill(
          child: ColoredBox(
            color: Color(0x22000000),
          ),
        ),

        // LOGIN FORM
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 800;

              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 40 : 20,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 48,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 1100,
                      ),
                      child: isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Expanded(
                                  flex: 5,
                                  child: _BrandPanel(
                                    compact: true,
                                  ),
                                ),
                                const SizedBox(width: 48),
                                Expanded(
                                  flex: 4,
                                  child: _buildFormCard(),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const _BrandPanel(
                                  compact: true,
                                ),
                                const SizedBox(height: 22),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 460,
                                  ),
                                  child: _buildFormCard(),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _fieldBorder),
        boxShadow: [
          BoxShadow(
            color: _darkGreen.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: _buildLoginForm(),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // USERNAME
          _buildLabel('Username'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _username,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            decoration: _inputDecoration(hint: 'Enter your username'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Enter your username';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          // PASSWORD
          _buildLabel('Password'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _password,
            obscureText: _hide,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              if (!_loading) _login();
            },
            decoration: _inputDecoration(hint: 'Enter your password').copyWith(
              suffixIcon: IconButton(
                tooltip: _hide ? 'Show password' : 'Hide password',
                onPressed: () {
                  setState(() {
                    _hide = !_hide;
                  });
                },
                icon: Icon(
                  _hide
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: primaryGreen,
                  size: 20,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Enter your password';
              }
              return null;
            },
          ),

          const SizedBox(height: 14),

          // REMEMBER ME AND FORGOT PASSWORD
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _rememberMe,
                  activeColor: primaryGreen,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _rememberMe = value ?? false;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Remember me',
                  style: TextStyle(fontSize: 13, color: _textColor),
                ),
              ),
              TextButton(
                onPressed: _openForgotPassword,
                style: TextButton.styleFrom(
                  foregroundColor: primaryGreen,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                ),
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          // API ERROR MESSAGE
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEEE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFCCCC)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 21,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: statusBad,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 22),

          // LOGIN BUTTON
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor: primaryGreen.withValues(alpha: 0.6),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 23,
                      width: 23,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Log In',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 18),

          // REGISTER NAVIGATION
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                "Don't have an account? ",
                style: TextStyle(color: _mutedText, fontSize: 13),
              ),
              GestureDetector(
                onTap: _openRegister,
                child: const Text(
                  'Register',
                  style: TextStyle(
                    color: primaryGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _textColor,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF91A197),
        fontSize: 13,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryGreen, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }
}

// ========================================
// RANDOMFOREST BRAND PANEL
// ========================================

class _BrandPanel extends StatelessWidget {
  final bool compact;

  const _BrandPanel({
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final textAlign = compact ? TextAlign.center : TextAlign.left;
    final align =
        compact ? CrossAxisAlignment.center : CrossAxisAlignment.start;

    const textShadow = [
      Shadow(
        color: Colors.black87,
        blurRadius: 12,
        offset: Offset(2, 3),
      ),
    ];

    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        // APP NAME
        Text(
          'RandomForest',
          textAlign: textAlign,
          style: TextStyle(
            fontSize: compact ? 38 : 48,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.7,
            shadows: textShadow,
          ),
        ),

        const SizedBox(height: 10),

        // SYSTEM TITLE
        Text(
          'Climate and Crop Productivity Monitoring\n'
          'and Decision Support System',
          textAlign: textAlign,
          style: TextStyle(
            fontSize: compact ? 14 : 17,
            height: 1.6,
            fontWeight: FontWeight.w500,
            color: Colors.white,
            shadows: textShadow,
          ),
        ),

        const SizedBox(height: 32),

        // WELCOME MESSAGE
        Text(
          'Welcome Back!',
          textAlign: textAlign,
          style: TextStyle(
            fontSize: compact ? 36 : 46,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.8,
            shadows: textShadow,
          ),
        ),

        const SizedBox(height: 12),

        // DESCRIPTION
        Text(
          'Sign in to access your farm insights,\n'
          'track performance, and make\n'
          'smarter decisions.',
          textAlign: textAlign,
          style: TextStyle(
            fontSize: compact ? 14 : 16,
            height: 1.7,
            color: Colors.white,
            shadows: textShadow,
          ),
        ),
      ],
    );
  }
}
