import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}
class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _loading = false;
  String? _message;
  String? _error;
  @override
  void dispose() { _email.dispose(); super.dispose(); }
  Future<void> _submit() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() { _error = 'Enter a valid email address.'; _message = null; }); return;
    }
    setState(() { _loading = true; _error = null; _message = null; });
    try {
      final result = await ApiClient.instance.post('/password/forgot', auth: false, body: {'email': email});
      if (mounted) setState(() => _message = (result as Map)['message']?.toString() ?? 'If an account with that email exists, a password-reset link will be sent.');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally { if (mounted) setState(() => _loading = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Forgot Password')),
    body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Icon(Icons.lock_reset, size: 54, color: primaryGreen),
        const SizedBox(height: 16),
        const Text('Enter your registered email address. If it matches an account, a reset link will be sent.', textAlign: TextAlign.center),
        const SizedBox(height: 20),
        TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.email_outlined))),
        if (_message != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(_message!, style: const TextStyle(color: primaryGreen))),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(_error!, style: const TextStyle(color: statusBad))),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: _loading ? null : _submit, child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Send reset link')),
      ]),
    ))),
  );
}
