
import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();

  bool _loading = false;
  bool _codeSent = false;

  String? _message;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _sendCode({bool resend = false}) async {
    final email = _email.text.trim();

    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
        .hasMatch(email)) {
      setState(() {
        _error = 'Please enter a valid email address.';
        _message = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });

    try {
      final result = await ApiClient.instance.post(
        '/password/forgot',
        auth: false,
        body: {'email': email},
      );

      if (!mounted) return;

      setState(() {
        _codeSent = true;
        _message = (result as Map)['message']?.toString() ??
            (resend
                ? 'A new verification code has been requested. Please check your email.'
                : 'If an account with that email exists, a verification code will be sent.');
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;
    final isCompact = screenWidth < 380;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Forgot Password',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: primaryGreen.withOpacity(0.94),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // FARM BACKGROUND IMAGE
          Positioned.fill(
            child: Image.asset(
              'assets/images/dashboard_field.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: const Color(0xFFEAF5E8),
                );
              },
            ),
          ),

          // BACKGROUND OVERLAY
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.20),
            ),
          ),

          // MAIN CONTENT
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 30,
                  vertical: 30,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 480,
                  ),
                  child: Card(
                    elevation: 12,
                    color: Colors.white.withOpacity(0.96),
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        isMobile ? 22 : 28,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(
                        isCompact ? 20 : 30,
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ICON
                          Center(
                            child: Container(
                              height: 82,
                              width: 82,
                              decoration: BoxDecoration(
                                color: primaryGreen.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.mark_email_read_outlined,
                                size: 42,
                                color: primaryGreen,
                              ),
                            ),
                          ),

                          const SizedBox(height: 22),

                          // TITLE
                          const Text(
                            'Reset your password',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                              color: primaryGreen,
                            ),
                          ),

                          const SizedBox(height: 12),

                          // DESCRIPTION
                          Text(
                            'Enter the email address linked to your account. We will send you a verification code to continue.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isCompact ? 13 : 15,
                              height: 1.5,
                              color: Colors.black87,
                            ),
                          ),

                          const SizedBox(height: 28),

                          // EMAIL FIELD
                          TextField(
                            controller: _email,
                            keyboardType:
                                TextInputType.emailAddress,
                            textInputAction:
                                TextInputAction.done,
                            autofillHints: const [
                              AutofillHints.email,
                            ],
                            enabled: !_loading,
                            decoration: InputDecoration(
                              labelText: 'Email address',
                              hintText:
                                  'Enter your registered email',
                              prefixIcon: const Icon(
                                Icons.email_outlined,
                                color: primaryGreen,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(14),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: primaryGreen,
                                  width: 1.8,
                                ),
                              ),
                            ),
                            onSubmitted: (_) {
                              if (!_loading) _sendCode();
                            },
                          ),

                          // SUCCESS MESSAGE
                          if (_message != null) ...[
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: primaryGreen.withOpacity(0.10),
                                borderRadius:
                                    BorderRadius.circular(12),
                              ),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline,
                                    color: primaryGreen,
                                    size: 21,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _message!,
                                      style: const TextStyle(
                                        color: primaryGreen,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // ERROR MESSAGE
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              _error!,
                              style: const TextStyle(
                                color: statusBad,
                                height: 1.4,
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),

                          // SEND CODE BUTTON
                          SizedBox(
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: _loading
                                  ? null
                                  : () => _sendCode(),
                              icon: _loading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.send_rounded,
                                    ),
                              label: Text(
                                _loading
                                    ? 'Please wait...'
                                    : 'Send Verification Code',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryGreen,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    primaryGreen.withOpacity(0.6),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),

                          // RESEND CODE BUTTON
                          if (_codeSent) ...[
                            const SizedBox(height: 14),
                            SizedBox(
                              height: 50,
                              child: OutlinedButton.icon(
                                onPressed: _loading
                                    ? null
                                    : () => _sendCode(
                                          resend: true,
                                        ),
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                ),
                                label: const Text(
                                  'Resend Code',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: primaryGreen,
                                  side: const BorderSide(
                                    color: primaryGreen,
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 22),

                          // HELPER TEXT
                          Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: primaryGreen.withOpacity(0.08),
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  color: primaryGreen,
                                  size: 21,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Did not receive the email? Check your spam folder before requesting another code.',
                                    style: TextStyle(
                                      fontSize:
                                          isCompact ? 12 : 13,
                                      height: 1.4,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
