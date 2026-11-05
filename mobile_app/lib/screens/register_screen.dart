import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _hide = true;
  bool _hideConfirm = true;
  bool _loading = false;
  String? _error;

  static const Color _darkGreen = Color(0xFF124B30);
  static const Color _textColor = Color(0xFF203328);
  static const Color _fieldBorder = Color(0xFFD5E5D9);
  static const Color _mutedText = Color(0xFF64756A);

  @override
  void dispose() {
    _fullName.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ApiClient.instance.post('/register', auth: false, body: {
        'full_name': _fullName.text.trim(),
        'username': _username.text.trim(),
        'email': _email.text.trim(),
        'password': _password.text,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Registration successful. You can now log in.')));
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        // Fullscreen background image
        Image.asset(
          'assets/images/dashboard_field.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: const Color(0xFF124B30),
            );
          },
        ),

        // Dark overlay para klaro ang text
        Container(
          color: Colors.black.withValues(alpha: 0.30),
        ),

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
                                  child: _BrandPanel(),
                                ),
                                const SizedBox(width: 48),
                                Expanded(
                                  flex: 4,
                                  child: _buildFormCard(),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                const _BrandPanel(compact: true),
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
      child: _buildForm(),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildLabel('Full Name'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _fullName,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(hint: 'Enter your full name'),
            validator: (v) => (v == null || v.trim().length < 2)
                ? 'Enter your full name'
                : null,
          ),

          const SizedBox(height: 14),

          _buildLabel('Email Address'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(hint: 'Enter your email address'),
            validator: (v) {
              final value = v?.trim() ?? '';
              return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)
                  ? null
                  : 'Enter a valid email address';
            },
          ),

          const SizedBox(height: 14),

          _buildLabel('Username'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _username,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(hint: 'Choose a username'),
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.length < 3) return 'At least 3 characters';
              if (t.contains(RegExp(r'\s'))) {
                return 'No spaces allowed';
              }
              return null;
            },
          ),

          const SizedBox(height: 14),

          _buildLabel('Password'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _password,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onChanged: (_) => setState(() {}),
            obscureText: _hide,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(hint: 'Create a password').copyWith(
              helperText: '8+ characters, uppercase, lowercase, '
                  'number, and special character',
              helperMaxLines: 3,
              suffixIcon: IconButton(
                tooltip: _hide ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _hide = !_hide),
                icon: Icon(
                  _hide
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: primaryGreen,
                  size: 20,
                ),
              ),
            ),
            validator: (v) {
              final p = v ?? '';
              if (p.length < 8 ||
                  !RegExp(r'[A-Z]').hasMatch(p) ||
                  !RegExp(r'[a-z]').hasMatch(p) ||
                  !RegExp(r'[0-9]').hasMatch(p) ||
                  !RegExp(r'[^A-Za-z0-9]').hasMatch(p)) {
                return 'Use 8+ characters with uppercase, '
                    'lowercase, number, and special character';
              }
              return null;
            },
          ),

          const SizedBox(height: 14),

          _buildLabel('Confirm Password'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _confirm,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            obscureText: _hideConfirm,
            onFieldSubmitted: (_) => _loading ? null : _register(),
            decoration: _inputDecoration(hint: 'Confirm your password')
                .copyWith(
              suffixIcon: IconButton(
                tooltip: _hideConfirm ? 'Show password' : 'Hide password',
                onPressed: () => setState(
                  () => _hideConfirm = !_hideConfirm,
                ),
                icon: Icon(
                  _hideConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: primaryGreen,
                  size: 20,
                ),
              ),
            ),
            validator: (v) =>
                v != _password.text ? 'Passwords do not match' : null,
          ),
          const SizedBox(height: 14),

         

          
         

          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _register,
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
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
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
          ),

          const SizedBox(height: 16),

          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Already have an account? ',
                style: TextStyle(color: _mutedText, fontSize: 13),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Text(
                  'Log In',
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
        vertical: 15,
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
        Text(
          'RandomForest',
          textAlign: textAlign,
          style: TextStyle(
            fontSize: compact ? 32 : 42,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.7,
            shadows: textShadow,
          ),
        ),

        const SizedBox(height: 10),

        Text(
          'Smart insights for thriving farms',
          textAlign: textAlign,
          style: TextStyle(
            fontSize: compact ? 14 : 17,
            height: 1.6,
            fontWeight: FontWeight.w500,
            color: Colors.white,
            shadows: textShadow,
          ),
        ),

        const SizedBox(height: 30),

        Text(
          'Create Your\nAccount',
          textAlign: textAlign,
          style: TextStyle(
            fontSize: compact ? 30 : 40,
            height: 1.15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.5,
            shadows: textShadow,
          ),
        ),

        const SizedBox(height: 12),

        Text(
          'Join RandomForest and\n'
            'start your journey to\n'
            'smarter farming.',
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



